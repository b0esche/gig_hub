import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a message in a public group chat
///
/// These messages are unencrypted and visible to all rave attendees
/// who join the public group chat.
class PublicGroupMessage {
  /// Unique identifier for the message
  final String id;

  /// ID of the public group chat this message belongs to
  final String publicGroupChatId;

  /// ID of the user who sent the message
  final String senderId;

  /// Display name of the sender (includes Guest usernames)
  final String senderName;

  /// Type of user who sent the message (Guest, DJ, Booker, Organizer)
  final String senderType;

  /// Whether the sender is marked as FLINTA*
  final bool? isFlinta;

  /// The message content (unencrypted for public chats)
  final String content;

  /// When the message was sent
  final DateTime timestamp;

  /// Whether the message has been edited
  final bool isEdited;

  /// When the message was last edited (if applicable)
  final DateTime? editedAt;

  /// Type of message (text, image, system, etc.)
  final String messageType;

  PublicGroupMessage({
    required this.id,
    required this.publicGroupChatId,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    this.isFlinta,
    required this.content,
    required this.timestamp,
    this.isEdited = false,
    this.editedAt,
    this.messageType = 'text',
  });

  factory PublicGroupMessage.fromJson(String id, Map<String, dynamic> json) {
    return PublicGroupMessage(
      id: id,
      publicGroupChatId: json['publicGroupChatId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderType: json['senderType'] ?? 'Guest',
      isFlinta: json['isFlinta'] as bool?,
      content: json['content'] ?? '',
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      isEdited: json['isEdited'] ?? false,
      editedAt:
          json['editedAt'] != null
              ? (json['editedAt'] as Timestamp).toDate()
              : null,
      messageType: json['messageType'] ?? 'text',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'publicGroupChatId': publicGroupChatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderType': senderType,
      'isFlinta': isFlinta,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isEdited': isEdited,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'messageType': messageType,
    };
  }

  PublicGroupMessage copyWith({
    String? id,
    String? publicGroupChatId,
    String? senderId,
    String? senderName,
    String? senderType,
    bool? isFlinta,
    String? content,
    DateTime? timestamp,
    bool? isEdited,
    DateTime? editedAt,
    String? messageType,
  }) {
    return PublicGroupMessage(
      id: id ?? this.id,
      publicGroupChatId: publicGroupChatId ?? this.publicGroupChatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderType: senderType ?? this.senderType,
      isFlinta: isFlinta ?? this.isFlinta,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      messageType: messageType ?? this.messageType,
    );
  }
}
