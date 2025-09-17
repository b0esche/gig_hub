import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/chat_message.dart';
import '../models/group_chat.dart';
import '../models/group_message.dart';
import '../models/users.dart';

/// Comprehensive caching service to reduce Firebase queries and costs
///
/// Features:
/// - In-memory LRU cache for frequently accessed data
/// - Persistent storage for offline access
/// - TTL (Time To Live) for automatic cache invalidation
/// - Smart cache warming strategies
/// - Memory management to prevent out-of-memory issues
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Secure storage for persistent caching
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // In-memory caches with LRU eviction
  final Map<String, _CacheEntry<List<ChatMessage>>> _chatMessagesCache = {};
  final Map<String, _CacheEntry<List<GroupMessage>>> _groupMessagesCache = {};
  final Map<String, _CacheEntry<List<ChatMessage>>> _chatListCache = {};
  final Map<String, _CacheEntry<List<GroupChat>>> _groupChatsCache = {};
  final Map<String, _CacheEntry<AppUser>> _usersCache = {};
  final Map<String, _CacheEntry<List<DJ>>> _djListCache =
      {}; // Cache for DJ search results

  // Cache configuration
  static const int _maxCacheSize = 100; // Maximum entries per cache type
  static const Duration _defaultTtl = Duration(minutes: 15); // Default TTL
  static const Duration _userCacheTtl = Duration(
    hours: 1,
  ); // Users change less frequently
  static const Duration _messageCacheTtl = Duration(
    minutes: 5,
  ); // Messages need fresher data

  // Cache usage tracking for cost optimization analytics
  int _hitCount = 0;
  int _missCount = 0;

  /// Cache statistics for monitoring efficiency
  Map<String, dynamic> get stats => {
    'hitCount': _hitCount,
    'missCount': _missCount,
    'hitRate':
        _hitCount + _missCount > 0 ? _hitCount / (_hitCount + _missCount) : 0.0,
    'chatMessagesCacheSize': _chatMessagesCache.length,
    'groupMessagesCacheSize': _groupMessagesCache.length,
    'chatListCacheSize': _chatListCache.length,
    'groupChatsCacheSize': _groupChatsCache.length,
    'usersCacheSize': _usersCache.length,
    'djListCacheSize': _djListCache.length,
  };

  // =============================================================================
  // CHAT MESSAGES CACHING
  // =============================================================================

  /// Cache chat messages for a specific conversation
  void cacheChatMessages(String chatId, List<ChatMessage> messages) {
    _evictOldEntries(_chatMessagesCache);
    _chatMessagesCache[chatId] = _CacheEntry(
      data: List.from(messages), // Create a copy to avoid reference issues
      timestamp: DateTime.now(),
      ttl: _messageCacheTtl,
    );
    _persistChatMessages(chatId, messages);
  }

  /// Get cached chat messages, returns null if not cached or expired
  Future<List<ChatMessage>?> getCachedChatMessages(String chatId) async {
    final memoryResult = _getFromMemoryCache(_chatMessagesCache, chatId);
    if (memoryResult != null) {
      _hitCount++;
      return memoryResult;
    }

    // Try persistent storage
    final persistentResult = await _loadPersistedChatMessages(chatId);
    if (persistentResult != null) {
      // Warm up memory cache
      _chatMessagesCache[chatId] = _CacheEntry(
        data: persistentResult,
        timestamp: DateTime.now(),
        ttl: _messageCacheTtl,
      );
      _hitCount++;
      return persistentResult;
    }

    _missCount++;
    return null;
  }

  /// Update cached messages with new message (for real-time updates)
  void addMessageToCache(String chatId, ChatMessage message) {
    final cached = _getFromMemoryCache(_chatMessagesCache, chatId);
    if (cached != null) {
      final updatedMessages = List<ChatMessage>.from(cached)..add(message);
      cacheChatMessages(chatId, updatedMessages);
    }
  }

  // =============================================================================
  // GROUP MESSAGES CACHING
  // =============================================================================

  /// Cache group messages for a specific group chat
  void cacheGroupMessages(String groupChatId, List<GroupMessage> messages) {
    _evictOldEntries(_groupMessagesCache);
    _groupMessagesCache[groupChatId] = _CacheEntry(
      data: List.from(messages),
      timestamp: DateTime.now(),
      ttl: _messageCacheTtl,
    );
    _persistGroupMessages(groupChatId, messages);
  }

  /// Get cached group messages
  Future<List<GroupMessage>?> getCachedGroupMessages(String groupChatId) async {
    final memoryResult = _getFromMemoryCache(_groupMessagesCache, groupChatId);
    if (memoryResult != null) {
      _hitCount++;
      return memoryResult;
    }

    final persistentResult = await _loadPersistedGroupMessages(groupChatId);
    if (persistentResult != null) {
      _groupMessagesCache[groupChatId] = _CacheEntry(
        data: persistentResult,
        timestamp: DateTime.now(),
        ttl: _messageCacheTtl,
      );
      _hitCount++;
      return persistentResult;
    }

    _missCount++;
    return null;
  }

  /// Add new group message to cache
  void addGroupMessageToCache(String groupChatId, GroupMessage message) {
    final cached = _getFromMemoryCache(_groupMessagesCache, groupChatId);
    if (cached != null) {
      final updatedMessages = List<GroupMessage>.from(cached)..add(message);
      cacheGroupMessages(groupChatId, updatedMessages);
    }
  }

  // =============================================================================
  // CHAT LIST CACHING
  // =============================================================================

  /// Cache user's chat list (recent conversations)
  void cacheChatList(String userId, List<ChatMessage> chatList) {
    _evictOldEntries(_chatListCache);
    _chatListCache[userId] = _CacheEntry(
      data: List.from(chatList),
      timestamp: DateTime.now(),
      ttl: _defaultTtl,
    );
    _persistChatList(userId, chatList);
  }

  /// Get cached chat list
  Future<List<ChatMessage>?> getCachedChatList(String userId) async {
    final memoryResult = _getFromMemoryCache(_chatListCache, userId);
    if (memoryResult != null) {
      _hitCount++;
      return memoryResult;
    }

    final persistentResult = await _loadPersistedChatList(userId);
    if (persistentResult != null) {
      _chatListCache[userId] = _CacheEntry(
        data: persistentResult,
        timestamp: DateTime.now(),
        ttl: _defaultTtl,
      );
      _hitCount++;
      return persistentResult;
    }

    _missCount++;
    return null;
  }

  // =============================================================================
  // GROUP CHATS CACHING
  // =============================================================================

  /// Cache user's group chats
  void cacheGroupChats(String userId, List<GroupChat> groupChats) {
    _evictOldEntries(_groupChatsCache);
    _groupChatsCache[userId] = _CacheEntry(
      data: List.from(groupChats),
      timestamp: DateTime.now(),
      ttl: _defaultTtl,
    );
    _persistGroupChats(userId, groupChats);
  }

  /// Get cached group chats
  Future<List<GroupChat>?> getCachedGroupChats(String userId) async {
    final memoryResult = _getFromMemoryCache(_groupChatsCache, userId);
    if (memoryResult != null) {
      _hitCount++;
      return memoryResult;
    }

    final persistentResult = await _loadPersistedGroupChats(userId);
    if (persistentResult != null) {
      _groupChatsCache[userId] = _CacheEntry(
        data: persistentResult,
        timestamp: DateTime.now(),
        ttl: _defaultTtl,
      );
      _hitCount++;
      return persistentResult;
    }

    _missCount++;
    return null;
  }

  // =============================================================================
  // USER CACHING
  // =============================================================================

  /// Cache user data (for profile information in chats)
  void cacheUser(String userId, AppUser user) {
    _evictOldEntries(_usersCache);
    _usersCache[userId] = _CacheEntry(
      data: user,
      timestamp: DateTime.now(),
      ttl: _userCacheTtl,
    );
    _persistUser(userId, user);
  }

  /// Get cached user data
  Future<AppUser?> getCachedUser(String userId) async {
    final memoryResult = _getFromMemoryCache(_usersCache, userId);
    if (memoryResult != null) {
      _hitCount++;
      return memoryResult;
    }

    final persistentResult = await _loadPersistedUser(userId);
    if (persistentResult != null) {
      _usersCache[userId] = _CacheEntry(
        data: persistentResult,
        timestamp: DateTime.now(),
        ttl: _userCacheTtl,
      );
      _hitCount++;
      return persistentResult;
    }

    _missCount++;
    return null;
  }

  // =============================================================================
  // DJ SEARCH CACHING
  // =============================================================================

  /// Cache DJ search results
  void cacheDJList(String cacheKey, List<DJ> djs) {
    _evictOldEntries(_djListCache);
    _djListCache[cacheKey] = _CacheEntry(
      data: List.from(djs),
      timestamp: DateTime.now(),
      ttl: _userCacheTtl, // DJs don't change often
    );
    _persistDJList(cacheKey, djs);
  }

  /// Get cached DJ search results
  Future<List<DJ>?> getCachedDJList(String cacheKey) async {
    final memoryResult = _getFromMemoryCache(_djListCache, cacheKey);
    if (memoryResult != null) {
      _hitCount++;
      return memoryResult;
    }

    final persistentResult = await _loadPersistedDJList(cacheKey);
    if (persistentResult != null) {
      _djListCache[cacheKey] = _CacheEntry(
        data: persistentResult,
        timestamp: DateTime.now(),
        ttl: _userCacheTtl,
      );
      _hitCount++;
      return persistentResult;
    }

    _missCount++;
    return null;
  }

  /// Generate cache key for DJ search with parameters
  String generateDJSearchCacheKey({
    List<String>? genres,
    String? city,
    List<int>? bpmRange,
  }) {
    final genresKey = genres?.join(',') ?? 'all';
    final cityKey = city ?? 'all';
    final bpmKey = bpmRange != null ? '${bpmRange[0]}-${bpmRange[1]}' : 'all';
    return 'dj_search_${genresKey}_${cityKey}_$bpmKey';
  }

  // =============================================================================
  // CACHE MANAGEMENT
  // =============================================================================

  /// Clear all caches (useful for logout or memory pressure)
  Future<void> clearAllCaches() async {
    _chatMessagesCache.clear();
    _groupMessagesCache.clear();
    _chatListCache.clear();
    _groupChatsCache.clear();
    _usersCache.clear();
    _djListCache.clear();

    // Clear persistent storage
    await _storage.deleteAll();

    // Reset stats
    _hitCount = 0;
    _missCount = 0;
  }

  /// Clear expired entries from all caches
  void clearExpiredEntries() {
    _clearExpiredFromCache(_chatMessagesCache);
    _clearExpiredFromCache(_groupMessagesCache);
    _clearExpiredFromCache(_chatListCache);
    _clearExpiredFromCache(_groupChatsCache);
    _clearExpiredFromCache(_usersCache);
    _clearExpiredFromCache(_djListCache);
  }

  /// Invalidate specific chat cache (useful when data changes)
  void invalidateChatCache(String chatId) {
    _chatMessagesCache.remove(chatId);
    _storage.delete(key: 'chat_messages_$chatId');
  }

  /// Invalidate specific group chat cache
  void invalidateGroupChatCache(String groupChatId) {
    _groupMessagesCache.remove(groupChatId);
    _storage.delete(key: 'group_messages_$groupChatId');
  }

  /// Invalidate user cache (when user updates profile)
  void invalidateUserCache(String userId) {
    _usersCache.remove(userId);
    _storage.delete(key: 'user_$userId');
  }

  // =============================================================================
  // PRIVATE HELPER METHODS
  // =============================================================================

  /// Generic method to get data from memory cache with TTL check
  T? _getFromMemoryCache<T>(Map<String, _CacheEntry<T>> cache, String key) {
    final entry = cache[key];
    if (entry != null && !entry.isExpired) {
      return entry.data;
    } else if (entry != null && entry.isExpired) {
      cache.remove(key); // Remove expired entry
    }
    return null;
  }

  /// Evict old entries when cache reaches max size (LRU strategy)
  void _evictOldEntries<T>(Map<String, _CacheEntry<T>> cache) {
    if (cache.length >= _maxCacheSize) {
      // Sort by timestamp and remove oldest entries
      final sortedEntries =
          cache.entries.toList()
            ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

      final entriesToRemove = sortedEntries.take(
        cache.length - _maxCacheSize + 10,
      );
      for (final entry in entriesToRemove) {
        cache.remove(entry.key);
      }
    }
  }

  /// Clear expired entries from a specific cache
  void _clearExpiredFromCache<T>(Map<String, _CacheEntry<T>> cache) {
    final expiredKeys =
        cache.entries
            .where((entry) => entry.value.isExpired)
            .map((entry) => entry.key)
            .toList();

    for (final key in expiredKeys) {
      cache.remove(key);
    }
  }

  // =============================================================================
  // PERSISTENT STORAGE METHODS
  // =============================================================================

  Future<void> _persistChatMessages(
    String chatId,
    List<ChatMessage> messages,
  ) async {
    try {
      final jsonData = jsonEncode(messages.map((m) => m.toJson()).toList());
      await _storage.write(key: 'chat_messages_$chatId', value: jsonData);
    } catch (e) {
      // Silent fail for persistent storage errors
    }
  }

  Future<List<ChatMessage>?> _loadPersistedChatMessages(String chatId) async {
    try {
      final jsonData = await _storage.read(key: 'chat_messages_$chatId');
      if (jsonData != null) {
        final List<dynamic> decoded = jsonDecode(jsonData);
        return decoded
            .map((json) => ChatMessage.fromJson(json['id'], json))
            .toList();
      }
    } catch (e) {
      // Silent fail for persistent storage errors
    }
    return null;
  }

  Future<void> _persistGroupMessages(
    String groupChatId,
    List<GroupMessage> messages,
  ) async {
    try {
      final jsonData = jsonEncode(messages.map((m) => m.toJson()).toList());
      await _storage.write(key: 'group_messages_$groupChatId', value: jsonData);
    } catch (e) {
      // Silent fail for persistent storage errors
    }
  }

  Future<List<GroupMessage>?> _loadPersistedGroupMessages(
    String groupChatId,
  ) async {
    try {
      final jsonData = await _storage.read(key: 'group_messages_$groupChatId');
      if (jsonData != null) {
        final List<dynamic> decoded = jsonDecode(jsonData);
        return decoded
            .map((json) => GroupMessage.fromJson(json['id'], json))
            .toList();
      }
    } catch (e) {
      // Silent fail for persistent storage errors
    }
    return null;
  }

  Future<void> _persistChatList(
    String userId,
    List<ChatMessage> chatList,
  ) async {
    try {
      final jsonData = jsonEncode(chatList.map((m) => m.toJson()).toList());
      await _storage.write(key: 'chat_list_$userId', value: jsonData);
    } catch (e) {
      // Silent fail for persistent storage errors
    }
  }

  Future<List<ChatMessage>?> _loadPersistedChatList(String userId) async {
    try {
      final jsonData = await _storage.read(key: 'chat_list_$userId');
      if (jsonData != null) {
        final List<dynamic> decoded = jsonDecode(jsonData);
        return decoded
            .map((json) => ChatMessage.fromJson(json['id'], json))
            .toList();
      }
    } catch (e) {
      // Silent fail for persistent storage errors
    }
    return null;
  }

  Future<void> _persistGroupChats(
    String userId,
    List<GroupChat> groupChats,
  ) async {
    try {
      final jsonData = jsonEncode(groupChats.map((g) => g.toJson()).toList());
      await _storage.write(key: 'group_chats_$userId', value: jsonData);
    } catch (e) {
      // Silent fail for persistent storage errors
    }
  }

  Future<List<GroupChat>?> _loadPersistedGroupChats(String userId) async {
    try {
      final jsonData = await _storage.read(key: 'group_chats_$userId');
      if (jsonData != null) {
        final List<dynamic> decoded = jsonDecode(jsonData);
        return decoded
            .map((json) => GroupChat.fromJson(json['id'], json))
            .toList();
      }
    } catch (e) {
      // Silent fail for persistent storage errors
    }
    return null;
  }

  Future<void> _persistUser(String userId, AppUser user) async {
    try {
      Map<String, dynamic> jsonData;

      // Handle different user types
      if (user is DJ) {
        jsonData = user.toJson();
      } else if (user is Booker) {
        jsonData = user.toJson();
      } else if (user is Guest) {
        jsonData = user.toJson();
      } else {
        return; // Unknown user type, skip persistence
      }

      await _storage.write(key: 'user_$userId', value: jsonEncode(jsonData));
    } catch (e) {
      // Silent fail for persistent storage errors
    }
  }

  Future<AppUser?> _loadPersistedUser(String userId) async {
    try {
      final jsonData = await _storage.read(key: 'user_$userId');
      if (jsonData != null) {
        final Map<String, dynamic> decoded = jsonDecode(jsonData);
        final type = decoded['type'] as String? ?? 'guest';

        switch (type) {
          case 'dj':
            return DJ.fromJson(userId, decoded);
          case 'booker':
            return Booker.fromJson(userId, decoded);
          case 'guest':
            return Guest.fromJson(userId, decoded);
          default:
            return null;
        }
      }
    } catch (e) {
      // Silent fail for persistent storage errors
    }
    return null;
  }

  Future<void> _persistDJList(String cacheKey, List<DJ> djs) async {
    try {
      final jsonData = jsonEncode(djs.map((d) => d.toJson()).toList());
      await _storage.write(key: 'dj_list_$cacheKey', value: jsonData);
    } catch (e) {
      // Silent fail for persistent storage errors
    }
  }

  Future<List<DJ>?> _loadPersistedDJList(String cacheKey) async {
    try {
      final jsonData = await _storage.read(key: 'dj_list_$cacheKey');
      if (jsonData != null) {
        final List<dynamic> decoded = jsonDecode(jsonData);
        return decoded.map((json) => DJ.fromJson(json['id'], json)).toList();
      }
    } catch (e) {
      // Silent fail for persistent storage errors
    }
    return null;
  }
}

/// Internal cache entry with TTL support
class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  _CacheEntry({required this.data, required this.timestamp, required this.ttl});

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}
