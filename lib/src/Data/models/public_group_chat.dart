import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a public group chat for rave attendees
///
/// This is completely separate from the private group chats between
/// DJs, bookers, organizers, and collaborators.
///
/// Features:
/// - Open to all rave attendees (including guests)
/// - Linked to a specific rave via raveId
/// - Auto-deletion after 24 hours of inactivity
/// - Public visibility and participation
class PublicGroupChat {
  /// Unique identifier for the public group chat
  final String id;

  /// ID of the rave this public group chat belongs to
  final String raveId;

  /// Display name of the public group chat (usually rave name + "Public Chat")
  final String name;

  /// List of user IDs who are members of this public group chat
  final List<String> memberIds;

  /// Last message content (unencrypted for public chats)
  final String? lastMessage;

  /// User ID who sent the last message
  final String? lastMessageSenderId;

  /// Timestamp of the last message
  final DateTime? lastMessageTimestamp;

  /// When the public group chat was created
  final DateTime createdAt;

  /// When the public group chat will be automatically deleted (24 hours after last activity)
  final DateTime? autoDeleteAt;

  /// Whether the public group chat is currently active
  final bool isActive;

  /// Number of total members (for display purposes)
  final int memberCount;

  /// URL of the group's image/avatar (optional)
  final String? imageUrl;

  PublicGroupChat({
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
    int? memberCount,
    this.imageUrl,
  }) : memberCount = memberCount ?? memberIds.length;

  factory PublicGroupChat.fromJson(String id, Map<String, dynamic> json) {
    return PublicGroupChat(
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
      memberCount:
          json['memberCount'] ?? (json['memberIds'] as List?)?.length ?? 0,
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
      'memberCount': memberCount,
      'imageUrl': imageUrl,
    };
  }

  PublicGroupChat copyWith({
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
    int? memberCount,
    String? imageUrl,
  }) {
    return PublicGroupChat(
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
      memberCount: memberCount ?? this.memberCount,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
