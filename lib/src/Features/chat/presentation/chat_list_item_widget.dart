import 'package:cached_network_image/cached_network_image.dart';
import 'package:gig_hub/src/Data/app_imports.dart';
import 'package:intl/intl.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class ChatListItemWidget extends StatelessWidget {
  final ChatListItem chatListItem;
  final AppUser currentUser;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ChatListItemWidget({
    super.key,
    required this.chatListItem,
    required this.currentUser,
    this.onTap,
    this.onLongPress,
  });

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat.Hm().format(timestamp);
  }

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
    final avatarUrl = chatListItem.user.avatarUrl;
    final userName = chatListItem.user.displayName;

    final lastMessage = _decryptPreview(chatListItem.recent.message);
    final lastStamp = chatListItem.recent.timestamp;
    final formattedTime = _formatTimestamp(lastStamp);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Palette.glazedWhite.o(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Palette.primalBlack.o(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(
                top: 10,
                left: 12,
                right: 12,
                bottom: 10,
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Palette.primalBlack.o(0.35),
                        width: 1.4,
                      ),
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        progressIndicatorBuilder:
                            (context, url, progress) =>
                                CircularProgressIndicator(
                                  color: Palette.forgedGold,
                                  strokeWidth: 1.65,
                                ),
                        imageUrl: avatarUrl,
                        fadeInDuration: Duration(milliseconds: 150),
                        fadeInCurve: Curves.easeIn,
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 12,
                              color: Palette.primalBlack.o(0.6),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sometypeMono(
                                  textStyle: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Palette.primalBlack,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sometypeMono(
                            textStyle: TextStyle(
                              fontSize: 14,
                              color: Palette.primalBlack.o(0.85),
                              wordSpacing: -3,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            (!chatListItem.recent.read &&
                    chatListItem.recent.senderId != currentUser.id)
                ? Positioned(
                  bottom: 8,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.forgedGold,
                      border: Border.all(
                        color: Palette.primalBlack.o(0.6),
                        width: 1.4,
                      ),
                    ),
                    height: 22,
                    width: 22,
                    child: Icon(
                      Icons.notification_important,
                      color: Palette.glazedWhite,
                      size: 16,
                    ),
                  ),
                )
                : SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
