import 'package:gig_hub/src/Data/app_imports.dart';
import 'package:gig_hub/src/Features/legal/presentation/terms_of_service_screen.dart';
import 'package:gig_hub/src/Features/legal/presentation/privacy_policy_screen.dart';
import 'package:gig_hub/src/Features/legal/services/legal_agreement_service.dart';

class LegalAgreementDialog extends StatefulWidget {
  final VoidCallback? onAccept;
  final bool isRequired;

  const LegalAgreementDialog({
    super.key,
    this.onAccept,
    this.isRequired = false,
  });

  @override
  State<LegalAgreementDialog> createState() => _LegalAgreementDialogState();
}

class _LegalAgreementDialogState extends State<LegalAgreementDialog> {
  bool _hasAcceptedTerms = false;
  bool _hasAcceptedPrivacy = false;
  bool _isLoading = true;

  bool get _canProceed => _hasAcceptedTerms && _hasAcceptedPrivacy;

  @override
  void initState() {
    super.initState();
    _loadCurrentAgreementStatus();
  }

  Future<void> _loadCurrentAgreementStatus() async {
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
          Icon(Icons.gavel_rounded, color: Palette.forgedGold, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Legal Agreements',
              style: TextStyle(
                color: Palette.forgedGold,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!widget.isRequired)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: Palette.glazedWhite.o(0.7)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child:
            _isLoading
                ? SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Palette.forgedGold,
                      strokeWidth: 2,
                    ),
                  ),
                )
                : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Introduction text
                    Text(
                      widget.isRequired
                          ? 'To continue using Gig Hub, please review and accept our legal agreements:'
                          : 'Please review our legal agreements:',
                      style: TextStyle(
                        color: Palette.glazedWhite.o(0.9),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Terms of Service Section
                    _buildAgreementSection(
                      title: 'Terms of Service',
                      description: 'Rules and guidelines for using Gig Hub',
                      isAccepted: _hasAcceptedTerms,
                      onToggle:
                          (value) => setState(
                            () => _hasAcceptedTerms = value ?? false,
                          ),
                      onViewPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TermsOfServiceScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Privacy Policy Section
                    _buildAgreementSection(
                      title: 'Privacy Policy',
                      description: 'How we collect, use, and protect your data',
                      isAccepted: _hasAcceptedPrivacy,
                      onToggle:
                          (value) => setState(
                            () => _hasAcceptedPrivacy = value ?? false,
                          ),
                      onViewPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyScreen(),
                          ),
                        );
                      },
                    ),

                    if (widget.isRequired) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Palette.forgedGold.o(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Palette.forgedGold.o(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Palette.forgedGold,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Acceptance of both agreements is required to continue.',
                                style: TextStyle(
                                  color: Palette.glazedWhite.o(0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
      ),
      actions: [
        if (!widget.isRequired)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Palette.glazedWhite.o(0.7),
            ),
            child: const Text('Close'),
          ),
        ElevatedButton(
          onPressed:
              _canProceed
                  ? () {
                    Navigator.of(context).pop();
                    widget.onAccept?.call();
                  }
                  : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _canProceed ? Palette.forgedGold : Palette.gigGrey.o(0.3),
            foregroundColor:
                _canProceed ? Palette.primalBlack : Palette.glazedWhite.o(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            widget.isRequired ? 'Accept & Continue' : 'Accept',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    );
  }

  Widget _buildAgreementSection({
    required String title,
    required String description,
    required bool isAccepted,
    required ValueChanged<bool?> onToggle,
    required VoidCallback onViewPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.glazedWhite.o(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isAccepted
                  ? Palette.forgedGold.o(0.5)
                  : Palette.glazedWhite.o(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Palette.glazedWhite.o(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onViewPressed,
                style: TextButton.styleFrom(
                  foregroundColor: Palette.forgedGold,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: isAccepted,
                  onChanged: onToggle,
                  activeColor: Palette.forgedGold,
                  checkColor: Palette.primalBlack,
                  side: BorderSide(
                    color:
                        isAccepted
                            ? Palette.forgedGold
                            : Palette.glazedWhite.o(0.5),
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'I have read and agree to the $title',
                  style: TextStyle(
                    color: Palette.glazedWhite.o(0.9),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
