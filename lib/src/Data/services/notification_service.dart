import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:gig_hub/src/Data/app_imports.dart';
import 'package:gig_hub/src/Features/profile/booker/presentation/booker_profile_loader_screen.dart';
import '../../../main.dart' show globalNavigatorKey;

/// Notification handler service that manages push notification interactions
///
/// Features:
/// - Handles notification taps when app is running or terminated
/// - Deep linking to specific chat screens based on notification data
/// - Integration with Firebase Cloud Messaging
/// - Navigation management for notification-triggered actions
class NotificationHandlerApp extends StatefulWidget {
  final AuthRepository auth;
  final DatabaseRepository db;

  const NotificationHandlerApp({
    super.key,
    required this.auth,
    required this.db,
  });

  @override
  State<NotificationHandlerApp> createState() => _NotificationHandlerAppState();
}

class _NotificationHandlerAppState extends State<NotificationHandlerApp> {
  @override
  void initState() {
    super.initState();
    // Listen for notification taps when app is running
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNav);
    // Check if app was opened via notification when terminated
    _checkInitialMessage();
  }

  /// Checks if the app was opened via a notification when it was terminated
  /// Handles the initial navigation if a notification was the trigger
  Future<void> _checkInitialMessage() async {
    final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMsg != null) {
      _handleNotificationNav(initialMsg);
    }
  }

  void _handleNotificationNav(RemoteMessage message) async {
    final screen = message.data['screen'];
    final notificationType = message.data['type'];

    // Handle different notification types
    switch (notificationType) {
      case 'rave_alert':
        _handleRaveAlertNavigation(message);
        break;
      case 'rave_collaboration':
        _handleRaveCollaborationNavigation(message);
        break;
      default:
        // Handle existing chat notifications
        if (screen == 'chat_list_screen') {
          final user = await widget.db.getCurrentUser();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            globalNavigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => ChatListScreen(currentUser: user),
              ),
            );
          });
        }
        break;
    }
  }

  /// Handle rave alert notification navigation
  void _handleRaveAlertNavigation(RemoteMessage message) {
    final organizerId = message.data['organizerId'];
    final raveId = message.data['raveId'];

    if (organizerId == null) {
      return;
    }

    // Navigate directly to the booker's profile screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      globalNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder:
              (_) => BookerProfileLoaderScreen(
                bookerId: organizerId,
                highlightedRaveId: raveId,
              ),
        ),
      );
    });
  }

  /// Handle rave collaboration notification navigation
  void _handleRaveCollaborationNavigation(RemoteMessage message) {
    final organizerId = message.data['organizerId'];
    final raveId = message.data['raveId'];

    if (organizerId == null) {
      return;
    }

    // Navigate directly to the booker's profile screen with the specific rave highlighted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      globalNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder:
              (_) => BookerProfileLoaderScreen(
                bookerId: organizerId,
                highlightedRaveId: raveId,
              ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return App(navigatorKey: globalNavigatorKey);
  }
}
