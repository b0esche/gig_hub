/// Model representing user notification preferences
class NotificationPreferences {
  final bool chatMessages;
  final bool raveAlerts;

  const NotificationPreferences({
    this.chatMessages = true,
    this.raveAlerts = true,
  });

  /// Create from JSON (for storing in user document or shared preferences)
  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      chatMessages: json['chatMessages'] ?? true,
      raveAlerts: json['raveAlerts'] ?? true,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'chatMessages': chatMessages,
      'raveAlerts': raveAlerts,
    };
  }

  /// Copy with new values
  NotificationPreferences copyWith({
    bool? chatMessages,
    bool? raveAlerts,
  }) {
    return NotificationPreferences(
      chatMessages: chatMessages ?? this.chatMessages,
      raveAlerts: raveAlerts ?? this.raveAlerts,
    );
  }
}