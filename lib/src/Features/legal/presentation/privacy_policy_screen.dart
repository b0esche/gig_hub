import 'package:gig_hub/src/Data/app_imports.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'Privacy Policy',
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
                    'Gig Hub Privacy Policy',
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
              'At Gig Hub, we respect your privacy and are committed to protecting your personal data. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.',
            ),

            _buildSection(
              '2. Information We Collect',
              '2.1 Personal Information:\n• Name and contact details\n• Profile information (DJ skills, genres, location)\n• Account credentials\n• Payment information (processed by third parties)\n\n2.2 Usage Data:\n• App usage patterns and preferences\n• Device information and identifiers\n• Location data (when permitted)\n• Chat messages and interactions\n\n2.3 Third-Party Data:\n• SoundCloud profile information (when connected)\n• Social media profile data (when linked)',
            ),

            _buildSection(
              '3. How We Use Your Information',
              'We use your personal data to:\n\n• Provide and improve our services\n• Create and manage your account\n• Facilitate connections between DJs and bookers\n• Process payments and transactions\n• Send notifications and updates\n• Ensure platform security and prevent fraud\n• Analyze usage patterns to improve user experience\n• Comply with legal obligations',
            ),

            _buildSection(
              '4. Information Sharing',
              '4.1 With Other Users: Profile information is visible to other users as part of the platform\'s functionality.\n\n4.2 With Service Providers: We share data with trusted third parties who help us operate our service (payment processors, cloud storage, analytics).\n\n4.3 Legal Requirements: We may disclose information when required by law or to protect our rights and safety.\n\n4.4 Business Transfers: Information may be transferred in connection with mergers or acquisitions.',
            ),

            _buildSection(
              '5. Data Storage and Security',
              '5.1 Storage: Your data is stored on secure servers provided by Firebase and other trusted cloud services.\n\n5.2 Security Measures: We implement appropriate technical and organizational measures to protect your data against unauthorized access, alteration, disclosure, or destruction.\n\n5.3 Retention: We retain your data for as long as necessary to provide our services or as required by law.',
            ),

            _buildSection(
              '6. Your Rights and Choices',
              'You have the right to:\n\n• Access your personal data\n• Correct inaccurate information\n• Delete your account and associated data\n• Restrict processing of your data\n• Data portability (where applicable)\n• Object to certain processing activities\n• Withdraw consent at any time',
            ),

            _buildSection(
              '7. Location Data',
              'We may collect location data to:\n• Show nearby events and DJs\n• Provide location-based search results\n• Enable rave alerts in your area\n\nYou can control location permissions through your device settings.',
            ),

            _buildSection(
              '8. Third-Party Content and Services',
              'Our app integrates with third-party services and displays user-generated content:\n\n• SoundCloud: For music streaming and profile integration\n• Google Maps: For location services and event discovery\n• Firebase: For authentication, database, and analytics\n• Social Media: For profile connections and sharing\n\nWhen you use these features, you are also subject to their privacy policies and terms of service. We do not control how these third parties collect or use your data.',
            ),

            _buildSection(
              '9. User Content Rights',
              'You retain ownership of content you upload but grant us license to display and distribute it within our app. You are responsible for ensuring you have rights to any content you share. We may process user content to:\n\n• Display profiles and events\n• Enable search and discovery\n• Moderate inappropriate content\n• Comply with legal requirements',
            ),

            _buildSection(
              '10. Children\'s Privacy',
              'Gig Hub is not intended for users under 13 years of age. We do not knowingly collect personal information from children under 13. If we discover such information, we will delete it promptly.',
            ),

            _buildSection(
              '11. International Data Transfers',
              'Your data may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place to protect your data during such transfers.',
            ),

            _buildSection(
              '12. Changes to This Policy',
              'We may update this Privacy Policy from time to time. We will notify you of significant changes through the app or by email. Your continued use of the service after changes constitutes acceptance.',
            ),

            _buildSection(
              '13. Contact Us',
              'If you have questions about this Privacy Policy or how we handle your data, please contact us through:\n\n• In-app support feature\n• Email: b0eschex@gmail.com\n• App settings > Privacy & Legal',
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
                'We are committed to protecting your privacy and ensuring the security of your personal information. Thank you for trusting Gig Hub with your data.',
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
