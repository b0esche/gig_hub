import 'package:gig_hub/src/Data/app_imports.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user notification preferences
class NotificationPreferencesService {
  static const String _preferencesKey = 'notification_preferences';

  /// Get notification preferences for a user
  static Future<NotificationPreferences> getPreferences(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_preferencesKey}_$userId';

    final preferencesJson = prefs.getString(key);
    if (preferencesJson != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(preferencesJson);
        return NotificationPreferences.fromJson(json);
      } catch (e) {
        // If parsing fails, return default preferences
        return const NotificationPreferences();
      }
    }

    return const NotificationPreferences();
  }

  /// Save notification preferences for a user
  static Future<void> savePreferences(String userId, NotificationPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_preferencesKey}_$userId';

    final preferencesJson = jsonEncode(preferences.toJson());
    await prefs.setString(key, preferencesJson);
  }

  /// Check if a specific notification type should be sent
  static Future<bool> shouldSendNotification(String userId, String notificationType) async {
    final preferences = await getPreferences(userId);

    switch (notificationType) {
      case 'chat':
        return preferences.chatMessages;
      case 'rave_alert':
        return preferences.raveAlerts;
      default:
        return true; // Default to sending if type is unknown
    }
  }
}