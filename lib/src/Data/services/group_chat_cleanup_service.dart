import 'dart:async';
import '../firebase/firestore_repository.dart';

/// Service responsible for automatically cleaning up expired group chats
///
/// Features:
/// - Singleton pattern ensures only one cleanup service runs
/// - Periodic cleanup every hour to remove expired group chats
/// - Removes group chats that have passed their autoDeleteAt timestamp
/// - Prevents database bloat from old group chat data
/// - Configurable cleanup intervals
class GroupChatCleanupService {
  /// How often to check for expired group chats (every hour)
  static const Duration _cleanupInterval = Duration(hours: 1);

  Timer? _cleanupTimer;
  final FirestoreDatabaseRepository _db = FirestoreDatabaseRepository();

  // Singleton implementation
  static final GroupChatCleanupService _instance =
      GroupChatCleanupService._internal();
  factory GroupChatCleanupService() => _instance;
  GroupChatCleanupService._internal();

  /// Starts the automatic cleanup service
  /// Performs an initial cleanup and then schedules periodic cleanups
  void startCleanupService() {
    // Prevent multiple cleanup timers from running
    if (_cleanupTimer?.isActive == true) return;

    // Run initial cleanup immediately
    _performCleanup();

    // Schedule periodic cleanup every hour
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _performCleanup();
    });
  }

  /// Stops the automatic cleanup service
  /// Cancels the periodic timer to prevent further cleanups
  void stopCleanupService() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// Perform the cleanup operation
  Future<void> _performCleanup() async {
    try {
      await _db.deleteExpiredGroupChats();
      await _db.deleteExpiredPublicGroupChats();
    } catch (_) {}
  }

  /// Manually trigger cleanup (useful for testing or immediate cleanup)
  Future<void> triggerCleanup() async {
    await _performCleanup();
  }

  /// Check if cleanup service is running
  bool get isRunning => _cleanupTimer?.isActive == true;
}
