import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_email_sender/flutter_email_sender.dart';

class EmailJSService {
  static const String _serviceId = 'service_q635zng';
  static const String _templateId = 'template_4bvvpvt';
  static const String _publicKey = 'hSu3Ct4QWW8iGNm7J';
  static const String _supportEmail = 'b0eschex@gmail.com';
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  static Future<bool> sendReport({
    required String subject,
    required String message,
    required String senderEmail,
    required String reporterName,
    required String reportedUserName,
    required String reportedUserId,
    required String reporterType,
    required String reportedUserType,
    List<String>? screenshots,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final now = DateTime.now();
    final timeString =
        '${now.day}/${now.month}/${now.year} at ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    try {
      // Ensure the subject line contains the email for n8n extraction
      final n8nSubject =
          'User Report: $reportedUserName - REPLY_TO:$senderEmail';

      final templateParams = {
        // Email routing (must use verified sender)
        'from_name': 'GigHub Support System',
        'from_email': _supportEmail,
        'reply_to': senderEmail,
        'to_email': _supportEmail,
        'to_name': 'GigHub Support',

        // User information for n8n processing
        'user_name': reporterName,
        'user_email': senderEmail,
        'contact_email': senderEmail,
        'reported_user_name': reportedUserName,
        'reported_user_id': reportedUserId,
        'reporter_type': reporterType,
        'reported_user_type': reportedUserType,

        // Subject must contain email for n8n extraction
        'subject': n8nSubject,

        // Message with proper formatting
        'message': '''
🎧 USER REPORT

Report Details:
==============

Reported User:
- Name: $reportedUserName
- ID: $reportedUserId
- User Type: $reportedUserType

Reporter:
- Name: $reporterName
- Type: $reporterType
- Email: $senderEmail

Report Message:
===============
$message

${screenshots?.isNotEmpty == true ? '\nAttachments: ${screenshots!.join(', ')}\n' : ''}
📧 Reply to this email to respond directly to the reporter.
⏰ Submitted: $timeString''',

        // Template variables
        'name': reporterName,
        'time': timeString,
        'user_message': message,
        'customer_name': reporterName,
        'customer_email': senderEmail,
      };
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': templateParams,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }

      // If EmailJS fails, try system email as fallback
      return _fallbackToEmailClient(
        subject: subject,
        message: message,
        senderEmail: senderEmail,
        screenshots: screenshots,
      );
    } catch (e) {
      // On any error, fall back to system email
      return _fallbackToEmailClient(
        subject: subject,
        message: message,
        senderEmail: senderEmail,
        screenshots: screenshots,
      );
    }
  }

  static Future<bool> _fallbackToEmailClient({
    required String subject,
    required String message,
    required String senderEmail,
    List<String>? screenshots,
  }) async {
    try {
      final Email email = Email(
        subject: subject,
        body: message,
        recipients: [_supportEmail],
        cc: [senderEmail],
        attachmentPaths: screenshots ?? [],
      );

      await FlutterEmailSender.send(email);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> sendContactEmail({
    required String name,
    required String email,
    required String message,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final now = DateTime.now();
    final timeString =
        '${now.day}/${now.month}/${now.year} at ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    try {
      // Format exactly like the web version for n8n
      final templateParams = {
        // Email must come from verified address
        'from_name': 'GigHub Support System',
        'from_email': _supportEmail,
        'reply_to': email,
        'to_email': _supportEmail,
        'to_name': 'GigHub Support',

        // User information for n8n processing
        'user_name': name,
        'user_email': email,
        'contact_email': email,

        // Critical: Subject format for n8n email extraction
        'subject': 'GigHub Support from $name - REPLY_TO:$email',

        // Message with consistent formatting
        'message': '''
🎧 Contact Form Submission from: $name ($email)

$message

📧 Reply to this email to respond directly to the user.
⏰ Submitted: $timeString''',

        // Template variables for customization
        'name': name,
        'time': timeString,
        'user_message': message,
        'customer_name': name,
        'customer_email': email,
      };
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': templateParams,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }

      return _fallbackToEmailClient(
        subject: 'Contact Form: $name',
        message: message,
        senderEmail: email,
      );
    } catch (e) {
      return _fallbackToEmailClient(
        subject: 'Contact Form: $name',
        message: message,
        senderEmail: email,
      );
    }
  }
}
