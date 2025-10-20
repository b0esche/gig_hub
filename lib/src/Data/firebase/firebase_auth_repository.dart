import 'package:gig_hub/src/Data/app_imports.dart';
import 'package:gig_hub/src/Data/services/passkey_service.dart';

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
    try {
      // Initialize Google Sign In
      await GoogleSignIn.instance.initialize();

      // Authenticate with Google
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      // Provide more specific error messages
      if (e.toString().contains('cancelled') ||
          e.toString().contains('CANCEL')) {
        throw Exception('Google Sign In was cancelled');
      } else if (e.toString().contains('network')) {
        throw Exception(
          'Network error during Google Sign In. Please check your connection.',
        );
      } else {
        throw Exception('Google Sign In failed: ${e.toString()}');
      }
    }
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final userDoc = await db.collection('users').doc(user.uid).get();

    if (userDoc.exists) {
      final data = userDoc.data();
      final _ = data?['type'] as String?;

      // Delete user data from storage (avatar, etc)
      try {
        final storage = FirebaseStorage.instance;
        await storage.ref('avatars/${user.uid}.jpg').delete();
      } catch (_) {}

      // Delete user document from Firestore
      await db.collection('users').doc(user.uid).delete();
    }

    // Finally delete the auth user and sign out
    await user.delete().whenComplete(() async {
      await FirebaseAuth.instance.signOut();
      await CacheService().clearAllCaches();
    });
  }

  // user stream ###
  @override
  Stream<User?> authStateChanges() {
    return FirebaseAuth.instance.authStateChanges();
  }

  final PasskeyService _passkeyService = PasskeyService();

  @override
  Future<bool> isPasskeySupported() async {
    return await _passkeyService.isPasskeyAvailable();
  }

  @override
  Future<void> signUpWithPasskey(String email) async {
    final password = _passkeyService.generateStrongPassword();

    // Create Firebase user with generated password
    final userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    if (userCredential.user != null) {
      // Save passkey if user creation was successful
      await _passkeyService.savePasskey(email: email, password: password);
    }
  }

  @override
  Future<void> signInWithPasskey() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;

    final password = await _passkeyService.getPasskey(user!.email!);
    if (password != null) {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: user.email!,
        password: password,
      );
    }
  }

  @override
  Future<String> generateStrongPassword() async {
    return _passkeyService.generateStrongPassword();
  }
}
