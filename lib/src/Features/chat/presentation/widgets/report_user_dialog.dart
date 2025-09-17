import '../../../../Data/app_imports.dart';

class ReportUserDialog extends StatefulWidget {
  final AppUser reportedUser;
  final AppUser currentUser;
  final VoidCallback? onReportComplete;

  const ReportUserDialog({
    super.key,
    required this.reportedUser,
    required this.currentUser,
    this.onReportComplete,
  });

  @override
  State<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<ReportUserDialog> {
  final TextEditingController _messageController = TextEditingController();
  final List<Uint8List> _screenshots = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _addScreenshot() async {
    if (_screenshots.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocale.maxTwoScreenshots.getString(context)),
          backgroundColor: Palette.alarmRed,
        ),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _screenshots.add(bytes);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add screenshot: $e'),
          backgroundColor: Palette.alarmRed,
        ),
      );
    }
  }

  void _removeScreenshot(int index) {
    setState(() {
      _screenshots.removeAt(index);
    });
  }

  Future<void> _submitReport() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please describe the issue'),
          backgroundColor: Palette.alarmRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ReportingService.sendReport(
        reporter: widget.currentUser,
        reportedUser: widget.reportedUser,
        message: message,
        screenshots: _screenshots.isNotEmpty ? _screenshots : null,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.reportSent.getString(context)),
            backgroundColor: Palette.forgedGold,
          ),
        );

        // Call the callback to handle blocking and chat deletion
        widget.onReportComplete?.call();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.reportFailed.getString(context)),
            backgroundColor: Palette.alarmRed,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Palette.alarmRed),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Palette.primalBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Palette.alarmRed, width: 2),
      ),
      title: Text(
        AppLocale.reportUser.getString(context),
        style: GoogleFonts.sometypeMono(
          textStyle: TextStyle(
            color: Palette.glazedWhite,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Palette.glazedWhite.o(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Palette.glazedWhite.o(0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage:
                        widget.reportedUser.avatarUrl.isNotEmpty
                            ? NetworkImage(widget.reportedUser.avatarUrl)
                            : const AssetImage(
                                  'assets/images/default_avatar.jpg',
                                )
                                as ImageProvider<Object>,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reporting: ${widget.reportedUser.displayName}',
                          style: TextStyle(
                            color: Palette.glazedWhite,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          widget.reportedUser is DJ ? 'DJ' : 'Booker',
                          style: TextStyle(
                            color: Palette.glazedWhite.o(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Message input
            Text(
              AppLocale.reportMessage.getString(context),
              style: TextStyle(
                color: Palette.glazedWhite,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Palette.glazedWhite, width: 1),
                borderRadius: BorderRadius.circular(8),
                color: Palette.glazedWhite.o(0.1),
              ),
              child: TextFormField(
                controller: _messageController,
                maxLength: 300,
                maxLines: 4,
                style: TextStyle(color: Palette.glazedWhite, fontSize: 14),
                decoration: InputDecoration(
                  counterStyle: TextStyle(color: Palette.shadowGrey.o(0.85)),
                  hintText: AppLocale.reportReason.getString(context),
                  hintStyle: TextStyle(color: Palette.glazedWhite.o(0.6)),
                  contentPadding: EdgeInsets.all(12),
                  border: InputBorder.none,
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Palette.alarmRed, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Screenshots section
            Text(
              AppLocale.addScreenshots.getString(context),
              style: TextStyle(
                color: Palette.glazedWhite,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),

            // Screenshot grid
            SizedBox(
              height: 80,
              child: Row(
                children: [
                  // Add screenshot button
                  if (_screenshots.length < 2)
                    GestureDetector(
                      onTap: _addScreenshot,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Palette.glazedWhite.o(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Palette.glazedWhite.o(0.3),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Icon(
                          Icons.add_photo_alternate,
                          color: Palette.glazedWhite,
                          size: 24,
                        ),
                      ),
                    ),

                  // Screenshot thumbnails
                  ..._screenshots.asMap().entries.map((entry) {
                    final index = entry.key;
                    final screenshot = entry.value;

                    return Container(
                      margin: const EdgeInsets.only(left: 8),
                      child: Stack(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: MemoryImage(screenshot),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _removeScreenshot(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Palette.alarmRed,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Palette.glazedWhite,
                                  size: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            AppLocale.cancel.getString(context),
            style: TextStyle(color: Palette.glazedWhite),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Palette.alarmRed,
            foregroundColor: Palette.glazedWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child:
              _isLoading
                  ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      color: Palette.glazedWhite,
                      strokeWidth: 2,
                    ),
                  )
                  : Text(
                    AppLocale.reportAndBlock.getString(context),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Palette.glazedWhite,
                    ),
                  ),
        ),
      ],
    );
  }
}
