import 'package:gig_hub/src/Data/app_imports.dart';

class FirebaseAuthRepository implements AuthRepository {
  // sign up w/ email ###
  @override
  Future<void> createUserWithEmailAndPassword(String email, String pw) async {
    final userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: pw);
    await userCredential.user?.sendEmailVerification();
  }

  // sign in w/ email ###
  @override
  Future<void> signInWithEmailAndPassword(String email, String pw) async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: pw,
    );
  }

  // sign in/up w/ apple ###
  @override
  Future<void> signInWithApple() async {
    try {
      // Check if Apple Sign In is available on this device
      final isAvailable = await SignInWithApple.isAvailable();

      if (!isAvailable) {
        throw Exception('Apple Sign In is not available on this device');
      }

      // Request Apple ID credential
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Create Firebase credential from Apple credential
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      // Sign in to Firebase with the Apple credential
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        oauthCredential,
      );

      // IMPORTANT: Use Apple-provided data, don't ask user again
      if (userCredential.user != null) {
        String displayName = '';

        // Use Apple-provided name if available
        if (credential.givenName != null || credential.familyName != null) {
          displayName =
              '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                  .trim();
        }

        // If Apple provided name, update Firebase user profile
        if (displayName.isNotEmpty) {
          await userCredential.user!.updateDisplayName(displayName);
        }
      }
    } catch (e) {
      rethrow; // Rethrow the original exception to preserve the exact error
    }
  }

  // sign in/up w/ google ###
  @override
  Future<void> signInWithGoogle() async {
    await GoogleSignIn.instance.initialize();
    final GoogleSignInAccount googleUser =
        await GoogleSignIn.instance.authenticate();

    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  // password reset ###
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  @override
  Future<String> verifyPasswordResetCode(String code) async {
    final email = await FirebaseAuth.instance.verifyPasswordResetCode(code);
    return email;
  }

  @override
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    await FirebaseAuth.instance.confirmPasswordReset(
      code: code,
      newPassword: newPassword,
    );
  }

  // sign out all ###
  @override
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    // Clear all cached data on logout to ensure fresh data on next login
    try {
      await CacheService().clearAllCaches();
    } catch (_) {}
  }

  // delete user and sign out
  @override
  Future<void> deleteUser() async {
    await FirebaseAuth.instance.currentUser!.delete().whenComplete(() async {
      await FirebaseAuth.instance.signOut();
    });
  }

  // user stream ###
  @override
  Stream<User?> authStateChanges() {
    return FirebaseAuth.instance.authStateChanges();
  }

  // Passkey support (placeholder for future implementation)
  @override
  Future<bool> isPasskeySupported() async {
    // Native passkey support would require platform-specific implementation
    // For now, we rely on iOS/Android native password management
    return false;
  }

  @override
  Future<void> signUpWithPasskey(String email) async {
    throw UnimplementedError('Native passkey support not yet implemented');
  }

  @override
  Future<void> signInWithPasskey() async {
    throw UnimplementedError('Native passkey support not yet implemented');
  }

  @override
  Future<String> generateStrongPassword() async {
    throw UnimplementedError('Use native system password generation instead');
  }
}
