import 'package:gig_hub/src/Data/app_imports.dart';
import 'package:gig_hub/src/Features/legal/presentation/legal_agreement_dialog.dart';
import 'package:gig_hub/src/Features/legal/services/legal_agreement_service.dart';

class LegalStatusWidget extends StatefulWidget {
  const LegalStatusWidget({super.key});

  @override
  State<LegalStatusWidget> createState() => _LegalStatusWidgetState();
}

class _LegalStatusWidgetState extends State<LegalStatusWidget> {
  bool _hasAcceptedTerms = false;
  bool _hasAcceptedPrivacy = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgreementStatus();
  }

  Future<void> _loadAgreementStatus() async {
    setState(() => _isLoading = true);

    try {
      final termsAccepted = await LegalAgreementService.hasAcceptedTerms();
      final privacyAccepted = await LegalAgreementService.hasAcceptedPrivacy();

      if (mounted) {
        setState(() {
          _hasAcceptedTerms = termsAccepted;
          _hasAcceptedPrivacy = privacyAccepted;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLegalAgreements() {
    showDialog(
      context: context,
      builder:
          (context) => LegalAgreementDialog(
            isRequired: false,
            onAccept: () async {
              await LegalAgreementService.acceptAllAgreements();
              _loadAgreementStatus(); // Refresh status
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 48,
        width: MediaQuery.of(context).size.width / 1.4,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Center(
          child: CircularProgressIndicator(
            color: Palette.forgedGold,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final allAccepted = _hasAcceptedTerms && _hasAcceptedPrivacy;

    return Container(
      height: 48,
      width: MediaQuery.of(context).size.width / 1.4,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              allAccepted ? Palette.forgedGold.o(0.1) : Palette.alarmRed.o(0.1),
          foregroundColor: allAccepted ? Palette.forgedGold : Palette.alarmRed,
          elevation: 0,
          splashFactory: NoSplash.splashFactory,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color:
                  allAccepted
                      ? Palette.forgedGold.o(0.7)
                      : Palette.alarmRed.o(0.7),
              width: 2,
            ),
          ),
        ),
        onPressed: _showLegalAgreements,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(allAccepted ? Icons.check_circle : Icons.warning, size: 16),
            const SizedBox(width: 8),
            Text(
              allAccepted ? 'legal agreements' : 'review agreements',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
