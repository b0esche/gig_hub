import '../../../../Data/app_imports.dart';
import '../../../auth/presentation/guest_username_dialog.dart';

class JoinPublicGroupChatDialog extends StatefulWidget {
  final String raveId;
  final String raveTitle;
  final AppUser currentUser;
  final VoidCallback? onJoinChat;

  const JoinPublicGroupChatDialog({
    super.key,
    required this.raveId,
    required this.raveTitle,
    required this.currentUser,
    this.onJoinChat,
  });

  @override
  State<JoinPublicGroupChatDialog> createState() =>
      _JoinPublicGroupChatDialogState();
}

class _JoinPublicGroupChatDialogState extends State<JoinPublicGroupChatDialog> {
  bool _isLoading = false;

  Future<void> _handleJoinPublicGroupChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = context.read<DatabaseRepository>();

      // Check if user is a Guest and needs a username
      if (widget.currentUser is Guest) {
        final guest = widget.currentUser as Guest;
        if (guest.name.isEmpty) {
          // Show username dialog first
          final updatedGuest = await showDialog<Guest>(
            context: context,
            barrierDismissible: false,
            builder: (context) => GuestUsernameDialog(guestUser: guest),
          );

          if (updatedGuest == null) {
            // User cancelled username creation
            if (mounted) {
              Navigator.of(context).pop();
            }
            return;
          }
        }
      }

      // Check if PUBLIC group chat already exists for this rave
      PublicGroupChat? existingPublicChat = await db.getPublicGroupChatByRaveId(
        widget.raveId,
      );

      if (existingPublicChat == null) {
        // Create new PUBLIC group chat (separate from private group chat)
        final publicGroupChatName = widget.raveTitle;

        final newPublicGroupChat = PublicGroupChat(
          id: '', // Will be set by repository
          raveId: widget.raveId,
          name: publicGroupChatName,
          memberIds: [widget.currentUser.id],
          createdAt: DateTime.now(),
          autoDeleteAt: DateTime.now().add(
            Duration(hours: 24),
          ), // 24 hours from creation
        );

        existingPublicChat = await db.createPublicGroupChat(newPublicGroupChat);
      } else {
        // Add user to existing PUBLIC group chat if not already a member
        if (!existingPublicChat.memberIds.contains(widget.currentUser.id)) {
          final updatedMemberIds = [
            ...existingPublicChat.memberIds,
            widget.currentUser.id,
          ];
          final updatedChat = existingPublicChat.copyWith(
            memberIds: updatedMemberIds,
            memberCount: updatedMemberIds.length,
          );

          await db.updatePublicGroupChat(updatedChat);
          existingPublicChat = updatedChat;
        }
      }

      if (widget.onJoinChat != null) {
        widget.onJoinChat!();
      }

      if (mounted) {
        // Show success message
        Navigator.of(context).pop();

        // Navigate to PUBLIC group chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => PublicGroupChatScreen(
                  publicGroupChat: existingPublicChat!,
                  currentUser: widget.currentUser,
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Palette.alarmRed,
            content: Text(
              'Failed to join public group chat. Please try again.',
              style: TextStyle(color: Palette.glazedWhite),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.primalBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.group_outlined, color: Palette.forgedGold, size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Join Public Group Chat?',
              style: TextStyle(
                color: Palette.glazedWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Join the public group chat for "${widget.raveTitle}" to connect with other attendees!',
            style: TextStyle(
              color: Palette.glazedWhite.o(0.8),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Palette.forgedGold.o(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Palette.forgedGold.o(0.3), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Palette.forgedGold, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This chat is temporary and will be deleted after the rave.',
                    style: TextStyle(
                      color: Palette.glazedWhite.o(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Maybe Later',
            style: TextStyle(color: Palette.glazedWhite.o(0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _handleJoinPublicGroupChat(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Palette.forgedGold,
            foregroundColor: Palette.primalBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child:
              _isLoading
                  ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Palette.primalBlack,
                      ),
                    ),
                  )
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_add, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Join Chat',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
        ),
      ],
    );
  }
}
