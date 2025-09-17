import 'package:intl/intl.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../../../Data/app_imports.dart';
import 'widgets/group_chat_list_widget.dart';

/// Arguments passed to the ChatListScreen via navigation
/// Contains the current user information needed for chat operations
class ChatListScreenArgs {
  final AppUser currentUser;

  ChatListScreenArgs({required this.currentUser});
}

/// Main chat list screen displaying both direct chats and group chats
/// Features:
/// - Tabbed interface (Direct Chats / Group Chats)
/// - Real-time message updates via Firestore streams
/// - AES-256 message encryption/decryption
/// - Date-based message grouping
/// - Chat deletion functionality
/// - Unread message indicators
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with RouteAware, TickerProviderStateMixin {
  // Use cached database repository for cost optimization
  final db = CachedFirestoreRepository();

  // Route observer for detecting when user returns to this screen
  RouteObserver<PageRoute>? _routeObserver;

  // Tab controller for switching between Direct and Group chats
  late TabController _tabController;

  // Cache user data to avoid refetching
  final Map<String, AppUser> _userCache = {};

  // Cache the direct chats data and stream subscription
  List<ChatMessage>? _cachedDirectChats;
  StreamSubscription<List<ChatMessage>>? _directChatsSubscription;
  bool _isLoadingDirectChats = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupDirectChatsStream();
  }

  /// Set up the direct chats stream once and maintain the subscription
  void _setupDirectChatsStream() {
    _isLoadingDirectChats = true;

    // Force refresh to ensure we have the latest data
    db.forceRefreshChatList(widget.currentUser.id);

    _directChatsSubscription = db
        .getChatsStream(widget.currentUser.id)
        .listen(
          (chats) {
            if (mounted) {
              setState(() {
                _cachedDirectChats = chats;
                _isLoadingDirectChats = false;
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _isLoadingDirectChats = false;
              });
            }
          },
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver = RouteObserverProvider.of(context);
    _routeObserver?.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    _userCache.clear(); // Clear the cache when disposing
    _tabController.dispose(); // Dispose the tab controller
    _directChatsSubscription?.cancel(); // Cancel the stream subscription
    super.dispose();
  }

  @override
  void didPopNext() {
    // Refresh the chat list when user returns from a chat screen
    // This ensures new messages are immediately visible

    // Force refresh the cached chat list data
    db.forceRefreshChatList(widget.currentUser.id);

    // Cancel current subscription and restart it to get fresh data
    _directChatsSubscription?.cancel();
    _setupDirectChatsStream();
  }

  /// Decrypts AES-256 encrypted messages using the environment key
  /// Messages are stored with 'enc::' prefix followed by IV:encryptedData format
  /// Returns error messages for malformed or undecryptable content
  String _decryptMessage(String text) {
    final keyString = dotenv.env['ENCRYPTION_KEY'];
    if (keyString == null || keyString.length != 32) {
      return '[key error]';
    }

    // Skip decryption for non-encrypted messages
    if (!text.startsWith('enc::')) {
      return text;
    }

    try {
      final key = encrypt.Key.fromUtf8(keyString);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      // Parse the IV and encrypted data from the message format
      final parts = text.substring(5).split(':');
      if (parts.length != 2) return '[format error]';

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encryptedData = parts[1];

      return encrypter.decrypt64(encryptedData, iv: iv);
    } catch (e) {
      return '[decoding error]';
    }
  }

  /// Formats timestamps into human-readable relative time
  /// Shows days (d), hours (h), minutes (m), or 'now' for recent messages
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  /// Builds the chat entry list with date separators
  /// Fetches user data for each chat partner and organizes by date
  /// Returns a mixed list of DateTime objects (date headers) and ChatListItem objects
  Future<List<dynamic>> _buildChatEntries(
    List<ChatMessage> recentMessages,
  ) async {
    final List<ChatListItem> items = [];

    // Collect all unique partner IDs and group by partner ID
    final Map<String, ChatMessage> messagesByPartnerId = {};

    for (final msg in recentMessages) {
      // Determine who the chat partner is (not the current user)
      final partnerId =
          msg.senderId == widget.currentUser.id ? msg.receiverId : msg.senderId;

      // Only keep the most recent message per partner
      if (!messagesByPartnerId.containsKey(partnerId) ||
          msg.timestamp.isAfter(messagesByPartnerId[partnerId]!.timestamp)) {
        messagesByPartnerId[partnerId] = msg;
      }
    }

    // Identify which users we need to fetch (not in cache)
    final Set<String> userIdsToFetch = {};
    for (final partnerId in messagesByPartnerId.keys) {
      if (!_userCache.containsKey(partnerId)) {
        userIdsToFetch.add(partnerId);
      }
    }

    // Fetch only the users we don't have cached
    if (userIdsToFetch.isNotEmpty) {
      final List<Future<MapEntry<String, AppUser?>>> userFutures =
          userIdsToFetch.map((partnerId) async {
            try {
              final user = await db.getUserById(partnerId);
              return MapEntry(partnerId, user);
            } catch (e) {
              return MapEntry(partnerId, null);
            }
          }).toList();

      // Wait for all user fetches to complete in parallel
      final userResults = await Future.wait(userFutures);

      // Update cache with newly fetched users
      for (final result in userResults) {
        if (result.value != null) {
          _userCache[result.key] = result.value!;
        }
      }
    }

    // Build chat items using cached user data
    for (final entry in messagesByPartnerId.entries) {
      final partnerId = entry.key;
      final message = entry.value;
      final partnerUser = _userCache[partnerId];

      if (partnerUser != null) {
        items.add(ChatListItem(user: partnerUser, recent: message));
      }
    }

    // Sort by most recent message first
    items.sort((a, b) => b.recent.timestamp.compareTo(a.recent.timestamp));

    final List<dynamic> entries = [];
    DateTime? lastDate;

    // Group messages by date and add date headers
    for (final item in items) {
      final itemDate = DateTime(
        item.recent.timestamp.year,
        item.recent.timestamp.month,
        item.recent.timestamp.day,
      );

      // Add date separator if this is a new date
      if (lastDate == null || itemDate.isBefore(lastDate)) {
        entries.add(itemDate);
        lastDate = itemDate;
      }

      entries.add(item);
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.primalBlack,
      appBar: AppBar(
        leading: IconButton(
          onPressed: Navigator.of(context).pop,
          icon: const Icon(Icons.chevron_left_rounded, size: 36),
          color: Palette.glazedWhite,
        ),
        title: Text(AppLocale.chats.getString(context)),
        backgroundColor: Palette.primalBlack,
        iconTheme: IconThemeData(color: Palette.glazedWhite),
        titleTextStyle: TextStyle(color: Palette.glazedWhite, fontSize: 20),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Palette.forgedGold,
          labelColor: Palette.forgedGold,
          unselectedLabelColor: Palette.glazedWhite.o(0.7),
          tabs: [Tab(text: 'direct chats'), Tab(text: 'group chats')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Direct chats tab - shows 1-on-1 conversations
          _buildDirectChats(),
          // Group chats tab - shows multi-user group conversations
          GroupChatListWidget(currentUserId: widget.currentUser.id),
        ],
      ),
    );
  }

  /// Builds the direct chats tab content
  /// Uses cached data instead of StreamBuilder to avoid loading states on tab switches
  Widget _buildDirectChats() {
    // Show loading only if we're initially loading and have no cached data
    if (_isLoadingDirectChats && _cachedDirectChats == null) {
      return Center(
        child: CircularProgressIndicator(color: Palette.forgedGold),
      );
    }

    final recentMessages = _cachedDirectChats ?? [];

    // Show empty state if no chats exist
    if (recentMessages.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_outlined,
                color: Palette.glazedWhite.o(0.3),
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocale.noChats.getString(context),
                style: TextStyle(
                  color: Palette.glazedWhite.o(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'start chatting by visiting profiles and tapping the chat button',
                style: TextStyle(
                  color: Palette.glazedWhite.o(0.5),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Build the chat list with date grouping
    return FutureBuilder<List<dynamic>>(
      future: _buildChatEntries(recentMessages),
      builder: (context, asyncSnapshot) {
        if (!asyncSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final chatEntries = asyncSnapshot.data!;
        return ListView.builder(
          // Consistent padding with group chat list
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          itemCount: chatEntries.length,
          itemBuilder: (context, idx) {
            final entry = chatEntries[idx];

            // Render date header
            if (entry is DateTime) {
              final isToday = DateTime.now().difference(entry).inDays == 0;
              final formattedDate =
                  isToday
                      ? AppLocale.today.getString(context)
                      : DateFormat('MMM dd, yyyy').format(entry);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    formattedDate,
                    style: TextStyle(
                      color: Palette.glazedWhite.o(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }

            // Render individual chat tile
            if (entry is ChatListItem) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Palette.gigGrey.o(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Palette.gigGrey.o(0.5), width: 1),
                ),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Palette.forgedGold.o(0.2),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Palette.forgedGold, width: 2),
                      image:
                          entry.user.avatarUrl.isNotEmpty
                              ? DecorationImage(
                                image: NetworkImage(entry.user.avatarUrl),
                                fit: BoxFit.cover,
                              )
                              : null,
                    ),
                    child:
                        entry.user.avatarUrl.isEmpty
                            ? Icon(
                              Icons.person,
                              color: Palette.forgedGold,
                              size: 24,
                            )
                            : null,
                  ),
                  title: Text(
                    entry.user.displayName,
                    style: TextStyle(
                      color: Palette.glazedWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    entry.recent.message.startsWith('enc::')
                        ? _decryptMessage(entry.recent.message)
                        : entry.recent.message,
                    style: TextStyle(
                      color: Palette.glazedWhite.o(0.7),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatTimestamp(entry.recent.timestamp),
                        style: TextStyle(
                          color: Palette.glazedWhite.o(0.5),
                          fontSize: 11,
                        ),
                      ),
                      if (!entry.recent.read &&
                          entry.recent.senderId != widget.currentUser.id) ...[
                        const SizedBox(height: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Palette.forgedGold,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => ChatScreen(
                              chatPartner: entry.user,
                              currentUser: widget.currentUser,
                            ),
                      ),
                    );
                  },
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          backgroundColor: Palette.forgedGold,
                          title: Center(
                            child: Text(
                              ('${AppLocale.deleteChatMsg.getString(context)}${entry.user.displayName}?'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sometypeMono(
                                textStyle: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                AppLocale.cancel.getString(context),
                                style: TextStyle(color: Palette.primalBlack),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await db.deleteChat(
                                  widget.currentUser.id,
                                  entry.user.id,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              child: Text(
                                AppLocale.deleteChat.getString(context),
                                style: TextStyle(color: Palette.primalBlack),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}
