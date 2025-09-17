import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

/// Service responsible for managing cleanup of expired raves and related content
///
/// Features:
/// - Manual cleanup triggering via Cloud Functions
/// - Automatic cleanup scheduling (handled by Firebase Cloud Functions)
/// - Client-side cleanup monitoring and logging
/// - Cleanup status tracking and reporting
class RaveCleanupService {
  static final RaveCleanupService _instance = RaveCleanupService._internal();
  factory RaveCleanupService() => _instance;
  RaveCleanupService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Manually trigger cleanup of expired raves and group chats
  ///
  /// This calls the Firebase Cloud Function to immediately remove:
  /// - Raves that ended more than 24 hours ago
  /// - Associated group chats for deleted raves
  /// - Expired group chats based on autoDeleteAt timestamp
  ///
  /// Returns a map with cleanup results including counts of deleted items
  Future<Map<String, dynamic>?> triggerManualCleanup() async {
    try {
      final callable = _functions.httpsCallable('triggerCleanup');
      final result = await callable.call();

      final data = result.data as Map<String, dynamic>?;

      return data;
    } catch (e) {
      rethrow;
    }
  }

  /// Check if a rave should be cleaned up based on its end date
  ///
  /// Returns true if the rave ended more than 24 hours ago
  static bool shouldCleanupRave(DateTime startDate, DateTime? endDate) {
    final now = DateTime.now();
    final raveEndTime = endDate ?? startDate;
    final twentyFourHoursAfterEnd = raveEndTime.add(const Duration(hours: 24));

    return now.isAfter(twentyFourHoursAfterEnd);
  }

  /// Get the estimated cleanup time for a rave
  ///
  /// Returns when the rave will be eligible for cleanup (24 hours after end)
  static DateTime getCleanupTime(DateTime startDate, DateTime? endDate) {
    final raveEndTime = endDate ?? startDate;
    return raveEndTime.add(const Duration(hours: 24));
  }

  /// Format cleanup time for display
  ///
  /// Returns a human-readable string indicating when cleanup will occur
  static String formatCleanupTime(DateTime startDate, DateTime? endDate) {
    final cleanupTime = getCleanupTime(startDate, endDate);
    final now = DateTime.now();

    if (now.isAfter(cleanupTime)) {
      return 'Eligible for cleanup';
    }

    final duration = cleanupTime.difference(now);

    if (duration.inDays > 0) {
      return 'Cleanup in ${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return 'Cleanup in ${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else {
      return 'Cleanup in ${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    }
  }

  /// Check cleanup service status
  ///
  /// Note: The actual scheduled cleanup runs automatically via Firebase Cloud Functions
  /// This method provides information about the cleanup schedule
  Map<String, dynamic> getCleanupStatus() {
    return {
      'scheduledCleanup': 'Daily at 2:00 AM UTC',
      'manualCleanupAvailable': true,
      'cleanupCriteria': 'Raves ended more than 24 hours ago',
      'affectedContent': [
        'Expired rave events',
        'Associated group chats',
        'Group chat messages',
      ],
    };
  }
}
