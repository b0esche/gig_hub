import 'package:gig_hub/src/Data/app_imports.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gig_hub/src/Data/services/notification_service.dart';
import 'package:gig_hub/src/Data/services/group_chat_cleanup_service.dart';
import 'package:gig_hub/src/Data/services/background_audio_service.dart';

/// Main entry point for the GigHub application
///
/// Features:
/// - Firebase integration for authentication and Firestore
/// - Push notification setup for both foreground and background
/// - Group chat cleanup service for expired chats
/// - Multi-platform local notifications (Android/iOS)
/// - Global app state management with Provider

// Global instances for dependency injection
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final AuthRepository auth = FirebaseAuthRepository();
final DatabaseRepository db = CachedFirestoreRepository();

// Global navigator key for app-wide navigation
final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

// Notification configuration for different platforms
const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
const InitializationSettings initializationSettings = InitializationSettings(
  android: initializationSettingsAndroid,
  iOS: initializationSettingsDarwin,
);

/// Background message handler for Firebase Cloud Messaging
/// Processes push notifications when the app is terminated or in background
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final notification = message.notification;
  if (notification != null) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'chat_channel',
          'chat messages',
          channelDescription: 'get notified when receiving new messages',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await FlutterLocalization.instance.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseMessaging.instance.requestPermission();
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Initialize background audio service for DJ track playback
  await BackgroundAudioService.initialize();

  GroupChatCleanupService().startCleanupService();

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (context) => auth),
        ChangeNotifierProvider<DatabaseRepository>(create: (_) => db),
      ],
      child: NotificationHandlerApp(auth: auth, db: db),
    ),
  );
}
