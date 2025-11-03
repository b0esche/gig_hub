import 'package:gig_hub/src/Data/app_imports.dart';

class NotificationSettingsDialog extends StatefulWidget {
  final NotificationPreferences initialPreferences;
  final Function(NotificationPreferences) onPreferencesChanged;

  const NotificationSettingsDialog({
    super.key,
    required this.initialPreferences,
    required this.onPreferencesChanged,
  });

  @override
  State<NotificationSettingsDialog> createState() => _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState extends State<NotificationSettingsDialog> {
  late NotificationPreferences _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
  }

  void _updatePreference(bool? value, String preferenceType) {
    if (value == null) return;

    setState(() {
      switch (preferenceType) {
        case 'chatMessages':
          _preferences = _preferences.copyWith(chatMessages: value);
          break;
        case 'raveAlerts':
          _preferences = _preferences.copyWith(raveAlerts: value);
          break;
      }
    });

    widget.onPreferencesChanged(_preferences);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.primalBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Palette.forgedGold, width: 2),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'notification settings',
              style: TextStyle(
                color: Palette.forgedGold,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: Palette.glazedWhite.o(0.7)),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNotificationToggle(
                title: 'chat messages',
                subtitle: 'get notified when you receive new messages',
                value: _preferences.chatMessages,
                onChanged: (value) => _updatePreference(value, 'chatMessages'),
              ),
              const SizedBox(height: 16),
              _buildNotificationToggle(
                title: 'rave alerts',
                subtitle: 'get notified about new raves in your area',
                value: _preferences.raveAlerts,
                onChanged: (value) => _updatePreference(value, 'raveAlerts'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.forgedGold,
              foregroundColor: Palette.primalBlack,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              'done',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationToggle({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool?) onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Palette.glazedWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Palette.glazedWhite.o(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Palette.forgedGold,
          activeTrackColor: Palette.forgedGold.o(0.3),
          inactiveThumbColor: Palette.shadowGrey,
          inactiveTrackColor: Palette.shadowGrey.o(0.3),
        ),
      ],
    );
  }
}