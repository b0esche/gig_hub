import 'package:gig_hub/src/Data/app_imports.dart';

abstract class AuthRepository {
  Future<void> signInWithEmailAndPassword(String email, String pw);
  Future<void> createUserWithEmailAndPassword(String email, String pw);
  Future<void> signOut();
  Future<void> signInWithApple();
  Future<void> signInWithGoogle();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> confirmPasswordReset(String code, String newPassword);
  Future<void> deleteUser();
  Future<String> verifyPasswordResetCode(String code);
  Stream<User?> authStateChanges();
}
