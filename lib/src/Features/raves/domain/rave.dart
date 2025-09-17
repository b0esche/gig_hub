import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a rave event with all its details and metadata
///
/// Features:
/// - Event scheduling with multi-day support
/// - User role management (organizer, DJs, collaborators, attendees)
/// - Group chat integration for event communication
/// - Geographic location data for mapping and discovery
/// - Comprehensive metadata for event management
class Rave {
  /// Unique identifier for the rave
  final String id;

  /// Display name of the rave event
  final String name;

  /// User ID of the booker who created this rave
  final String organizerId;

  /// When the rave starts
  final DateTime startDate;

  /// Optional end date for multi-day festivals
  final DateTime? endDate;

  /// Start time display (e.g., "doors open" time)
  final String startTime;

  /// Text location description (validated city name)
  final String location;

  /// Geographic coordinates for mapping and radar features
  final GeoPoint? geoPoint;

  /// Event description and details
  final String description;

  /// Optional link to ticket purchasing
  final String? ticketShopLink;

  /// Optional additional link (social media, etc.)
  final String? additionalLink;

  /// List of DJ user IDs performing at this rave
  final List<String> djIds;

  /// List of collaborator booker user IDs
  final List<String> collaboratorIds;

  /// List of user IDs who marked as attending
  final List<String> attendingUserIds;

  /// Whether this rave has an associated group chat
  final bool hasGroupChat;

  /// ID of the associated group chat (if any)
  final String? groupChatId;

  /// When this rave was created
  final DateTime createdAt;

  /// When this rave was last updated
  final DateTime updatedAt;

  Rave({
    required this.id,
    required this.name,
    required this.organizerId,
    required this.startDate,
    this.endDate,
    required this.startTime,
    required this.location,
    this.geoPoint,
    required this.description,
    this.ticketShopLink,
    this.additionalLink,
    required this.djIds,
    required this.collaboratorIds,
    required this.attendingUserIds,
    required this.hasGroupChat,
    this.groupChatId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isMultiDay => endDate != null;

  bool get isUpcoming => startDate.isAfter(DateTime.now());

  bool get isFinished {
    final endDateTime = endDate ?? startDate;
    return endDateTime.add(Duration(days: 1)).isBefore(DateTime.now());
  }

  int get attendingCount => attendingUserIds.length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'organizerId': organizerId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'startTime': startTime,
      'location': location,
      'geoPoint': geoPoint,
      'description': description,
      'ticketShopLink': ticketShopLink,
      'additionalLink': additionalLink,
      'djIds': djIds,
      'collaboratorIds': collaboratorIds,
      'attendingUserIds': attendingUserIds,
      'hasGroupChat': hasGroupChat,
      'groupChatId': groupChatId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Rave.fromJson(Map<String, dynamic> json) {
    return Rave(
      id: json['id'],
      name: json['name'],
      organizerId: json['organizerId'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      startTime: json['startTime'],
      location: json['location'],
      geoPoint: json['geoPoint'] as GeoPoint?,
      description: json['description'],
      ticketShopLink: json['ticketShopLink'],
      additionalLink: json['additionalLink'],
      djIds: List<String>.from(json['djIds'] ?? []),
      collaboratorIds: List<String>.from(json['collaboratorIds'] ?? []),
      attendingUserIds: List<String>.from(json['attendingUserIds'] ?? []),
      hasGroupChat: json['hasGroupChat'] ?? false,
      groupChatId: json['groupChatId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Rave copyWith({
    String? id,
    String? name,
    String? organizerId,
    DateTime? startDate,
    DateTime? endDate,
    String? startTime,
    String? location,
    GeoPoint? geoPoint,
    String? description,
    String? ticketShopLink,
    String? additionalLink,
    List<String>? djIds,
    List<String>? collaboratorIds,
    List<String>? attendingUserIds,
    bool? hasGroupChat,
    String? groupChatId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Rave(
      id: id ?? this.id,
      name: name ?? this.name,
      organizerId: organizerId ?? this.organizerId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      location: location ?? this.location,
      geoPoint: geoPoint ?? this.geoPoint,
      description: description ?? this.description,
      ticketShopLink: ticketShopLink ?? this.ticketShopLink,
      additionalLink: additionalLink ?? this.additionalLink,
      djIds: djIds ?? this.djIds,
      collaboratorIds: collaboratorIds ?? this.collaboratorIds,
      attendingUserIds: attendingUserIds ?? this.attendingUserIds,
      hasGroupChat: hasGroupChat ?? this.hasGroupChat,
      groupChatId: groupChatId ?? this.groupChatId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
