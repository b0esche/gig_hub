import '../../../Data/app_imports.dart';
import '../../auth/presentation/guest_username_dialog.dart';
import 'package:gig_hub/src/Common/widgets/safe_pinch_zoom.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:gig_hub/src/Data/services/image_compression_service.dart';

class GroupChatScreen extends StatefulWidget {
  final GroupChat groupChat;
  final String currentUserId;

  const GroupChatScreen({
    super.key,
    required this.groupChat,
    required this.currentUserId,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirestoreDatabaseRepository _db = FirestoreDatabaseRepository();
  AppUser? _currentUser;
  String? _currentGroupImageUrl; // Track current group image URL

  // Encryption variables
  late encrypt.Encrypter _encrypter;
  late encrypt.Key _aesKey;
  bool _encryptionReady = false;

  @override
  void initState() {
    super.initState();
    _currentGroupImageUrl =
        widget.groupChat.imageUrl; // Initialize with current image
    _loadCurrentUser();
    _initEncryption();
  }

  Future<void> _initEncryption() async {
    final keyString = dotenv.env['ENCRYPTION_KEY'];
    if (keyString == null || keyString.length != 32) {
      return;
    }

    _aesKey = encrypt.Key.fromUtf8(keyString);
    _encrypter = encrypt.Encrypter(encrypt.AES(_aesKey));

    setState(() {
      _encryptionReady = true;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _db.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (_) {}
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
                currentUser: _currentUser!,
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
  }

  String _decryptMessage(String text) {
    if (!_encryptionReady) return '[loading key...]';

    if (text.startsWith('enc::')) {
      try {
        final encryptedPart = text.substring(5);

        final parts = encryptedPart.split(':');
        if (parts.length != 2) return '[invalid format]';

        final iv = encrypt.IV.fromBase64(parts[0]);
        final encryptedData = parts[1];

        return _encrypter.decrypt64(encryptedData, iv: iv);
      } catch (e) {
        return '[decoding error]';
      }
    }

    return text;
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
                  backgroundColor:
                      _currentGroupImageUrl != null
                          ? Colors.transparent
                          : Palette.forgedGold,
                  radius: 42,
                  backgroundImage:
                      _currentGroupImageUrl != null
                          ? NetworkImage(_currentGroupImageUrl!)
                          : null,
                  child:
                      _currentGroupImageUrl == null
                          ? Icon(
                            Icons.group,
                            color: Palette.primalBlack,
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
                    widget.groupChat.name,
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
                    '${widget.groupChat.memberIds.length} members',
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
          Expanded(
            child: StreamBuilder<List<GroupMessage>>(
              stream: _db.getGroupMessagesStream(widget.groupChat.id),
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
                    child: Text(
                      'Error loading messages',
                      style: TextStyle(color: Palette.glazedWhite),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(
                        color: Palette.glazedWhite.o(0.6),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                // Group messages by date like in regular chat
                final List<dynamic> messageItems = [];
                DateTime? lastDate;

                final sortedMessages = [...messages]
                  ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

                for (final msg in sortedMessages) {
                  final msgDate = DateTime(
                    msg.timestamp.year,
                    msg.timestamp.month,
                    msg.timestamp.day,
                  );

                  if (lastDate == null || msgDate.isAfter(lastDate)) {
                    messageItems.add(msgDate);
                    lastDate = msgDate;
                  }

                  messageItems.add(msg);
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.minScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messageItems.length,
                  itemBuilder: (context, index) {
                    final item = messageItems[messageItems.length - 1 - index];

                    if (item is DateTime) {
                      final isToday =
                          DateTime.now().difference(item).inDays == 0;
                      final dateText =
                          isToday
                              ? 'Today'
                              : '${item.day.toString().padLeft(2, '0')}.${item.month.toString().padLeft(2, '0')}.${item.year}';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            dateText,
                            style: TextStyle(
                              color: Palette.glazedWhite.o(0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }

                    final GroupMessage message = item;
                    final isOwnMessage =
                        message.senderId == widget.currentUserId;

                    // Check if we should show sender info (for non-own messages)
                    // Show sender info if this is the last message OR if the next message has a different sender
                    bool showSenderInfo = false;
                    if (!isOwnMessage) {
                      // Always show sender info for the first message (last in reversed list)
                      if (index == messageItems.length - 1) {
                        showSenderInfo = true;
                      } else {
                        // Check if the next message (in chronological order) has a different sender
                        // Since list is reversed, "next" message is at index + 1 in the builder
                        // which corresponds to messageItems.length - 1 - (index + 1) in messageItems
                        final nextMessageIndex =
                            messageItems.length - 2 - index;
                        if (nextMessageIndex >= 0 &&
                            nextMessageIndex < messageItems.length) {
                          final nextItem = messageItems[nextMessageIndex];
                          if (nextItem is GroupMessage) {
                            showSenderInfo =
                                nextItem.senderId != message.senderId;
                          } else {
                            // If next item is not a message (e.g., date separator), show sender info
                            showSenderInfo = true;
                          }
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
          _buildMessageInput(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    GroupMessage message,
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
            CircleAvatar(
              radius: 18,
              backgroundColor: Palette.forgedGold,
              backgroundImage:
                  message.senderAvatarUrl != null
                      ? NetworkImage(message.senderAvatarUrl!)
                      : null,
              child:
                  message.senderAvatarUrl == null
                      ? Icon(Icons.person, color: Palette.primalBlack, size: 18)
                      : null,
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
                                SizedBox(width: 8),
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
                            _decryptMessage(message.message),
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

  Widget _buildMessageInput() {
    return Padding(
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
    );
  }

  Future<void> _sendMessage() async {
    if (!_encryptionReady) return;
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    try {
      String senderName = 'Unknown';
      String? senderAvatarUrl;

      if (_currentUser is DJ) {
        final dj = _currentUser as DJ;
        senderName = dj.name;
        senderAvatarUrl = dj.avatarImageUrl;
      } else if (_currentUser is Booker) {
        final booker = _currentUser as Booker;
        senderName = booker.name;
        senderAvatarUrl = booker.avatarImageUrl;
      } else if (_currentUser is Guest) {
        final guest = _currentUser as Guest;
        senderName = guest.name.isNotEmpty ? guest.name : 'Guest';
        senderAvatarUrl = guest.avatarImageUrl;
      }

      // Encrypt the message
      final iv = encrypt.IV.fromLength(16);
      final encrypted = _encrypter.encrypt(text, iv: iv);
      final encryptedText = 'enc::${iv.base64}:${encrypted.base64}';

      final message = GroupMessage(
        id: '', // Will be set by Firestore
        groupChatId: widget.groupChat.id,
        senderId: widget.currentUserId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        message: encryptedText,
        timestamp: DateTime.now(),
        readBy: {widget.currentUserId: true}, // Mark as read by sender
      );

      await _db.sendGroupMessage(message);
      _messageController.clear();

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    }
  }

  void _showGroupInfo() async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Palette.glazedWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Palette.forgedGold, width: 2),
            ),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Palette.forgedGold),
                const SizedBox(width: 16),
                Text(
                  'Loading members...',
                  style: TextStyle(color: Palette.primalBlack),
                ),
              ],
            ),
          ),
    );

    try {
      // Fetch member user data
      final memberUsers = <AppUser>[];
      for (final memberId in widget.groupChat.memberIds) {
        try {
          final user = await context.read<DatabaseRepository>().getUserById(
            memberId,
          );
          memberUsers.add(user);
        } catch (_) {
          // Continue with other members
        }
      }

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show info dialog with member names
      if (mounted) {
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
                  'group info',
                  style: TextStyle(
                    color: Palette.primalBlack,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group Image Section
                    Center(
                      child: Stack(
                        children: [
                          SafePinchZoom(
                            maxScale: 3.0,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor:
                                  _currentGroupImageUrl != null
                                      ? Colors.transparent
                                      : Palette.forgedGold.o(0.2),
                              backgroundImage:
                                  _currentGroupImageUrl != null
                                      ? NetworkImage(_currentGroupImageUrl!)
                                      : null,
                              child:
                                  _currentGroupImageUrl == null
                                      ? Icon(
                                        Icons.group,
                                        color: Palette.forgedGold,
                                        size: 40,
                                      )
                                      : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _uploadGroupImage(),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Palette.forgedGold,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Palette.glazedWhite,
                                    width: 2,
                                  ),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Palette.primalBlack,
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
                      'members (${widget.groupChat.memberIds.length}):',
                      style: TextStyle(
                        color: Palette.primalBlack,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...memberUsers.map(
                      (user) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                // Only allow navigation for DJs and Bookers
                                if (user is DJ || user is Booker) {
                                  Navigator.of(
                                    context,
                                  ).pop(); // Close the dialog first
                                  _navigateToProfile(user);
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      (user is DJ || user is Booker)
                                          ? Border.all(
                                            color: Palette.forgedGold.o(0.6),
                                            width: 2,
                                          )
                                          : null,
                                ),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundImage:
                                      user.avatarUrl.isNotEmpty
                                          ? NetworkImage(user.avatarUrl)
                                          : null,
                                  backgroundColor: Palette.forgedGold.o(0.2),
                                  child:
                                      user.avatarUrl.isEmpty
                                          ? Text(
                                            user.displayName
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Palette.forgedGold,
                                              fontSize: 12,
                                            ),
                                          )
                                          : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                user.displayName,
                                style: TextStyle(
                                  color: Palette.primalBlack,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.groupChat.autoDeleteAt != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'auto-delete: ${widget.groupChat.autoDeleteAt!.day.toString().padLeft(2, '0')}.${widget.groupChat.autoDeleteAt!.month.toString().padLeft(2, '0')}.${widget.groupChat.autoDeleteAt!.year}',
                        style: TextStyle(
                          color: Palette.primalBlack.o(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  // Show username change option for Guest users
                  if (_currentUser is Guest) ...[
                    TextButton(
                      onPressed: () => _showGuestUsernameDialog(),
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
                  ],
                  TextButton(
                    onPressed: () => _showLeaveGroupDialog(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.exit_to_app,
                          color: Palette.alarmRed,
                          size: 16,
                        ),
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
                      style: TextStyle(color: Palette.forgedGold),
                    ),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error loading members: $e'),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    }
  }

  Future<void> _uploadGroupImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                backgroundColor: Palette.glazedWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Palette.forgedGold, width: 2),
                ),
                content: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Palette.forgedGold),
                    const SizedBox(width: 16),
                    Text(
                      'uploading image...',
                      style: TextStyle(color: Palette.primalBlack),
                    ),
                  ],
                ),
              ),
        );

        // Compress the image
        final originalFile = File(pickedFile.path);
        final compressedFile = await ImageCompressionService.compressImage(
          originalFile,
        );

        // Upload to Firebase Storage
        final storageRef = FirebaseStorage.instance.ref().child(
          'group_images/${widget.groupChat.id}.jpg',
        );

        await storageRef.putFile(
          compressedFile,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'groupId': widget.groupChat.id},
          ),
        );

        final downloadUrl = await storageRef.getDownloadURL();

        // Update group chat in Firestore
        await _db.updateGroupChatImage(widget.groupChat.id, downloadUrl);

        // Update local state
        setState(() {
          _currentGroupImageUrl = downloadUrl;
        });

        // Close loading dialog
        if (mounted) Navigator.of(context).pop();

        // Refresh the group info dialog
        if (mounted) {
          Navigator.of(context).pop(); // Close current dialog
          _showGroupInfo(); // Reopen with updated image
        }
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (mounted) Navigator.of(context).pop();

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('failed to upload image: $e'),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    }
  }

  /// Shows username dialog for Guest users
  Future<void> _showGuestUsernameDialog() async {
    if (_currentUser is! Guest) return;

    Navigator.of(context).pop(); // Close group info dialog first

    final updatedGuest = await showDialog<Guest>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => GuestUsernameDialog(guestUser: _currentUser as Guest),
    );

    if (updatedGuest != null) {
      setState(() {
        _currentUser = updatedGuest;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Palette.okGreen,
          content: Text(
            'Username updated!',
            style: TextStyle(color: Palette.primalBlack),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Shows confirmation dialog for leaving the group chat
  Future<void> _showLeaveGroupDialog() async {
    Navigator.of(context).pop(); // Close group info dialog first

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Palette.primalBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Palette.alarmRed, width: 2),
            ),
            title: Text(
              'Leave Group Chat?',
              style: TextStyle(
                color: Palette.glazedWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to leave "${widget.groupChat.name}"?',
                  style: TextStyle(
                    color: Palette.glazedWhite.o(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Palette.alarmRed.o(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Palette.alarmRed.o(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_outlined,
                        color: Palette.alarmRed,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can rejoin by attending the rave again.',
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
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Palette.glazedWhite.o(0.7)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.alarmRed,
                  foregroundColor: Palette.glazedWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Leave Chat',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _leaveGroupChat();
    }
  }

  /// Removes the current user from the group chat
  Future<void> _leaveGroupChat() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              backgroundColor: Palette.primalBlack,
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Palette.forgedGold),
                  const SizedBox(width: 16),
                  Text(
                    'Leaving chat...',
                    style: TextStyle(color: Palette.glazedWhite),
                  ),
                ],
              ),
            ),
      );

      // Remove user from group chat members
      final updatedMemberIds = List<String>.from(widget.groupChat.memberIds)
        ..remove(widget.currentUserId);

      final updatedChat = widget.groupChat.copyWith(
        memberIds: updatedMemberIds,
      );

      final db = context.read<DatabaseRepository>();
      await db.updateGroupChat(updatedChat);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Go back to chat list
      if (mounted) {
        Navigator.of(context).pop(); // Exit group chat screen

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Palette.okGreen,
            content: Text(
              'Left group chat successfully',
              style: TextStyle(color: Palette.primalBlack),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Palette.alarmRed,
            content: Text(
              'Failed to leave chat. Please try again.',
              style: TextStyle(color: Palette.glazedWhite),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
