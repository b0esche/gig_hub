import 'package:gig_hub/src/Data/app_imports.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.primalBlack,
      appBar: AppBar(
        backgroundColor: Palette.primalBlack,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 36),
          color: Palette.glazedWhite,
        ),
        title: Text(
          'Terms of Service',
          style: TextStyle(
            color: Palette.glazedWhite,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: Palette.glazedWhite),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Palette.forgedGold.o(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Palette.forgedGold.o(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gig Hub Terms of Service',
                    style: TextStyle(
                      color: Palette.forgedGold,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: ${DateTime.now().toString().split(' ')[0]}',
                    style: TextStyle(
                      color: Palette.glazedWhite.o(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Introduction
            _buildSection(
              '1. Introduction',
              'Welcome to Gig Hub! These Terms of Service ("Terms") govern your use of the Gig Hub mobile application and related services. By using our app, you agree to be bound by these Terms.',
            ),

            _buildSection(
              '2. Acceptance of Terms',
              'By downloading, installing, or using Gig Hub, you acknowledge that you have read, understood, and agree to be legally bound by these Terms. If you do not agree to these Terms, please do not use our service.',
            ),

            _buildSection(
              '3. Description of Service',
              'Gig Hub is a platform that connects DJs and event organizers. Our service allows users to:\n\n• Create and manage DJ profiles\n• Search for and book DJs\n• Organize and promote events\n• Connect with other users in the music community\n• Access music-related content and features',
            ),

            _buildSection(
              '4. User Accounts',
              '4.1 Account Creation: You must create an account to access certain features. You agree to provide accurate and complete information.\n\n4.2 Account Security: You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account.\n\n4.3 Account Types: We offer different account types (DJ, Booker, Guest) with varying features and capabilities.',
            ),

            _buildSection(
              '5. User Conduct',
              'You agree to use Gig Hub responsibly and in compliance with all applicable laws. You will not:\n\n• Post harmful, offensive, or illegal content\n• Harass, threaten, or abuse other users\n• Impersonate others or provide false information\n• Violate intellectual property rights\n• Attempt to gain unauthorized access to our systems\n• Use the service for commercial purposes without permission',
            ),

            _buildSection(
              '6. Content and Intellectual Property',
              '6.1 Your Content: You retain ownership of content you submit but grant us a license to use, display, and distribute it through our service.\n\n6.2 Our Content: All Gig Hub content, features, and functionality are owned by us and protected by intellectual property laws.\n\n6.3 Third-Party Content: We may integrate with third-party services like SoundCloud. Your use of such services is subject to their terms.',
            ),

            _buildSection(
              '7. Privacy',
              'Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.',
            ),

            _buildSection(
              '8. Payments and Transactions',
              '8.1 Booking Fees: Transactions between DJs and bookers are facilitated through our platform.\n\n8.2 Payment Processing: We use third-party payment processors and are not responsible for payment processing issues.\n\n8.3 Refunds: Refund policies are subject to individual agreements between users.',
            ),

            _buildSection(
              '9. Limitation of Liability',
              'TO THE MAXIMUM EXTENT PERMITTED BY LAW, GIG HUB SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING FROM YOUR USE OF THE SERVICE.',
            ),

            _buildSection(
              '10. Termination',
              'We may suspend or terminate your account at our discretion for violations of these Terms. You may also delete your account at any time through the app settings.',
            ),

            _buildSection(
              '11. Changes to Terms',
              'We reserve the right to modify these Terms at any time. We will notify users of significant changes through the app or email.',
            ),

            _buildSection(
              '12. Contact Information',
              'If you have questions about these Terms, please contact us through the app support feature or at our official support channels.',
            ),

            const SizedBox(height: 32),

            // Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Palette.glazedWhite.o(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Palette.glazedWhite.o(0.2)),
              ),
              child: Text(
                'By using Gig Hub, you acknowledge that you have read and understood these Terms of Service and agree to be bound by them.',
                style: TextStyle(
                  color: Palette.glazedWhite.o(0.8),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Palette.forgedGold,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            color: Palette.glazedWhite,
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
