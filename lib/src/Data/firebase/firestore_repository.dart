import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:gig_hub/src/Data/app_imports.dart';

/// Main Firestore database repository implementing all database operations
/// Handles user management, chat messaging, rave management, group chats, and notifications
///
/// Key features:
/// - User CRUD operations (Guest, DJ, Booker)
/// - Real-time chat messaging with encryption support
/// - Group chat functionality with member management
/// - Rave event management with CRUD operations
/// - FCM token management for push notifications
/// - Image upload and management via Firebase Storage
class FirestoreDatabaseRepository extends DatabaseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =============================================================================
  // USER MANAGEMENT SECTION
  // =============================================================================

  /// Creates a new Guest user document in Firestore
  @override
  Future<void> createGuest(Guest guest) async {
    final docRef = _firestore.collection('users').doc(guest.id);
    await docRef.set(guest.toJson());
    await initFirebaseMessaging(); // Initialize FCM token after user creation
  }

  @override
  Future<void> createDJ(DJ dj) async {
    final docRef = _firestore.collection('users').doc(dj.id);
    await docRef.set(dj.toJson());
    await initFirebaseMessaging();
  }

  @override
  Future<void> createBooker(Booker booker) async {
    final docRef = _firestore.collection('users').doc(booker.id);
    await docRef.set(booker.toJson());
    await initFirebaseMessaging();
  }

  // delete ###
  @override
  Future<void> deleteGuest(Guest guest) async {
    await _firestore.collection('users').doc(guest.id).delete();
  }

  @override
  Future<void> deleteDJ(DJ dj) async {
    await _firestore.collection('users').doc(dj.id).delete();
  }

  @override
  Future<void> deleteBooker(Booker booker) async {
    await _firestore.collection('users').doc(booker.id).delete();
  }

  // update ###
  @override
  Future<void> updateGuest(Guest guest) async {
    await _firestore.collection('users').doc(guest.id).update({
      'name': guest.name,
      'favoriteUIds': guest.favoriteUIds,
      'avatarImageUrl': guest.avatarImageUrl,
      'isFlinta': guest.isFlinta,
    });
  }

  @override
  Future<void> updateDJ(DJ dj) async {
    await _firestore.collection('users').doc(dj.id).update({
      'name': dj.name,
      'city': dj.city,
      'about': dj.about,
      'info': dj.info,
      'headImageUrl': dj.headImageUrl,
      'avatarImageUrl': dj.avatarImageUrl,
      'genres': dj.genres,
      'bpm': dj.bpm,
      'streamingUrls': dj.streamingUrls,
      'mediaImageUrls': dj.mediaImageUrls,
      'favoriteUIds': dj.favoriteUIds,
    });
  }

  @override
  Future<void> updateBooker(Booker booker) async {
    await _firestore.collection('users').doc(booker.id).update({
      'name': booker.name,
      'city': booker.city,
      'about': booker.about,
      'info': booker.info,
      'headImageUrl': booker.headImageUrl,
      'avatarImageUrl': booker.avatarImageUrl,
      'mediaImageUrls': booker.mediaImageUrls,
      'category': booker.category,
      'favoriteUIds': booker.favoriteUIds,
    });
  }

  // read ###
  @override
  Future<DJ> getProfileDJ() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("no authenticated user");
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (data == null || data['type'] != 'dj') throw Exception("DJ not found");
    return DJ.fromJson(uid, data);
  }

  @override
  Future<Booker> getProfileBooker() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("no authenticated user");
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (data == null || data['type'] != 'booker') {
      throw Exception("booker not found");
    }
    return Booker.fromJson(uid, data);
  }

  @override
  Future<List<DJ>> getDJs() async {
    final currentUser = await getCurrentUser();

    final blockedSnapshot =
        await _firestore
            .collection('users')
            .doc(currentUser.id)
            .collection('blocks')
            .get();

    final blockedUids = blockedSnapshot.docs.map((doc) => doc.id).toSet();

    final snapshot =
        await _firestore
            .collection('users')
            .where('type', isEqualTo: 'dj')
            .get();

    return snapshot.docs
        .where(
          (doc) => doc.id != currentUser.id && !blockedUids.contains(doc.id),
        )
        .map((doc) => DJ.fromJson(doc.id, doc.data()))
        .toList();
  }

  @override
  Future<List<DJ>> getFavoriteDJs(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data();

    final favoriteIds = List<String>.from(data?['favoriteUIds'] ?? []);

    final List<DJ> favoriteDJs = [];

    for (final id in favoriteIds) {
      final doc = await _firestore.collection('users').doc(id).get();

      if (doc.exists) {
        final type = doc.data()?['type'];
        if (type?.toString().toLowerCase() == 'dj') {
          favoriteDJs.add(DJ.fromJson(doc.id, doc.data()!));
        }
      }
    }

    return favoriteDJs;
  }

  @override
  Future<List<DJ>> searchDJs({
    String? city,
    List<String>? genres,
    List<int>? bpmRange,
  }) async {
    final all = await getDJs();
    return all.where((dj) {
      final matchesCity =
          city == null ||
          city.trim().isEmpty ||
          dj.city.toLowerCase().contains(city.toLowerCase());
      final matchesGenres =
          genres == null ||
          genres.isEmpty ||
          genres.any((g) => dj.genres.contains(g));
      final matchesBpm =
          bpmRange == null ||
          bpmRange.length != 2 ||
          (dj.bpm.last >= bpmRange[0] && dj.bpm.first <= bpmRange[1]);
      return matchesCity && matchesGenres && matchesBpm;
    }).toList();
  }

  /// CHAT ###

  @override
  Future<void> sendMessage(ChatMessage message) async {
    final chatId = getChatId(message.senderId, message.receiverId);
    final docRef =
        _firestore.collection('chats').doc(chatId).collection('messages').doc();

    final newMessage = ChatMessage(
      id: docRef.id,
      senderId: message.senderId,
      receiverId: message.receiverId,
      message: message.message,
      timestamp: message.timestamp,
      read: message.read,
    );

    await docRef.set(newMessage.toJson());
    final chatDoc = _firestore.collection('chats').doc(chatId);

    await chatDoc.set({
      'lastMessage': newMessage.message,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': [message.senderId, message.receiverId],
      'lastMessageId': newMessage.id,
      'lastSenderId': newMessage.senderId,
    }, SetOptions(merge: true));
  }

  @override
  Stream<List<ChatMessage>> getChatsStream(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((querySnapshot) async {
          List<ChatMessage> allMessages = [];

          for (var doc in querySnapshot.docs) {
            final data = doc.data();
            final chatId = doc.id;
            final lastMessage = data['lastMessage'] as String? ?? '';
            final timestamp = (data['lastTimestamp'] as Timestamp?)?.toDate();
            final participants = List<String>.from(data['participants'] ?? []);
            final senderId = data['lastSenderId'] as String? ?? userId;

            final receiverId = participants.firstWhere(
              (id) => id != userId,
              orElse: () => '',
            );

            if (receiverId.isEmpty || timestamp == null) continue;

            final messagesQuery =
                await _firestore
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .get();

            String messageId = chatId;
            bool read = false;
            if (messagesQuery.docs.isNotEmpty) {
              final lastMsgDoc = messagesQuery.docs.first;
              final lastMsgData = lastMsgDoc.data();
              messageId = lastMsgDoc.id;
              read = lastMsgData['read'] ?? false;
            }

            allMessages.add(
              ChatMessage(
                id: messageId,
                senderId: senderId,
                receiverId: receiverId,
                message: lastMessage,
                timestamp: timestamp,
                read: read,
              ),
            );
          }

          return allMessages;
        });
  }

  @override
  Stream<List<ChatMessage>> getMessagesStream(
    String senderId,
    String receiverId,
  ) {
    final chatId = getChatId(senderId, receiverId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data();
                return ChatMessage.fromJson(doc.id, data);
              }).toList(),
        );
  }

  /// UTILS ###
  @override
  Future<void> blockUser(String currentUid, String targetUid) async {
    final firestore = FirebaseFirestore.instance;

    final now = FieldValue.serverTimestamp();

    final currentUserBlockRef = firestore
        .collection('users')
        .doc(currentUid)
        .collection('blocks')
        .doc(targetUid);

    await currentUserBlockRef.set({'timestamp': now});
  }

  @override
  Future<void> unblockUser(String currentUid, String targetUid) async {
    final firestore = FirebaseFirestore.instance;

    final currentUserBlockRef = firestore
        .collection('users')
        .doc(currentUid)
        .collection('blocks')
        .doc(targetUid);

    await currentUserBlockRef.delete();
  }

  @override
  Future<List<AppUser>> getBlockedUsers(String currentUid) async {
    final firestore = FirebaseFirestore.instance;

    final blockedSnapshot =
        await firestore
            .collection('users')
            .doc(currentUid)
            .collection('blocks')
            .get();

    final blockedUids = blockedSnapshot.docs.map((doc) => doc.id).toList();

    List<AppUser> blockedUsers = [];

    for (final uid in blockedUids) {
      try {
        final userDoc = await firestore.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          final type = data['type'] as String? ?? 'guest';

          switch (type) {
            case 'dj':
              blockedUsers.add(DJ.fromJson(uid, data));
              break;
            case 'booker':
              blockedUsers.add(Booker.fromJson(uid, data));
              break;
            case 'guest':
              blockedUsers.add(Guest.fromJson(uid, data));
              break;
          }
        }
      } catch (e) {
        continue;
      }
    }

    return blockedUsers;
  }

  Future<List<ChatMessage>> getMessages(String userId, String partnerId) async {
    final chatId = getChatId(userId, partnerId);
    final snapshot =
        await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp')
            .get();
    return snapshot.docs
        .map((doc) => ChatMessage.fromJson(doc.id, doc.data()))
        .toList();
  }

  Future<void> markMessageAsRead(
    String messageId,
    String userId,
    String partnerId,
    String currentUserId,
  ) async {
    final chatId = getChatId(userId, partnerId);

    // Update the individual message read status
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    await messageRef.update({'read': true});

    // CRITICAL: Also update the chat document's lastRead status
    // This is what the chat list uses for the unread indicator
    final chatRef = _firestore.collection('chats').doc(chatId);
    await chatRef.update({'lastRead': true});
  }

  @override
  Future<void> deleteMessage(
    String chatId,
    String messageId,
    String currentUserId,
  ) async {
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    final msgDoc = await messageRef.get();
    if (!msgDoc.exists) {
      throw Exception('message not found');
    }
    final data = msgDoc.data();
    if (data == null || data['senderId'] != currentUserId) {
      throw Exception('You can only delete your own messages');
    }
    await messageRef.delete();
  }

  @override
  Future<void> deleteChat(String userId, String partnerId) async {
    final chatId = getChatId(userId, partnerId);
    final chatDoc = _firestore.collection('chats').doc(chatId);

    final messagesQuery = await chatDoc.collection('messages').get();
    for (final msgDoc in messagesQuery.docs) {
      await msgDoc.reference.delete();
    }

    await chatDoc.delete();
  }

  @override
  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return sorted.join('_');
  }

  @override
  Future<AppUser> getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("no user logged in");

    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    if (!doc.exists || doc.data() == null) {
      throw Exception("failed to load user data");
    }

    final data = doc.data()!;

    final type = data['type'] as String? ?? 'guest';

    switch (type) {
      case 'dj':
        return DJ.fromJson(user.uid, data);
      case 'booker':
        return Booker.fromJson(user.uid, data);
      case 'guest':
        return Guest.fromJson(user.uid, data);
      default:
        throw Exception("Unknown user type: $type");
    }
  }

  @override
  Future<AppUser> getUserById(String id) async {
    final doc = await _firestore.collection('users').doc(id).get();
    if (!doc.exists) throw Exception("user id '$id' nicht not found");

    final data = doc.data();
    if (data == null) throw Exception("no data for user");

    final type = data['type'] as String?;

    switch (type) {
      case 'dj':
        return DJ.fromJson(id, data);
      case 'booker':
        return Booker.fromJson(id, data);
      case 'guest':
        return Guest.fromJson(id, data);
      default:
        throw Exception("unknown user type: $type");
    }
  }

  @override
  Future<void> updateUser(AppUser user) async {
    if (user is DJ) {
      await updateDJ(user);
    } else if (user is Booker) {
      await updateBooker(user);
    } else if (user is Guest) {
      await updateGuest(user);
    }
    notifyListeners();
  }

  @override
  Future<void> initFirebaseMessaging() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      String? token = await messaging.getToken();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }

      messaging.onTokenRefresh.listen((newToken) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'fcmToken': newToken}, SetOptions(merge: true));
        }
      });
    } catch (_) {
      // Don't rethrow - this is not critical for app functionality
    }
  }

  /// STATUS MESSAGES ###

  @override
  Future<void> createStatusMessage(StatusMessage statusMessage) async {
    try {
      final existingStatusQuery =
          await _firestore
              .collection('status_messages')
              .where('userId', isEqualTo: statusMessage.userId)
              .get();

      for (final doc in existingStatusQuery.docs) {
        await doc.reference.delete();
      }

      await _firestore
          .collection('status_messages')
          .doc(statusMessage.id)
          .set(statusMessage.toJson());
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<StatusMessage?> getActiveStatusMessage(String userId) async {
    try {
      final query =
          await _firestore
              .collection('status_messages')
              .where('userId', isEqualTo: userId)
              .limit(5)
              .get();

      if (query.docs.isEmpty) return null;

      for (final doc in query.docs) {
        final statusMessage = StatusMessage.fromJson(doc.id, doc.data());
        if (!statusMessage.isExpired) {
          return statusMessage;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteStatusMessage(String statusMessageId) async {
    try {
      await _firestore
          .collection('status_messages')
          .doc(statusMessageId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  // =============================================================================
  // GROUP CHAT MANAGEMENT SECTION
  // =============================================================================

  /// Creates a new group chat document in Firestore
  /// Generates a unique document ID and returns the group chat with the assigned ID
  @override
  Future<GroupChat> createGroupChat(GroupChat groupChat) async {
    try {
      final docRef = await _firestore
          .collection('group_chats')
          .add(groupChat.toJson());

      return groupChat.copyWith(id: docRef.id);
    } catch (e) {
      rethrow;
    }
  }

  /// Retrieves a group chat by its associated rave ID
  /// Returns null if no active group chat exists for the rave
  @override
  Future<GroupChat?> getGroupChatByRaveId(String raveId) async {
    try {
      final query =
          await _firestore
              .collection('group_chats')
              .where('raveId', isEqualTo: raveId)
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      return GroupChat.fromJson(doc.id, doc.data());
    } catch (e) {
      return null;
    }
  }

  @override
  Future<GroupChat?> getGroupChatById(String groupChatId) async {
    try {
      final doc =
          await _firestore.collection('group_chats').doc(groupChatId).get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      return GroupChat.fromJson(doc.id, data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateGroupChat(GroupChat groupChat) async {
    try {
      await _firestore
          .collection('group_chats')
          .doc(groupChat.id)
          .update(groupChat.toJson());
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<GroupChat>> getUserGroupChats(String userId) async {
    try {
      final query =
          await _firestore
              .collection('group_chats')
              .where('memberIds', arrayContains: userId)
              .where('isActive', isEqualTo: true)
              .orderBy('lastMessageTimestamp', descending: true)
              .get();

      final groupChats =
          query.docs.map((doc) {
            return GroupChat.fromJson(doc.id, doc.data());
          }).toList();

      return groupChats;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> sendGroupMessage(GroupMessage message) async {
    try {
      // Use subcollection approach with generated doc ref (like regular chat)
      final docRef =
          _firestore
              .collection('group_chats')
              .doc(message.groupChatId)
              .collection('messages')
              .doc();

      final newMessage = GroupMessage(
        id: docRef.id,
        groupChatId: message.groupChatId,
        senderId: message.senderId,
        senderName: message.senderName,
        senderAvatarUrl: message.senderAvatarUrl,
        message: message.message,
        timestamp: message.timestamp,
        readBy: message.readBy,
      );

      await docRef.set(newMessage.toJson());

      // Update the group chat's last message
      await updateGroupChatLastMessage(message.groupChatId, newMessage);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<List<GroupMessage>> getGroupMessagesStream(String groupChatId) {
    // Use subcollection approach to match regular chat pattern
    return _firestore
        .collection('group_chats')
        .doc(groupChatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .handleError((error) {
          return const Stream.empty();
        })
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return GroupMessage.fromJson(doc.id, doc.data());
          }).toList();
        });
  }

  @override
  Future<void> markGroupMessageAsRead(
    String groupChatId,
    String messageId,
    String userId,
  ) async {
    try {
      await _firestore
          .collection('group_chats')
          .doc(groupChatId)
          .collection('messages')
          .doc(messageId)
          .update({'readBy.$userId': true});
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateGroupChatLastMessage(
    String groupChatId,
    GroupMessage message,
  ) async {
    try {
      await _firestore.collection('group_chats').doc(groupChatId).update({
        'lastMessage': message.message,
        'lastMessageSenderId': message.senderId,
        'lastMessageTimestamp': Timestamp.fromDate(message.timestamp),
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteExpiredGroupChats() async {
    try {
      final now = DateTime.now();
      final query =
          await _firestore
              .collection('group_chats')
              .where('autoDeleteAt', isLessThan: Timestamp.fromDate(now))
              .where('isActive', isEqualTo: true)
              .get();

      for (final doc in query.docs) {
        final batch = _firestore.batch();

        // Mark group chat as inactive
        batch.update(doc.reference, {'isActive': false});

        // Delete all messages in this group chat (using subcollection)
        final messagesQuery = await doc.reference.collection('messages').get();

        for (final messageDoc in messagesQuery.docs) {
          batch.delete(messageDoc.reference);
        }

        await batch.commit();
      }
    } catch (e) {
      // Silent error handling
    }
  }

  @override
  Future<void> updateGroupChatImage(String groupChatId, String imageUrl) async {
    try {
      await _firestore.collection('group_chats').doc(groupChatId).update({
        'imageUrl': imageUrl,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Default implementation - no caching, so no refresh needed
  @override
  Future<void> forceRefreshChatList(String userId) async {
    // Base implementation does nothing since there's no caching
  }

  // =============================================================================
  // RAVE MANAGEMENT SECTION
  // =============================================================================

  /// Updates a rave document in Firestore
  @override
  Future<void> updateRave(String raveId, Map<String, dynamic> updates) async {
    try {
      // Always update the updatedAt timestamp
      final updatesWithTimestamp = Map<String, dynamic>.from(updates);
      updatesWithTimestamp['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore
          .collection('raves')
          .doc(raveId)
          .update(updatesWithTimestamp);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a rave document from Firestore
  /// Also cleans up associated group chat if it exists
  @override
  Future<void> deleteRave(String raveId) async {
    try {
      final batch = _firestore.batch();

      // Get the rave document first to check for group chat
      final raveDoc = await _firestore.collection('raves').doc(raveId).get();

      if (raveDoc.exists) {
        final raveData = raveDoc.data();
        final groupChatId = raveData?['groupChatId'] as String?;

        // Delete the rave document
        batch.delete(raveDoc.reference);

        // If there's an associated group chat, clean it up
        if (groupChatId != null && groupChatId.isNotEmpty) {
          final groupChatRef = _firestore
              .collection('group_chats')
              .doc(groupChatId);

          // Mark group chat as inactive
          batch.update(groupChatRef, {'isActive': false});

          // Delete all messages in the group chat
          final messagesQuery = await groupChatRef.collection('messages').get();
          for (final messageDoc in messagesQuery.docs) {
            batch.delete(messageDoc.reference);
          }
        }

        await batch.commit();
      }
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // PUBLIC GROUP CHAT METHODS (for rave attendees)
  // ============================================================================

  @override
  Future<PublicGroupChat> createPublicGroupChat(
    PublicGroupChat publicGroupChat,
  ) async {
    try {
      final docRef = await _firestore
          .collection('public_group_chats')
          .add(publicGroupChat.toJson());

      return publicGroupChat.copyWith(id: docRef.id);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<PublicGroupChat?> getPublicGroupChatByRaveId(String raveId) async {
    try {
      final query =
          await _firestore
              .collection('public_group_chats')
              .where('raveId', isEqualTo: raveId)
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return PublicGroupChat.fromJson(doc.id, doc.data());
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<PublicGroupChat?> getPublicGroupChatById(
    String publicGroupChatId,
  ) async {
    try {
      final doc =
          await _firestore
              .collection('public_group_chats')
              .doc(publicGroupChatId)
              .get();

      if (doc.exists && doc.data() != null) {
        return PublicGroupChat.fromJson(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updatePublicGroupChat(PublicGroupChat publicGroupChat) async {
    try {
      await _firestore
          .collection('public_group_chats')
          .doc(publicGroupChat.id)
          .update(publicGroupChat.toJson());
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<PublicGroupChat>> getUserPublicGroupChats(String userId) async {
    try {
      final query =
          await _firestore
              .collection('public_group_chats')
              .where('memberIds', arrayContains: userId)
              .get();

      // Filter active chats and sort in memory
      final publicChats =
          query.docs
              .map((doc) => PublicGroupChat.fromJson(doc.id, doc.data()))
              .where((chat) => chat.isActive)
              .toList();

      // Sort by lastMessageTimestamp in memory
      publicChats.sort((a, b) {
        if (a.lastMessageTimestamp == null && b.lastMessageTimestamp == null) {
          return 0;
        }
        if (a.lastMessageTimestamp == null) return 1;
        if (b.lastMessageTimestamp == null) return -1;
        return b.lastMessageTimestamp!.compareTo(a.lastMessageTimestamp!);
      });

      return publicChats;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> sendPublicGroupMessage(PublicGroupMessage message) async {
    try {
      await _firestore
          .collection('public_group_chats')
          .doc(message.publicGroupChatId)
          .collection('messages')
          .add(message.toJson());

      // Update the public group chat's last message
      await updatePublicGroupChatLastMessage(
        message.publicGroupChatId,
        message,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<List<PublicGroupMessage>> getPublicGroupMessagesStream(
    String publicGroupChatId,
  ) {
    return _firestore
        .collection('public_group_chats')
        .doc(publicGroupChatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => PublicGroupMessage.fromJson(doc.id, doc.data()))
                  .toList(),
        );
  }

  @override
  Future<void> updatePublicGroupChatLastMessage(
    String publicGroupChatId,
    PublicGroupMessage message,
  ) async {
    try {
      await _firestore
          .collection('public_group_chats')
          .doc(publicGroupChatId)
          .update({
            'lastMessage': message.content,
            'lastMessageSenderId': message.senderId,
            'lastMessageTimestamp': Timestamp.fromDate(message.timestamp),
            'autoDeleteAt': Timestamp.fromDate(
              DateTime.now().add(
                Duration(hours: 24),
              ), // Reset auto-delete timer
            ),
          });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteExpiredPublicGroupChats() async {
    try {
      final now = DateTime.now();
      final query =
          await _firestore
              .collection('public_group_chats')
              .where('autoDeleteAt', isLessThan: Timestamp.fromDate(now))
              .where('isActive', isEqualTo: true)
              .get();

      for (final doc in query.docs) {
        final batch = _firestore.batch();

        // Mark public group chat as inactive
        batch.update(doc.reference, {'isActive': false});

        // Delete all messages in this public group chat
        final messagesQuery = await doc.reference.collection('messages').get();
        for (final messageDoc in messagesQuery.docs) {
          batch.delete(messageDoc.reference);
        }

        await batch.commit();
      }
    } catch (e) {
      rethrow;
    }
  }
}
