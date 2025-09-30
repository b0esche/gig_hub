import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Data/app_imports.dart';

class ContentReportButton extends StatelessWidget {
  final String contentId;
  final String contentType; // 'profile', 'event', 'message', 'rave'
  final String reportedUserId;
  final String? contentTitle; // Optional title for context

  const ContentReportButton({
    Key? key,
    required this.contentId,
    required this.contentType,
    required this.reportedUserId,
    this.contentTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.report_outlined,
        color: Palette.glazedWhite.o(0.6),
        size: 20,
      ),
      onPressed: () => _showReportDialog(context),
      tooltip: 'Report Content',
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Palette.primalBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Palette.forgedGold, width: 1),
            ),
            title: Text(
              'Report Content',
              style: GoogleFonts.sometypeMono(
                color: Palette.forgedGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (contentTitle != null) ...[
                    Text(
                      'Reporting: ${contentTitle!}',
                      style: GoogleFonts.sometypeMono(
                        color: Palette.glazedWhite.o(0.8),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 12),
                  ],
                  Text(
                    'Why are you reporting this content?',
                    style: GoogleFonts.sometypeMono(
                      color: Palette.glazedWhite,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 16),
                  ..._getReportOptions(context),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.sometypeMono(
                    color: Palette.glazedWhite.o(0.6),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  List<Widget> _getReportOptions(BuildContext context) {
    final options = [
      {
        'title': 'Inappropriate Content',
        'subtitle': 'Adult content, violence, etc.',
      },
      {
        'title': 'Copyright Violation',
        'subtitle': 'Unauthorized use of copyrighted material',
      },
      {
        'title': 'Spam or Misleading',
        'subtitle': 'Fake information, spam, scams',
      },
      {
        'title': 'Harassment or Bullying',
        'subtitle': 'Threatening or abusive behavior',
      },
      {
        'title': 'Privacy Violation',
        'subtitle': 'Sharing personal information without consent',
      },
      {'title': 'Other', 'subtitle': 'Something else that violates our terms'},
    ];

    return options
        .map(
          (option) => InkWell(
            onTap: () => _submitReport(context, option['title']!),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Palette.shadowGrey.o(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option['title']!,
                    style: GoogleFonts.sometypeMono(
                      color: Palette.glazedWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    option['subtitle']!,
                    style: GoogleFonts.sometypeMono(
                      color: Palette.glazedWhite.o(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .toList();
  }

  Future<void> _submitReport(BuildContext context, String reason) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Center(
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Palette.primalBlack,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Palette.forgedGold),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Palette.forgedGold),
                  SizedBox(height: 16),
                  Text(
                    'Submitting report...',
                    style: GoogleFonts.sometypeMono(color: Palette.glazedWhite),
                  ),
                ],
              ),
            ),
          ),
    );

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Submit report to Firestore
      await FirebaseFirestore.instance.collection('content_reports').add({
        'contentId': contentId,
        'contentType': contentType,
        'contentTitle': contentTitle,
        'reportedUserId': reportedUserId,
        'reportedBy': currentUser.uid,
        'reporterEmail': currentUser.email,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'reviewed': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Close dialogs
      Navigator.of(context).pop(); // Loading dialog
      Navigator.of(context).pop(); // Report dialog

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Palette.primalBlack),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Report submitted successfully. We\'ll review it within 24 hours.',
                  style: GoogleFonts.sometypeMono(
                    color: Palette.primalBlack,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Palette.forgedGold,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Palette.glazedWhite),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Failed to submit report. Please try again.',
                  style: GoogleFonts.sometypeMono(
                    color: Palette.glazedWhite,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Palette.alarmRed,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}
