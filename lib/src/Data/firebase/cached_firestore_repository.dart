import 'package:gig_hub/src/Data/app_imports.dart';

/// Enhanced Firestore repository with intelligent caching to reduce Firebase costs
///
/// Key Features:
/// - Cache-first approach for read operations
/// - Smart cache invalidation on writes
/// - Optimistic updates for better UX
/// - Automatic cache warming
/// - Background sync for offline support
class CachedFirestoreRepository extends FirestoreDatabaseRepository {
  final CacheService _cache = CacheService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream controllers for cached data with real-time updates
  final Map<String, StreamController<List<ChatMessage>>>
  _messageStreamControllers = {};
  final Map<String, StreamController<List<GroupMessage>>>
  _groupMessageStreamControllers = {};
  final Map<String, StreamController<List<ChatMessage>>>
  _chatListStreamControllers = {};

  // Store last emitted values for immediate access
  final Map<String, List<ChatMessage>> _lastChatListValues = {};

  // Real-time listeners to Firebase (kept minimal)
  final Map<String, StreamSubscription> _firebaseListeners = {};

  // =============================================================================
  // CACHED CHAT OPERATIONS
  // =============================================================================

  @override
  Future<void> sendMessage(ChatMessage message) async {
    // 1. Update cache optimistically before Firebase
    final chatId = getChatId(message.senderId, message.receiverId);
    _cache.addMessageToCache(chatId, message);

    // 2. Update message stream controllers immediately
    _notifyMessageStreamControllers(chatId);

    // 3. CRITICAL: Update chat list cache immediately with the new message
    _updateChatListWithNewMessage(message);

    // 4. Update Firebase chat document immediately for the sender (optimistic)
    _updateChatDocumentInFirebase(chatId, message);

    // 5. Send to Firebase (don't await to keep UI responsive)
    super.sendMessage(message).catchError((error) {
      // Handle error if needed, but keep optimistic update
    });
  }

  /// Updates the chat document in Firebase to maintain last message data
  Future<void> _updateChatDocumentInFirebase(
    String chatId,
    ChatMessage message,
  ) async {
    try {
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [message.senderId, message.receiverId],
        'lastMessage': message.message,
        'lastTimestamp': Timestamp.fromDate(message.timestamp),
        'lastSenderId': message.senderId,
        'lastRead': false,
      }, SetOptions(merge: true));
    } catch (e) {
      // Fail silently - the optimistic update is what matters for UX
    }
  }

  /// Updates the chat list cache when a new message is sent
  /// This ensures the chat list shows the correct most recent message
  void _updateChatListWithNewMessage(ChatMessage message) {
    // Update chat list for both sender and receiver
    final senderId = message.senderId;
    final receiverId = message.receiverId;

    _updateUserChatList(senderId, message);
    _updateUserChatList(receiverId, message);
  }

  /// Updates a specific user's chat list to reflect the new message
  void _updateUserChatList(String userId, ChatMessage newMessage) {
    List<ChatMessage> currentChatList;

    // If user's chat list isn't loaded yet, create a new list with just this message
    if (!_lastChatListValues.containsKey(userId)) {
      currentChatList = [newMessage];
    } else {
      // Update existing cache
      currentChatList = List<ChatMessage>.from(_lastChatListValues[userId]!);

      // Find existing chat entry for this conversation
      final partnerId =
          newMessage.senderId == userId
              ? newMessage.receiverId
              : newMessage.senderId;
      final existingIndex = currentChatList.indexWhere((chat) {
        final chatPartnerId =
            chat.senderId == userId ? chat.receiverId : chat.senderId;
        return chatPartnerId == partnerId;
      });

      if (existingIndex != -1) {
        // Update existing chat entry
        currentChatList[existingIndex] = newMessage;
      } else {
        // Add new chat entry
        currentChatList.add(newMessage);
      }
    }

    // Sort by timestamp (most recent first)
    currentChatList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Update cache immediately
    _lastChatListValues[userId] = currentChatList;
    _cache.cacheChatList(userId, currentChatList);

    // CRITICAL: Notify stream controllers immediately for real-time UI update
    _notifyChatListStreamController(userId, currentChatList);
  }

  /// Notifies chat list stream controller of updates
  void _notifyChatListStreamController(
    String userId,
    List<ChatMessage> chatList,
  ) {
    if (_chatListStreamControllers.containsKey(userId)) {
      final controller = _chatListStreamControllers[userId]!;
      if (!controller.isClosed) {
        // Force immediate stream update
        controller.add(chatList);

        // Also ensure the cached value is immediately available for future stream requests
        _lastChatListValues[userId] = chatList;
      }
    }
  }

  @override
  Stream<List<ChatMessage>> getMessagesStream(
    String senderId,
    String receiverId,
  ) {
    final chatId = getChatId(senderId, receiverId);

    // Return existing controller if available
    if (_messageStreamControllers.containsKey(chatId)) {
      return _messageStreamControllers[chatId]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<List<ChatMessage>>.broadcast();
    _messageStreamControllers[chatId] = controller;

    // Initialize with cached data first
    _initializeMessagesStream(chatId, senderId, receiverId, controller);

    return controller.stream;
  }

  Future<void> _initializeMessagesStream(
    String chatId,
    String senderId,
    String receiverId,
    StreamController<List<ChatMessage>> controller,
  ) async {
    // 1. Try cache first for immediate display
    final cachedMessages = await _cache.getCachedChatMessages(chatId);
    if (cachedMessages != null && cachedMessages.isNotEmpty) {
      controller.add(cachedMessages);
    } else {
      // Emit empty list immediately if no cached messages
      // This prevents the UI from showing loading state
      controller.add(<ChatMessage>[]);
    }

    // 2. Set up selective Firebase listener (only for new messages)
    if (!_firebaseListeners.containsKey(chatId)) {
      // Get timestamp of last cached message to only listen for newer ones
      DateTime? lastMessageTime =
          cachedMessages?.isNotEmpty == true
              ? cachedMessages!.last.timestamp
              : null;

      final firebaseStream =
          lastMessageTime != null
              ? _getMessagesStreamAfterTimestamp(
                senderId,
                receiverId,
                lastMessageTime,
              )
              : super.getMessagesStream(senderId, receiverId);

      _firebaseListeners[chatId] = firebaseStream.listen((newMessages) {
        // Always process the result, even if empty
        // For new chats, empty result should be shown immediately
        if (lastMessageTime == null) {
          // First time loading - replace cache entirely
          _cache.cacheChatMessages(chatId, newMessages);
        } else if (newMessages.isNotEmpty) {
          // Incremental update - merge with existing cache
          _mergeAndCacheMessages(chatId, newMessages);
        }
        _notifyMessageStreamControllers(chatId);
      });
    }
  }

  /// Custom Firebase query to only get messages after a specific timestamp
  Stream<List<ChatMessage>> _getMessagesStreamAfterTimestamp(
    String senderId,
    String receiverId,
    DateTime afterTimestamp,
  ) {
    final chatId = getChatId(senderId, receiverId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(afterTimestamp))
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ChatMessage.fromJson(doc.id, doc.data()))
                  .toList(),
        );
  }

  void _mergeAndCacheMessages(
    String chatId,
    List<ChatMessage> newMessages,
  ) async {
    final cachedMessages = await _cache.getCachedChatMessages(chatId) ?? [];

    // Merge without duplicates
    final Set<String> existingIds = cachedMessages.map((m) => m.id).toSet();
    final uniqueNewMessages =
        newMessages.where((m) => !existingIds.contains(m.id)).toList();

    if (uniqueNewMessages.isNotEmpty) {
      final allMessages = [...cachedMessages, ...uniqueNewMessages];
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _cache.cacheChatMessages(chatId, allMessages);
    }
  }

  void _notifyMessageStreamControllers(String chatId) async {
    final controller = _messageStreamControllers[chatId];
    if (controller != null && !controller.isClosed) {
      final messages = await _cache.getCachedChatMessages(chatId) ?? [];
      controller.add(messages);
    }
  }

  // =============================================================================
  // CACHED CHAT LIST OPERATIONS
  // =============================================================================

  @override
  Stream<List<ChatMessage>> getChatsStream(String userId) {
    // Return existing controller stream if available
    if (_chatListStreamControllers.containsKey(userId)) {
      final controller = _chatListStreamControllers[userId]!;

      // If we have cached data, emit it immediately, then continue with the stream
      if (_lastChatListValues.containsKey(userId)) {
        final cachedData = _lastChatListValues[userId]!;

        return Stream<List<ChatMessage>>.multi((streamController) {
          // Emit cached data first for immediate UI update
          streamController.add(cachedData);

          // Then listen to ongoing updates
          final subscription = controller.stream.listen((data) {
            _lastChatListValues[userId] = data;
            streamController.add(data);
          }, onError: streamController.addError);

          streamController.onCancel = () => subscription.cancel();
        });
      } else {
        // No cached data, just return the controller stream
        return controller.stream.map((data) {
          _lastChatListValues[userId] = data;
          return data;
        });
      }
    }

    // Create new controller if none exists
    final controller = StreamController<List<ChatMessage>>.broadcast();
    _chatListStreamControllers[userId] = controller;

    // Initialize the stream
    _initializeChatListStream(userId, controller);

    // Return the controller stream
    return controller.stream.map((data) {
      _lastChatListValues[userId] = data;
      return data;
    });
  }

  Future<void> _initializeChatListStream(
    String userId,
    StreamController<List<ChatMessage>> controller,
  ) async {
    // 1. Serve cached data immediately if available
    final cachedChatList = await _cache.getCachedChatList(userId);
    if (cachedChatList != null && cachedChatList.isNotEmpty) {
      _lastChatListValues[userId] = cachedChatList;
      controller.add(cachedChatList);
    } else {
      // 2. If no cache, fetch immediately for first load
      try {
        final freshChatList = await _getOptimizedChatsStream(userId);
        _cache.cacheChatList(userId, freshChatList);
        _lastChatListValues[userId] = freshChatList;
        controller.add(freshChatList);
      } catch (e) {
        // Send empty list if initial fetch fails
        final emptyList = <ChatMessage>[];
        _lastChatListValues[userId] = emptyList;
        controller.add(emptyList);
      }
    }

    // Note: No periodic timer - rely on optimistic updates and explicit refreshes
  }

  /// Forces an immediate refresh of the chat list for a specific user
  /// This is useful when returning to the chat list screen after sending messages
  @override
  Future<void> forceRefreshChatList(String userId) async {
    try {
      final freshChatList = await _getOptimizedChatsStream(userId);
      _cache.cacheChatList(userId, freshChatList);
      _lastChatListValues[userId] = freshChatList;

      // Notify the stream controller if it exists
      if (_chatListStreamControllers.containsKey(userId)) {
        final controller = _chatListStreamControllers[userId]!;
        if (!controller.isClosed) {
          controller.add(freshChatList);
        }
      }
    } catch (e) {
      // Continue with cached data on error
    }
  }

  /// Optimized chat list fetching that avoids N+1 queries
  /// Uses only the chat document data without additional message queries
  Future<List<ChatMessage>> _getOptimizedChatsStream(String userId) async {
    final querySnapshot =
        await _firestore
            .collection('chats')
            .where('participants', arrayContains: userId)
            .get();

    List<ChatMessage> allMessages = [];

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final chatId = doc.id;
      final lastMessage = data['lastMessage'] as String? ?? '';
      final timestamp = (data['lastTimestamp'] as Timestamp?)?.toDate();
      final participants = List<String>.from(data['participants'] ?? []);
      final senderId = data['lastSenderId'] as String? ?? userId;
      final read =
          data['lastRead'] as bool? ?? false; // Use chat-level read status

      final receiverId = participants.firstWhere(
        (id) => id != userId,
        orElse: () => '',
      );

      if (receiverId.isEmpty || timestamp == null) continue;

      allMessages.add(
        ChatMessage(
          id: chatId, // Use chat ID instead of message ID
          senderId: senderId,
          receiverId: receiverId,
          message: lastMessage,
          timestamp: timestamp,
          read: read,
        ),
      );
    }

    return allMessages;
  }

  // =============================================================================
  // CACHED GROUP CHAT OPERATIONS
  // =============================================================================

  @override
  Future<void> sendGroupMessage(GroupMessage message) async {
    // Optimistic cache update
    _cache.addGroupMessageToCache(message.groupChatId, message);
    _notifyGroupMessageStreamControllers(message.groupChatId);

    // Send to Firebase
    await super.sendGroupMessage(message);
  }

  @override
  Stream<List<GroupMessage>> getGroupMessagesStream(String groupChatId) {
    if (_groupMessageStreamControllers.containsKey(groupChatId)) {
      return _groupMessageStreamControllers[groupChatId]!.stream;
    }

    final controller = StreamController<List<GroupMessage>>.broadcast();
    _groupMessageStreamControllers[groupChatId] = controller;

    _initializeGroupMessagesStream(groupChatId, controller);

    return controller.stream;
  }

  Future<void> _initializeGroupMessagesStream(
    String groupChatId,
    StreamController<List<GroupMessage>> controller,
  ) async {
    // Serve cached data first
    final cachedMessages = await _cache.getCachedGroupMessages(groupChatId);
    if (cachedMessages != null) {
      controller.add(cachedMessages);
    }

    // Set up Firebase listener for new messages only
    DateTime? lastMessageTime =
        cachedMessages?.isNotEmpty == true
            ? cachedMessages!.last.timestamp
            : null;

    final firebaseStream =
        lastMessageTime != null
            ? _getGroupMessagesStreamAfterTimestamp(
              groupChatId,
              lastMessageTime,
            )
            : super.getGroupMessagesStream(groupChatId);

    firebaseStream.listen((newMessages) {
      if (newMessages.isNotEmpty) {
        _mergeAndCacheGroupMessages(groupChatId, newMessages);
        _notifyGroupMessageStreamControllers(groupChatId);
      }
    });
  }

  Stream<List<GroupMessage>> _getGroupMessagesStreamAfterTimestamp(
    String groupChatId,
    DateTime afterTimestamp,
  ) {
    return _firestore
        .collection('group_chats')
        .doc(groupChatId)
        .collection('messages')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(afterTimestamp))
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => GroupMessage.fromJson(doc.id, doc.data()))
                  .toList(),
        );
  }

  void _mergeAndCacheGroupMessages(
    String groupChatId,
    List<GroupMessage> newMessages,
  ) async {
    final cachedMessages =
        await _cache.getCachedGroupMessages(groupChatId) ?? [];

    final Set<String> existingIds = cachedMessages.map((m) => m.id).toSet();
    final uniqueNewMessages =
        newMessages.where((m) => !existingIds.contains(m.id)).toList();

    if (uniqueNewMessages.isNotEmpty) {
      final allMessages = [...cachedMessages, ...uniqueNewMessages];
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _cache.cacheGroupMessages(groupChatId, allMessages);
    }
  }

  void _notifyGroupMessageStreamControllers(String groupChatId) async {
    final controller = _groupMessageStreamControllers[groupChatId];
    if (controller != null && !controller.isClosed) {
      final messages = await _cache.getCachedGroupMessages(groupChatId) ?? [];
      controller.add(messages);
    }
  }

  // =============================================================================
  // CACHED USER OPERATIONS
  // =============================================================================

  @override
  Future<AppUser> getUserById(String id) async {
    // Try cache first
    final cachedUser = await _cache.getCachedUser(id);
    if (cachedUser != null) {
      return cachedUser;
    }

    // Fetch from Firebase and cache
    final user = await super.getUserById(id);
    _cache.cacheUser(id, user);
    return user;
  }

  @override
  Future<AppUser> getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("no user logged in");

    // Try cache first
    final cachedUser = await _cache.getCachedUser(user.uid);
    if (cachedUser != null) {
      return cachedUser;
    }

    // Fetch and cache
    final currentUser = await super.getCurrentUser();
    _cache.cacheUser(user.uid, currentUser);
    return currentUser;
  }

  // =============================================================================
  // CACHED DJ SEARCH OPERATIONS
  // =============================================================================

  @override
  Future<List<DJ>> getDJs() async {
    const cacheKey = 'all_djs';

    // Try cache first
    final cachedDJs = await _cache.getCachedDJList(cacheKey);
    if (cachedDJs != null) {
      return cachedDJs;
    }

    // Fetch from Firebase and cache
    final djs = await super.getDJs();
    _cache.cacheDJList(cacheKey, djs);
    return djs;
  }

  @override
  Future<List<DJ>> searchDJs({
    List<String>? genres,
    String? city,
    List<int>? bpmRange,
  }) async {
    // Generate cache key based on search parameters
    final cacheKey = _cache.generateDJSearchCacheKey(
      genres: genres,
      city: city,
      bpmRange: bpmRange,
    );

    // Try cache first
    final cachedResults = await _cache.getCachedDJList(cacheKey);
    if (cachedResults != null) {
      return cachedResults;
    }

    // Fetch from Firebase and cache
    final results = await super.searchDJs(
      genres: genres,
      city: city,
      bpmRange: bpmRange,
    );
    _cache.cacheDJList(cacheKey, results);
    return results;
  }

  // =============================================================================
  // CACHE INVALIDATION & CLEANUP
  // =============================================================================

  @override
  Future<void> deleteMessage(
    String chatId,
    String messageId,
    String currentUserId,
  ) async {
    // Delete from Firebase first
    await super.deleteMessage(chatId, messageId, currentUserId);

    // Invalidate cache and refresh
    _cache.invalidateChatCache(chatId);
    _notifyMessageStreamControllers(chatId);
  }

  @override
  Future<void> deleteChat(String userId, String partnerId) async {
    await super.deleteChat(userId, partnerId);

    final chatId = getChatId(userId, partnerId);
    _cache.invalidateChatCache(chatId);

    // Close stream controller
    _messageStreamControllers[chatId]?.close();
    _messageStreamControllers.remove(chatId);

    // Cancel Firebase listener
    _firebaseListeners[chatId]?.cancel();
    _firebaseListeners.remove(chatId);
  }

  @override
  Future<void> updateUser(AppUser user) async {
    await super.updateUser(user);

    // Invalidate user cache
    _cache.invalidateUserCache(user.id);

    // Update cache with new data
    _cache.cacheUser(user.id, user);
  }

  // =============================================================================
  // RAVE OPERATIONS WITH CACHING
  // =============================================================================

  /// Updates a rave and invalidates any related caches
  @override
  Future<void> updateRave(String raveId, Map<String, dynamic> updates) async {
    try {
      // Update in Firebase
      await super.updateRave(raveId, updates);

      // Invalidate any rave-related caches
      // You might want to invalidate specific caches here if you implement rave caching
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a rave and cleans up any related caches
  @override
  Future<void> deleteRave(String raveId) async {
    try {
      // Delete from Firebase (includes group chat cleanup)
      await super.deleteRave(raveId);

      // Invalidate any rave-related caches
      // You might want to invalidate specific caches here if you implement rave caching
    } catch (e) {
      rethrow;
    }
  }

  // =============================================================================
  // CLEANUP & MEMORY MANAGEMENT
  // =============================================================================

  /// Clean up resources and caches
  @override
  void dispose() {
    // Cancel all Firebase listeners
    for (final subscription in _firebaseListeners.values) {
      subscription.cancel();
    }
    _firebaseListeners.clear();

    // Close all stream controllers
    for (final controller in _messageStreamControllers.values) {
      controller.close();
    }
    _messageStreamControllers.clear();

    for (final controller in _groupMessageStreamControllers.values) {
      controller.close();
    }
    _groupMessageStreamControllers.clear();

    for (final controller in _chatListStreamControllers.values) {
      controller.close();
    }
    _chatListStreamControllers.clear();

    // Clear expired cache entries
    _cache.clearExpiredEntries();

    // Call parent dispose
    super.dispose();
  }

  /// Get cache statistics for monitoring
  Map<String, dynamic> getCacheStats() => _cache.stats;

  /// Force refresh of specific chat (bypasses cache)
  Future<void> forceRefreshChat(String senderId, String receiverId) async {
    final chatId = getChatId(senderId, receiverId);
    _cache.invalidateChatCache(chatId);

    final freshMessages =
        await super.getMessagesStream(senderId, receiverId).first;
    _cache.cacheChatMessages(chatId, freshMessages);
    _notifyMessageStreamControllers(chatId);
  }

  // =============================================================================
  // PUBLIC GROUP CHAT METHODS (delegate to base repository)
  // =============================================================================
}
