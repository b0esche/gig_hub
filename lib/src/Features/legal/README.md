# Legal Agreement System

## Overview

The legal agreement system for Gig Hub ensures that users accept the Terms of Service and Privacy Policy before using the app. The system is designed to be compliant with app store requirements and follows the app's existing design patterns.

## Architecture

### Core Components

1. **LegalAgreementService** (`/lib/src/Features/legal/services/legal_agreement_service.dart`)
   - Handles persistence of agreement acceptance using SharedPreferences
   - Tracks version numbers for future updates
   - Provides methods to check and update agreement status

2. **LegalAgreementDialog** (`/lib/src/Features/legal/presentation/legal_agreement_dialog.dart`)
   - Interactive dialog for accepting agreements
   - Can be used in required mode (first-time users) or optional mode (settings)
   - Follows app's design system (Palette colors, rounded corners, etc.)

3. **TermsOfServiceScreen** (`/lib/src/Features/legal/presentation/terms_of_service_screen.dart`)
   - Full-screen view of Terms of Service
   - Scrollable content with proper formatting
   - Consistent with app's design patterns

4. **PrivacyPolicyScreen** (`/lib/src/Features/legal/presentation/privacy_policy_screen.dart`)
   - Full-screen view of Privacy Policy
   - Detailed information about data collection and usage
   - Matches app's visual styling

5. **LegalAgreementWrapper** (`/lib/src/Features/legal/presentation/legal_agreement_wrapper.dart`)
   - Wrapper component that shows legal dialog for new users
   - Integrates into the app's authentication flow
   - Prevents access to main app until agreements are accepted

6. **LegalStatusWidget** (`/lib/src/Features/legal/presentation/legal_status_widget.dart`)
   - Settings screen component showing agreement status
   - Allows existing users to review agreements
   - Visual indicator of acceptance status

## Integration Points

### App Startup Flow

The legal agreement check is integrated into the main app authentication flow in `app.dart`:

```dart
// After user authentication, check legal agreements
return FutureBuilder<bool>(
  future: LegalAgreementService.hasAcceptedAllAgreements(),
  builder: (context, legalSnap) {
    final hasAcceptedAgreements = legalSnap.data ?? false;
    
    if (!hasAcceptedAgreements) {
      return LegalAgreementWrapper(user: userSnap.data!);
    }
    
    return MainScreen(initialUser: userSnap.data!);
  },
);
```

### Settings Integration

The legal agreements are accessible from the settings screen through the `LegalStatusWidget`, which shows:
- ✅ Green status if all agreements are accepted
- ⚠️ Red status if agreements need review
- Quick access to review and re-accept agreements

## Design System Compliance

The legal system follows Gig Hub's established design patterns:

### Colors
- **Primary Background**: `Palette.primalBlack` (#212121)
- **Text**: `Palette.glazedWhite` (#F8F8F8)  
- **Accents**: `Palette.forgedGold` (#BBAF63)
- **Warnings**: `Palette.alarmRed` (#EB4848)

### Components
- **Dialogs**: `AlertDialog` with 16px border radius and gold borders
- **Buttons**: `ElevatedButton` with consistent styling and 8px border radius
- **Typography**: Google Fonts with proper hierarchy
- **Loading States**: Consistent spinner styling with gold color

## Usage Examples

### Check Agreement Status
```dart
final hasAccepted = await LegalAgreementService.hasAcceptedAllAgreements();
if (!hasAccepted) {
  // Show legal agreement dialog
}
```

### Show Legal Dialog
```dart
showDialog(
  context: context,
  builder: (context) => LegalAgreementDialog(
    isRequired: true, // or false for optional viewing
    onAccept: () async {
      await LegalAgreementService.acceptAllAgreements();
      // Continue with app flow
    },
  ),
);
```

### Navigate to Full Screens
```dart
// Terms of Service
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const TermsOfServiceScreen(),
  ),
);

// Privacy Policy  
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const PrivacyPolicyScreen(),
  ),
);
```

## Testing

To test the legal agreement system:

1. **Reset agreements**: Use `LegalAgreementService.resetAgreements()` to clear stored acceptance
2. **Check first-run flow**: Restart app after reset to see the legal dialog
3. **Test settings integration**: Navigate to settings to see the legal status widget
4. **Version updates**: Increment version numbers in `LegalAgreementService` to test update flow

## App Store Compliance

The system addresses key app store requirements:

- **Terms of Service**: Comprehensive terms covering user conduct, payments, liability
- **Privacy Policy**: Detailed privacy information including data collection, usage, and user rights
- **Mandatory Acceptance**: Users cannot proceed without accepting both agreements
- **Easy Access**: Agreements are always accessible from settings
- **Version Tracking**: System can handle agreement updates in the future

## Future Enhancements

- **Localization**: Terms and Privacy Policy can be localized using the existing `AppLocale` system
- **Remote Updates**: Agreements could be fetched from a server for easier updates
- **Granular Consent**: Individual consent options could be added for specific features
- **Audit Trail**: More detailed logging of when agreements were accepted could be added

## File Structure

```
lib/src/Features/legal/
├── presentation/
│   ├── legal_agreement_dialog.dart
│   ├── legal_agreement_wrapper.dart
│   ├── legal_status_widget.dart
│   ├── privacy_policy_screen.dart
│   └── terms_of_service_screen.dart
└── services/
    └── legal_agreement_service.dart
```