import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

/// Model representing a user's rave alert preferences
///
/// Features:
/// - Geographic location monitoring with customizable radius
/// - Push notification integration for new raves in area
/// - User-specific alert preferences and status tracking
/// - Location name display for user reference
class RaveAlert {
  /// Unique identifier for the alert
  final String id;

  /// User ID who owns this alert
  final String userId;

  /// Geographic center point for the alert area
  final GeoPoint centerPoint;

  /// Alert radius in kilometers (10-200km range)
  final double radiusKm;

  /// Human-readable location name for display
  final String locationName;

  /// Whether this alert is currently active
  final bool isActive;

  /// When this alert was created
  final DateTime createdAt;

  /// When this alert was last updated
  final DateTime updatedAt;

  const RaveAlert({
    required this.id,
    required this.userId,
    required this.centerPoint,
    required this.radiusKm,
    required this.locationName,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Converts the rave alert to a JSON map for Firestore storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'centerPoint': centerPoint,
    'radiusKm': radiusKm,
    'locationName': locationName,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Creates a RaveAlert instance from Firestore JSON data
  factory RaveAlert.fromJson(Map<String, dynamic> json) => RaveAlert(
    id: json['id'] as String,
    userId: json['userId'] as String,
    centerPoint: json['centerPoint'] as GeoPoint,
    radiusKm: (json['radiusKm'] as num).toDouble(),
    locationName: json['locationName'] as String,
    isActive: json['isActive'] as bool? ?? true,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  /// Creates a copy of this alert with updated values
  RaveAlert copyWith({
    String? id,
    String? userId,
    GeoPoint? centerPoint,
    double? radiusKm,
    String? locationName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RaveAlert(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    centerPoint: centerPoint ?? this.centerPoint,
    radiusKm: radiusKm ?? this.radiusKm,
    locationName: locationName ?? this.locationName,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Calculates distance between this alert's center and a given point
  /// Returns distance in kilometers
  double distanceToPoint(GeoPoint point) {
    return _calculateDistance(
      centerPoint.latitude,
      centerPoint.longitude,
      point.latitude,
      point.longitude,
    );
  }

  /// Checks if a given location falls within this alert's radius
  bool isLocationInRadius(GeoPoint location) {
    return distanceToPoint(location) <= radiusKm;
  }

  /// Calculates the distance between two geographic points using Haversine formula
  /// Returns distance in kilometers
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.asin(math.sqrt(a));

    return earthRadiusKm * c;
  }

  /// Converts degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  @override
  String toString() {
    return 'RaveAlert(id: $id, location: $locationName, radius: ${radiusKm}km, active: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RaveAlert &&
        other.id == id &&
        other.userId == userId &&
        other.centerPoint == centerPoint &&
        other.radiusKm == radiusKm &&
        other.locationName == locationName &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      centerPoint,
      radiusKm,
      locationName,
      isActive,
    );
  }
}
