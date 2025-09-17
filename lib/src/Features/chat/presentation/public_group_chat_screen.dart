import '../../../Data/app_imports.dart';
import '../../auth/presentation/guest_username_dialog.dart';
import 'package:gig_hub/src/Common/widgets/safe_pinch_zoom.dart';
import 'package:gig_hub/src/Data/services/image_compression_service.dart';

/// Screen for public group chat associated with a rave
/// Allows all rave attendees to communicate in an open chat
class PublicGroupChatScreen extends StatefulWidget {
  final PublicGroupChat publicGroupChat;
  final AppUser currentUser;

  const PublicGroupChatScreen({
    super.key,
    required this.publicGroupChat,
    required this.currentUser,
  });

  @override
  State<PublicGroupChatScreen> createState() => _PublicGroupChatScreenState();
}

class _PublicGroupChatScreenState extends State<PublicGroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<List<PublicGroupMessage>> _messagesStream;
  PublicGroupChat? _currentChat;
  bool _isUploadingImage = false;
  bool _isFlinta = false; // Track FLINTA* status in state
  late AppUser _currentUser; // Local copy of current user

  // Cache for user data to avoid repeated database calls
  final Map<String, AppUser> _userCache = {};

  @override
  void initState() {
    super.initState();
    _currentChat = widget.publicGroupChat;
    _currentUser = widget.currentUser; // Initialize local copy
    _messagesStream = context
        .read<DatabaseRepository>()
        .getPublicGroupMessagesStream(widget.publicGroupChat.id);

    // Initialize FLINTA* status and refresh guest data if needed
    if (_currentUser is Guest) {
      final guest = _currentUser as Guest;
      _isFlinta = guest.isFlinta;

      // If guest name is empty, fetch the latest data from database
      if (guest.name.isEmpty) {
        _refreshGuestData();
      }
    }
  }

  Future<void> _refreshGuestData() async {
    if (_currentUser is! Guest) return;

    try {
      final db = context.read<DatabaseRepository>();
      final updatedUser = await db.getUserById(_currentUser.id);

      if (updatedUser is Guest && mounted) {
        setState(() {
          _currentUser = updatedUser;
          _isFlinta = updatedUser.isFlinta;
        });
      }
    } catch (e) {
      // Silent error handling
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Get user data with caching to avoid repeated database calls
  Future<AppUser?> _getCachedUser(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final user = await context.read<DatabaseRepository>().getUserById(userId);
      _userCache[userId] = user;
      return user;
    } catch (e) {
      return null;
    }
  }

  /// Load member information for the group info dialog
  Future<List<AppUser>> _loadMemberInformation() async {
    if (_currentChat?.memberIds == null || _currentChat!.memberIds.isEmpty) {
      return [];
    }

    final List<AppUser> members = [];

    for (final memberId in _currentChat!.memberIds) {
      try {
        final user = await _getCachedUser(memberId);
        if (user != null) {
          members.add(user);
        }
      } catch (e) {
        // Skip users that can't be loaded
        continue;
      }
    }

    return members;
  }

  /// Navigate to the profile screen based on user type
  void _navigateToProfile(AppUser user) {
    final db = context.read<DatabaseRepository>();

    if (user is DJ) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ProfileScreenDJ(
                dj: user,
                currentUser: _currentUser,
                showChatButton: true,
                showEditButton: true,
                showFavoriteIcon: true,
              ),
        ),
      );
    } else if (user is Booker) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ProfileScreenBooker(
                booker: user,
                db: db,
                showEditButton: true,
              ),
        ),
      );
    }
    // Guests don't have profile screens, so no navigation for them
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    try {
      final db = context.read<DatabaseRepository>();

      // Get user display name and type
      String senderName = _currentUser.displayName;
      String senderType = 'Guest'; // Default for public chats

      if (_currentUser is DJ) {
        senderType = 'DJ';
        senderName = (_currentUser as DJ).name;
      } else if (_currentUser is Booker) {
        senderType = 'Booker';
        senderName = (_currentUser as Booker).name;
      } else if (_currentUser is Guest) {
        final guest = _currentUser as Guest;

        // Ensure we use the guest's actual name if available, fallback to 'Guest'
        senderName = guest.name.isNotEmpty ? guest.name : 'Guest';
      }

      // Check if user is marked as FLINTA*
      bool isFlinta = false;
      if (_currentUser is Guest) {
        isFlinta = _isFlinta; // Use state variable
      }

      final newMessage = PublicGroupMessage(
        id: '', // Will be set by repository
        publicGroupChatId: widget.publicGroupChat.id,
        senderId: _currentUser.id,
        senderName: senderName,
        senderType: senderType,
        content: messageText,
        timestamp: DateTime.now(),
        isFlinta: isFlinta,
      );

      await db.sendPublicGroupMessage(newMessage);

      // Update the public group chat's last message
      await db.updatePublicGroupChatLastMessage(
        widget.publicGroupChat.id,
        newMessage,
      );

      _messageController.clear();

      // Scroll to bottom after sending (same as private chat)
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('failed to send message: $e')),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    }
  }

  Future<void> _toggleFlintaStatus() async {
    if (_currentUser is! Guest) return;

    final guest = _currentUser as Guest;
    final newFlintaStatus = !_isFlinta; // Use state variable

    try {
      final db = context.read<DatabaseRepository>();

      // Update the local guest object
      guest.isFlinta = newFlintaStatus;

      // Update in database
      await db.updateGuest(guest);

      if (mounted) {
        setState(() {
          _isFlinta = newFlintaStatus; // Update state variable
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('failed to update FLINTA* status')),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    }
  }

  Future<void> _onAvatarTapped(String senderId) async {
    // Don't allow starting chat with yourself
    if (senderId == widget.currentUser.id) return;

    try {
      final db = context.read<DatabaseRepository>();
      final senderUser = await db.getUserById(senderId);

      // Guest users can only chat with other Guest users
      if (widget.currentUser is Guest && mounted) {
        if (senderUser is! Guest) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(
                child: Text(
                  'guest users can only chat with other guests',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              backgroundColor: Palette.forgedGold,
            ),
          );
          return;
        }
      } else {
        // DJs and Bookers cannot start chats with Guest users
        if (senderUser is Guest && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(
                child: Text(
                  'cannot start chat with guest users',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              backgroundColor: Palette.forgedGold,
            ),
          );
          return;
        }
      }

      // Show confirmation dialog
      final shouldStartChat = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: Palette.gigGrey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Palette.forgedGold, width: 2),
              ),
              title: Text(
                'start direct chat?',
                style: TextStyle(
                  color: Palette.glazedWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'do you want to start a direct chat with ${senderUser.displayName}?',
                style: TextStyle(
                  color: Palette.glazedWhite.o(0.8),
                  fontSize: 14,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'cancel',
                    style: TextStyle(color: Palette.glazedWhite.o(0.7)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.forgedGold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'start chat',
                    style: TextStyle(
                      color: Palette.primalBlack,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
      );

      if (shouldStartChat == true && mounted) {
        // Navigate to chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatScreen(
                  chatPartner: senderUser,
                  currentUser: widget.currentUser,
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(
                'failed to get user information',
                style: TextStyle(fontSize: 16),
              ),
            ),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    }
  }

  Widget _buildMessageBubble(
    PublicGroupMessage message,
    bool isOwnMessage,
    bool showSenderInfo,
  ) {
    return Align(
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwnMessage && showSenderInfo) ...[
            GestureDetector(
              onTap: () => _onAvatarTapped(message.senderId),
              child: FutureBuilder<AppUser?>(
                future: _getCachedUser(message.senderId),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: Palette.forgedGold,
                    backgroundImage:
                        (user != null && user.avatarUrl.isNotEmpty)
                            ? NetworkImage(user.avatarUrl)
                            : null,
                    child:
                        (user == null || user.avatarUrl.isEmpty)
                            ? Icon(
                              Icons.person,
                              color: Palette.primalBlack,
                              size: 18,
                            )
                            : null,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (!isOwnMessage && !showSenderInfo) const SizedBox(width: 44),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: Stack(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: showSenderInfo && !isOwnMessage ? 6 : 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isOwnMessage
                              ? Palette.forgedGold
                              : Palette.glazedWhite,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isOwnMessage ? 16 : 4),
                        bottomRight: Radius.circular(isOwnMessage ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.primalBlack.o(0.1),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isOwnMessage
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                      children: [
                        if (showSenderInfo && !isOwnMessage)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    message.senderName,
                                    style: TextStyle(
                                      color: Palette.primalBlack.o(0.7),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (message.isFlinta == true) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: Text(
                                          'FL*',
                                          style: TextStyle(
                                            color: Palette.glazedWhite,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (message.senderType == 'DJ') ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Palette.forgedGold,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: Text(
                                          'DJ',
                                          style: TextStyle(
                                            color: Palette.primalBlack,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                if (message.senderType == 'Booker') ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Palette.primalBlack,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: Text(
                                          'B',
                                          style: TextStyle(
                                            color: Palette.glazedWhite,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                Text(
                                  '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Palette.primalBlack.o(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.only(
                            top: 2,
                            bottom: 2,
                            right: showSenderInfo && !isOwnMessage ? 0 : 60,
                          ),
                          child: Text(
                            message.content,
                            style: TextStyle(
                              color: Palette.primalBlack,
                              fontSize: 15,
                              wordSpacing: -0.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Only show positioned timestamp for own messages or when sender info is not shown
                  if (isOwnMessage || !showSenderInfo)
                    Positioned(
                      top: 8,
                      right: 10,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Palette.primalBlack.o(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeGuestUsername() async {
    if (_currentUser is! Guest) return;

    final guest = _currentUser as Guest;
    final newGuest = await showDialog<Guest?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GuestUsernameDialog(guestUser: guest),
    );

    if (newGuest != null && mounted) {
      setState(() {
        _currentUser = newGuest; // Update the local user with new data
      });
    }
  }

  Future<void> _leavePublicGroupChat() async {
    try {
      final db = context.read<DatabaseRepository>();

      // Remove user from the chat
      final updatedMemberIds =
          _currentChat!.memberIds
              .where((id) => id != widget.currentUser.id)
              .toList();

      final updatedChat = _currentChat!.copyWith(
        memberIds: updatedMemberIds,
        memberCount: updatedMemberIds.length,
      );

      await db.updatePublicGroupChat(updatedChat);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(
                'left the public group chat',
                style: TextStyle(fontSize: 16),
              ),
            ),
            backgroundColor: Palette.forgedGold,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('failed to leave chat: $e')),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    }
  }

  Future<void> _uploadGroupImage() async {
    if (_isUploadingImage) return; // Prevent multiple simultaneous uploads

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      // Compress the image
      final compressedImage = await ImageCompressionService.compressImage(
        File(image.path),
      );

      // Create a unique filename with timestamp
      final String fileName =
          'public_group_${widget.publicGroupChat.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('public_group_images')
          .child(fileName);

      final uploadTask = storageRef.putFile(
        compressedImage,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': widget.currentUser.id,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update the group chat document with the new image URL
      await FirebaseFirestore.instance
          .collection('public_group_chats')
          .doc(widget.publicGroupChat.id)
          .update({
            'imageUrl': downloadUrl,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      // Update local chat data to immediately reflect the change
      if (mounted) {
        setState(() {
          _currentChat = _currentChat?.copyWith(imageUrl: downloadUrl);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(
                'group image updated successfully!',
                style: TextStyle(fontSize: 16),
              ),
            ),
            backgroundColor: Palette.forgedGold,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(
                'failed to upload image: ${e.toString()}',
                style: TextStyle(fontSize: 16),
              ),
            ),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _showGroupInfo() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Palette.glazedWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Palette.forgedGold, width: 2),
            ),
            title: Text(
              'public group info',
              style: TextStyle(
                color: Palette.primalBlack,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group Icon Section
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Palette.forgedGold.o(0.2),
                          backgroundImage:
                              _currentChat?.imageUrl != null
                                  ? NetworkImage(_currentChat!.imageUrl!)
                                  : null,
                          child:
                              _currentChat?.imageUrl == null
                                  ? Icon(
                                    Icons.public,
                                    color: Palette.forgedGold,
                                    size: 40,
                                  )
                                  : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _uploadGroupImage,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Palette.forgedGold,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Palette.glazedWhite,
                                  width: 2,
                                ),
                              ),
                              child:
                                  _isUploadingImage
                                      ? Padding(
                                        padding: EdgeInsets.all(6.0),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Palette.glazedWhite,
                                              ),
                                        ),
                                      )
                                      : Icon(
                                        Icons.camera_alt,
                                        color: Palette.glazedWhite,
                                        size: 16,
                                      ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'members (${_currentChat?.memberCount ?? 0}):',
                    style: TextStyle(
                      color: Palette.primalBlack,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Member list
                  SizedBox(
                    height: 200,
                    child: FutureBuilder<List<AppUser>>(
                      future: _loadMemberInformation(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Palette.forgedGold,
                              ),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'error loading members',
                              style: TextStyle(
                                color: Palette.alarmRed,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        final members = snapshot.data ?? [];

                        if (members.isEmpty) {
                          return Center(
                            child: Text(
                              'no members found',
                              style: TextStyle(
                                color: Palette.primalBlack.o(0.7),
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      // Only allow navigation for DJs and Bookers
                                      if (member is DJ || member is Booker) {
                                        Navigator.of(
                                          context,
                                        ).pop(); // Close the dialog first
                                        _navigateToProfile(member);
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border:
                                            (member is DJ || member is Booker)
                                                ? Border.all(
                                                  color: Palette.forgedGold.o(
                                                    0.6,
                                                  ),
                                                  width: 2,
                                                )
                                                : null,
                                      ),
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Palette.forgedGold.o(
                                          0.3,
                                        ),
                                        backgroundImage:
                                            member.avatarUrl.isNotEmpty
                                                ? NetworkImage(member.avatarUrl)
                                                : null,
                                        child:
                                            member.avatarUrl.isEmpty
                                                ? Icon(
                                                  Icons.person,
                                                  color: Palette.primalBlack,
                                                  size: 16,
                                                )
                                                : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      member.displayName,
                                      style: TextStyle(
                                        color: Palette.primalBlack,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Show user type badge
                                  if (member is DJ) ...[
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Palette.forgedGold,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'DJ',
                                        style: TextStyle(
                                          color: Palette.primalBlack,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ] else if (member is Booker) ...[
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Palette.primalBlack,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'B',
                                        style: TextStyle(
                                          color: Palette.glazedWhite,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ] else if (member is Guest) ...[
                                    if (member.isFlinta) ...[
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'FL*',
                                          style: TextStyle(
                                            color: Palette.glazedWhite,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (_currentChat?.autoDeleteAt != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'auto-delete: ${_currentChat!.autoDeleteAt!.day.toString().padLeft(2, '0')}.${_currentChat!.autoDeleteAt!.month.toString().padLeft(2, '0')}.${_currentChat!.autoDeleteAt!.year}',
                      style: TextStyle(
                        color: Palette.primalBlack.o(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (widget.currentUser is Guest) ...[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _changeGuestUsername();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, color: Palette.forgedGold, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'change username',
                        style: TextStyle(color: Palette.forgedGold),
                      ),
                    ],
                  ),
                ),
                StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _isFlinta,
                          onChanged: (bool? value) async {
                            await _toggleFlintaStatus();
                            setDialogState(() {}); // Rebuild dialog
                          },
                          activeColor: Colors.deepPurple,
                        ),
                        Text(
                          'mark yourself as FLINTA*',
                          style: TextStyle(color: Palette.primalBlack),
                        ),
                      ],
                    );
                  },
                ),
              ],
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _leavePublicGroupChat();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.exit_to_app, color: Palette.alarmRed, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'leave chat',
                      style: TextStyle(color: Palette.alarmRed),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'close',
                  style: TextStyle(color: Palette.primalBlack),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 108,
        backgroundColor: Palette.glazedWhite,
        elevation: 1,
        iconTheme: IconThemeData(color: Palette.primalBlack),
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Palette.primalBlack, width: 1.5),
              ),
              child: SafePinchZoom(
                maxScale: 3.0,
                child: CircleAvatar(
                  backgroundColor: Palette.forgedGold.o(0.2),
                  radius: 42,
                  backgroundImage:
                      _currentChat?.imageUrl != null
                          ? NetworkImage(_currentChat!.imageUrl!)
                          : null,
                  child:
                      _currentChat?.imageUrl == null
                          ? Icon(
                            Icons.public,
                            color: Palette.forgedGold,
                            size: 32,
                          )
                          : null,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.publicGroupChat.name,
                    style: GoogleFonts.sometypeMono(
                      textStyle: TextStyle(
                        wordSpacing: -3,
                        overflow: TextOverflow.ellipsis,
                        color: Palette.primalBlack,
                        fontWeight: FontWeight.w500,
                        fontSize: 20,
                      ),
                    ),
                    maxLines: 1,
                  ),
                  Text(
                    '${widget.publicGroupChat.memberCount} members',
                    style: TextStyle(
                      color: Palette.primalBlack.o(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        leadingWidth: 32,
        actionsPadding: EdgeInsets.only(bottom: 42),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _showGroupInfo,
              style: ButtonStyle(
                elevation: WidgetStateProperty.all(3),
                tapTargetSize: MaterialTapTargetSize.padded,
                splashFactory: NoSplash.splashFactory,
              ),
              icon: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Palette.primalBlack.o(0.85),
                  border: Border.all(color: Palette.shadowGrey, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Palette.primalBlack.o(0.85),
                      offset: Offset(0.2, 0.15),
                      blurRadius: 1.65,
                    ),
                    BoxShadow(
                      color: Palette.glazedWhite.o(0.85),
                      blurStyle: BlurStyle.inner,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.info_outline,
                    color: Palette.glazedWhite,
                    size: 22,
                    shadows: [Shadow(color: Palette.glazedWhite)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Palette.primalBlack.o(0.95),
      body: Column(
        children: [
          // Messages area
          Expanded(
            child: StreamBuilder<List<PublicGroupMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Palette.forgedGold,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Palette.alarmRed, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'error loading messages',
                          style: TextStyle(
                            color: Palette.glazedWhite,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                            color: Palette.glazedWhite.o(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Palette.glazedWhite.o(0.3),
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'no messages yet',
                          style: TextStyle(
                            color: Palette.glazedWhite.o(0.7),
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'start the conversation!',
                          style: TextStyle(
                            color: Palette.glazedWhite.o(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final isOwnMessage = message.senderId == _currentUser.id;

                    // Check if we should show sender info (for non-own messages)
                    bool showSenderInfo = false;
                    if (!isOwnMessage) {
                      // Always show sender info for the first message (last in reversed list)
                      if (index == messages.length - 1) {
                        showSenderInfo = true;
                      } else {
                        // Check if the next message (in chronological order) has a different sender
                        final nextMessageIndex = messages.length - 2 - index;
                        if (nextMessageIndex >= 0 &&
                            nextMessageIndex < messages.length) {
                          final nextMessage = messages[nextMessageIndex];
                          showSenderInfo =
                              nextMessage.senderId != message.senderId;
                        }
                      }
                    }

                    return _buildMessageBubble(
                      message,
                      isOwnMessage,
                      showSenderInfo,
                    );
                  },
                );
              },
            ),
          ),

          // Message input area
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Palette.glazedWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, -2),
                    blurRadius: 5,
                    color: Palette.primalBlack.o(0.05),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: TextField(
                        showCursor: false,
                        textInputAction: TextInputAction.send,
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'type a message...',
                          hintStyle: TextStyle(color: Palette.primalBlack),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: Palette.forgedGold,
                      size: 28,
                    ),
                    onPressed: () => _sendMessage(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
