import 'package:flutter/material.dart';
import 'package:gig_hub/src/Data/models/users.dart';
import 'package:gig_hub/src/Theme/palette.dart';
import 'package:gig_hub/src/Common/pages/main_screen.dart';
import 'package:gig_hub/src/Features/legal/presentation/legal_agreement_dialog.dart';
import 'package:gig_hub/src/Features/legal/services/legal_agreement_service.dart';

class LegalAgreementWrapper extends StatefulWidget {
  final AppUser user;

  const LegalAgreementWrapper({super.key, required this.user});

  @override
  State<LegalAgreementWrapper> createState() => _LegalAgreementWrapperState();
}

class _LegalAgreementWrapperState extends State<LegalAgreementWrapper> {
  bool _showDialog = true;

  @override
  void initState() {
    super.initState();
    // Show the dialog immediately when this screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLegalAgreementDialog();
    });
  }

  void _showLegalAgreementDialog() {
    if (!_showDialog) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing without accepting
      builder:
          (context) => LegalAgreementDialog(
            isRequired: true,
            onAccept: () async {
              // Save acceptance to SharedPreferences
              await LegalAgreementService.acceptAllAgreements();

              if (mounted) {
                setState(() {
                  _showDialog = false;
                });
              }
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If dialog is dismissed and agreements are accepted, show MainScreen
    if (!_showDialog) {
      return MainScreen(initialUser: widget.user);
    }

    // Show a loading screen while the dialog is being displayed
    return Scaffold(
      backgroundColor: Palette.primalBlack,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Palette.forgedGold,
              strokeWidth: 1.65,
            ),
            const SizedBox(height: 20),
            Text(
              'Loading legal agreements...',
              style: TextStyle(color: Palette.glazedWhite, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
