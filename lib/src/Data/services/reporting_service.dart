import '../app_imports.dart';

class ReportingService {
  static Future<bool> sendReport({
    required AppUser reporter,
    required AppUser reportedUser,
    required String message,
    List<Uint8List>? screenshots,
  }) async {
    try {
      final List<String> attachments = [];

      if (screenshots != null && screenshots.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        for (int i = 0; i < screenshots.length; i++) {
          final file = File('${tempDir.path}/screenshot_$i.png');
          await file.writeAsBytes(screenshots[i]);
          attachments.add(file.path);
        }
      }

      final success = await EmailJSService.sendReport(
        subject: 'User Report - ${reportedUser.displayName}',
        message: message, // Just pass the raw message, EmailJS will format it
        senderEmail: reporter.email ?? 'noreply@gighub.app',
        reporterName: reporter.displayName,
        reportedUserName: reportedUser.displayName,
        reportedUserId: reportedUser.id,
        reporterType:
            reporter is DJ ? 'DJ' : (reporter is Booker ? 'Booker' : 'Guest'),
        reportedUserType:
            reportedUser is DJ
                ? 'DJ'
                : (reportedUser is Booker ? 'Booker' : 'Guest'),
        screenshots: attachments,
      );

      // Clean up temporary files
      for (final path in attachments) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }

      return success;
    } catch (e) {
      return false;
    }
  }
}
