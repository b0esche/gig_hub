import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a group chat associated with a rave event
///
/// Features:
/// - Linked to a specific rave via raveId
/// - Supports multiple members via memberIds list
/// - Tracks last message for preview display
/// - Auto-deletion after rave ends (48 hours)
/// - Optional group image for customization
/// - Active/inactive state management
class GroupChat {
  /// Unique identifier for the group chat
  final String id;

  /// ID of the rave this group chat belongs to
  final String raveId;

  /// Display name of the group chat
  final String name;

  /// List of user IDs who are members of this group chat
  final List<String> memberIds;

  /// Last message content (may be encrypted)
  final String? lastMessage;

  /// User ID who sent the last message
  final String? lastMessageSenderId;

  /// Timestamp of the last message
  final DateTime? lastMessageTimestamp;

  /// When the group chat was created
  final DateTime createdAt;

  /// When the group chat will be automatically deleted (48 hours after rave end)
  final DateTime? autoDeleteAt;

  /// Whether the group chat is currently active
  final bool isActive;

  /// Optional custom image URL for the group chat
  final String? imageUrl;

  GroupChat({
    required this.id,
    required this.raveId,
    required this.name,
    required this.memberIds,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageTimestamp,
    required this.createdAt,
    this.autoDeleteAt,
    this.isActive = true,
    this.imageUrl,
  });

  factory GroupChat.fromJson(String id, Map<String, dynamic> json) {
    return GroupChat(
      id: id,
      raveId: json['raveId'] ?? '',
      name: json['name'] ?? '',
      memberIds: List<String>.from(json['memberIds'] ?? []),
      lastMessage: json['lastMessage'],
      lastMessageSenderId: json['lastMessageSenderId'],
      lastMessageTimestamp:
          json['lastMessageTimestamp'] != null
              ? (json['lastMessageTimestamp'] as Timestamp).toDate()
              : null,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      autoDeleteAt:
          json['autoDeleteAt'] != null
              ? (json['autoDeleteAt'] as Timestamp).toDate()
              : null,
      isActive: json['isActive'] ?? true,
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'raveId': raveId,
      'name': name,
      'memberIds': memberIds,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTimestamp':
          lastMessageTimestamp != null
              ? Timestamp.fromDate(lastMessageTimestamp!)
              : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'autoDeleteAt':
          autoDeleteAt != null ? Timestamp.fromDate(autoDeleteAt!) : null,
      'isActive': isActive,
      'imageUrl': imageUrl,
    };
  }

  GroupChat copyWith({
    String? id,
    String? raveId,
    String? name,
    List<String>? memberIds,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageTimestamp,
    DateTime? createdAt,
    DateTime? autoDeleteAt,
    bool? isActive,
    String? imageUrl,
  }) {
    return GroupChat(
      id: id ?? this.id,
      raveId: raveId ?? this.raveId,
      name: name ?? this.name,
      memberIds: memberIds ?? this.memberIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      createdAt: createdAt ?? this.createdAt,
      autoDeleteAt: autoDeleteAt ?? this.autoDeleteAt,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
