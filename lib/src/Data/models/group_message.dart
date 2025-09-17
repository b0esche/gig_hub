import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a message within a group chat
///
/// Features:
/// - Links to parent group chat via groupChatId
/// - Includes sender information (ID, name, avatar)
/// - Supports encrypted message content
/// - Tracks read status per user via readBy map
/// - Firestore timestamp handling for cross-platform compatibility
class GroupMessage {
  /// Unique identifier for this message
  final String id;

  /// ID of the group chat this message belongs to
  final String groupChatId;

  /// User ID of the message sender
  final String senderId;

  /// Display name of the message sender
  final String senderName;

  /// Optional avatar URL of the message sender
  final String? senderAvatarUrl;

  /// Message content (may be AES-256 encrypted with 'enc::' prefix)
  final String message;

  /// When the message was sent
  final DateTime timestamp;

  /// Map tracking which users have read this message (userId -> isRead)
  final Map<String, bool> readBy;

  GroupMessage({
    required this.id,
    required this.groupChatId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.message,
    required this.timestamp,
    this.readBy = const {},
  });

  factory GroupMessage.fromJson(String id, Map<String, dynamic> json) {
    final Timestamp? ts =
        json['timestamp'] is Timestamp ? json['timestamp'] : null;

    return GroupMessage(
      id: id,
      groupChatId: json['groupChatId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Unknown',
      senderAvatarUrl: json['senderAvatarUrl'],
      message: json['message'] ?? '',
      timestamp: ts?.toDate() ?? DateTime.now(),
      readBy: Map<String, bool>.from(json['readBy'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupChatId': groupChatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'readBy': readBy,
    };
  }

  bool isReadBy(String userId) {
    return readBy[userId] ?? false;
  }

  GroupMessage markAsReadBy(String userId) {
    final newReadBy = Map<String, bool>.from(readBy);
    newReadBy[userId] = true;

    return GroupMessage(
      id: id,
      groupChatId: groupChatId,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      message: message,
      timestamp: timestamp,
      readBy: newReadBy,
    );
  }

  int get unreadCount {
    return readBy.values.where((isRead) => !isRead).length;
  }
}
