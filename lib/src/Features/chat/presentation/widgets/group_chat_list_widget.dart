import '../../../../Data/app_imports.dart';
import '../group_chat_screen.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Widget displaying a list of group chats for the current user
/// Features:
/// - Real-time group chat updates via FutureBuilder with refresh mechanism
/// - AES-256 encrypted message preview decryption
/// - Group image display with fallback icons
/// - Member count display
/// - Navigation to individual group chat screens
class GroupChatListWidget extends StatefulWidget {
  final String currentUserId;

  const GroupChatListWidget({super.key, required this.currentUserId});

  @override
  State<GroupChatListWidget> createState() => _GroupChatListWidgetState();
}

class _GroupChatListWidgetState extends State<GroupChatListWidget> {
  final FirestoreDatabaseRepository _db = FirestoreDatabaseRepository();

  /// Refresh key used to force FutureBuilder rebuild when returning from group chat
  /// Incremented to trigger fresh data fetch and ensure UI shows latest changes
  int _refreshKey = 0;

  /// Fetches both regular group chats and public group chats
  Future<Map<String, dynamic>> _fetchAllChats() async {
    final groupChats = await _db.getUserGroupChats(widget.currentUserId);
    final publicGroupChats = await _db.getUserPublicGroupChats(
      widget.currentUserId,
    );

    return {'groupChats': groupChats, 'publicGroupChats': publicGroupChats};
  }

  /// Decrypts encrypted group chat message previews for display
  /// Handles the same AES-256 encryption format as direct chats
  /// Returns error messages for malformed or undecryptable content
  String _decryptPreview(String text) {
    final keyString = dotenv.env['ENCRYPTION_KEY'];
    if (keyString == null || keyString.length != 32) {
      return '[key error]';
    }

    if (!text.startsWith('enc::')) {
      return text;
    }

    try {
      final key = encrypt.Key.fromUtf8(keyString);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      final parts = text.substring(5).split(':');
      if (parts.length != 2) return '[format error]';

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encryptedData = parts[1];

      return encrypter.decrypt64(encryptedData, iv: iv);
    } catch (e) {
      return '[decoding error]';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(_refreshKey), // Use refresh key to force rebuild
      future: _fetchAllChats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Palette.forgedGold),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'error loading group chats',
                  style: TextStyle(color: Palette.glazedWhite),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(
                    color: Palette.glazedWhite.o(0.7),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final chatsData = snapshot.data ?? {};
        final groupChats = (chatsData['groupChats'] as List<GroupChat>?) ?? [];
        final publicGroupChats =
            (chatsData['publicGroupChats'] as List<PublicGroupChat>?) ?? [];
        final totalChats = groupChats.length + publicGroupChats.length;

        if (totalChats == 0) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.group_outlined,
                    color: Palette.glazedWhite.o(0.3),
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'no group chats yet',
                    style: TextStyle(
                      color: Palette.glazedWhite.o(0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'group chats will appear here when you create raves with group chat enabled',
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

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 16, bottom: 16),
          itemCount: totalChats,
          itemBuilder: (context, index) {
            if (index < groupChats.length) {
              // Display regular group chat
              return _buildGroupChatTile(groupChats[index]);
            } else {
              // Display public group chat
              final publicIndex = index - groupChats.length;
              return _buildPublicGroupChatTile(publicGroupChats[publicIndex]);
            }
          },
        );
      },
    );
  }

  Widget _buildGroupChatTile(GroupChat groupChat) {
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
            color:
                groupChat.imageUrl != null
                    ? Colors.transparent
                    : Palette.forgedGold.o(0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Palette.forgedGold, width: 2),
            image:
                groupChat.imageUrl != null
                    ? DecorationImage(
                      image: NetworkImage(groupChat.imageUrl!),
                      fit: BoxFit.cover,
                    )
                    : null,
          ),
          child:
              groupChat.imageUrl == null
                  ? Icon(Icons.group, color: Palette.forgedGold, size: 24)
                  : null,
        ),
        title: Text(
          groupChat.name,
          style: TextStyle(
            color: Palette.glazedWhite,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (groupChat.lastMessage != null) ...[
              Text(
                _decryptPreview(groupChat.lastMessage!),
                style: TextStyle(
                  color: Palette.glazedWhite.o(0.7),
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              Text(
                'no messages yet',
                style: TextStyle(
                  color: Palette.glazedWhite.o(0.5),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${groupChat.memberIds.length} members',
              style: TextStyle(color: Palette.glazedWhite.o(0.5), fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (groupChat.lastMessageTimestamp != null)
              Text(
                _formatTimestamp(groupChat.lastMessageTimestamp!),
                style: TextStyle(
                  color: Palette.glazedWhite.o(0.5),
                  fontSize: 11,
                ),
              ),
          ],
        ),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (context) => GroupChatScreen(
                    groupChat: groupChat,
                    currentUserId: widget.currentUserId,
                  ),
            ),
          );
          // Refresh the list when returning from group chat screen
          setState(() {
            _refreshKey++; // Increment to force FutureBuilder rebuild
          });
        },
      ),
    );
  }

  Widget _buildPublicGroupChatTile(PublicGroupChat publicGroupChat) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Palette.gigGrey.o(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.forgedGold.o(0.5), width: 1),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color:
                publicGroupChat.imageUrl != null
                    ? Colors.transparent
                    : Palette.forgedGold.o(0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Palette.forgedGold, width: 2),
            image:
                publicGroupChat.imageUrl != null
                    ? DecorationImage(
                      image: NetworkImage(publicGroupChat.imageUrl!),
                      fit: BoxFit.cover,
                    )
                    : null,
          ),
          child:
              publicGroupChat.imageUrl == null
                  ? Icon(Icons.public, color: Palette.forgedGold, size: 24)
                  : null,
        ),
        title: Text(
          publicGroupChat.name,
          style: TextStyle(
            color: Palette.glazedWhite,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (publicGroupChat.lastMessage != null) ...[
              Text(
                publicGroupChat.lastMessage!,
                style: TextStyle(
                  color: Palette.glazedWhite.o(0.7),
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              Text(
                'no messages yet',
                style: TextStyle(
                  color: Palette.glazedWhite.o(0.5),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.people, color: Palette.glazedWhite.o(0.5), size: 12),
                const SizedBox(width: 4),
                Text(
                  '${publicGroupChat.memberCount} members',
                  style: TextStyle(
                    color: Palette.glazedWhite.o(0.5),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (publicGroupChat.lastMessageTimestamp != null)
                  Text(
                    _formatTimestamp(publicGroupChat.lastMessageTimestamp!),
                    style: TextStyle(
                      color: Palette.glazedWhite.o(0.5),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
        onTap: () async {
          // Need to get current user data for navigation
          final currentUser = await _db.getUserById(widget.currentUserId);

          // Navigate to public group chat

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PublicGroupChatScreen(
                    publicGroupChat: publicGroupChat,
                    currentUser: currentUser,
                  ),
            ),
          );

          // Increment refresh key to trigger rebuild when returning
          if (result == 'refresh' || result == null) {
            setState(() {
              _refreshKey++;
            });
          }
        },
      ),
    );
  }

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
}
