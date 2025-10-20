import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

/// Service to handle App Tracking Transparency compliance
///
/// Apple requires apps to request user permission before accessing
/// web content that may use cookies for tracking purposes.
class AppTrackingService {
  static bool _hasRequestedPermission = false;

  /// Request tracking permission before opening web content
  /// This is required by Apple's App Tracking Transparency guidelines
  static Future<bool> requestTrackingPermission() async {
    // Only request once per app session
    if (_hasRequestedPermission) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      return status == TrackingStatus.authorized;
    }

    try {
      // Wait a moment for the app to be fully loaded
      await Future.delayed(Duration(milliseconds: 500));

      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();
      _hasRequestedPermission = true;

      return status == TrackingStatus.authorized;
    } catch (e) {
      // If tracking transparency fails, allow web content access
      // but don't use any tracking features
      return false;
    }
  }

  /// Check current tracking authorization status
  static Future<TrackingStatus> getTrackingStatus() async {
    try {
      return await AppTrackingTransparency.trackingAuthorizationStatus;
    } catch (e) {
      return TrackingStatus.notDetermined;
    }
  }

  /// Get the identifier for advertisers (IDFA)
  /// Only available if user has granted tracking permission
  static Future<String?> getAdvertisingIdentifier() async {
    try {
      final status = await getTrackingStatus();
      if (status == TrackingStatus.authorized) {
        return await AppTrackingTransparency.getAdvertisingIdentifier();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
