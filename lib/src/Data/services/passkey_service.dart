import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

class PasskeyService {
  final _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  final _random = Random.secure();

  Future<bool> isPasskeyAvailable() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  String generateStrongPassword() {
    const length = 20;
    const letterLowerCase = "abcdefghijklmnopqrstuvwxyz";
    const letterUpperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const number = "0123456789";
    const special = "@#=+!£\$%&?[](){}";

    String chars = "";
    chars += letterLowerCase;
    chars += letterUpperCase;
    chars += number;
    chars += special;

    return List.generate(length, (index) {
      final indexRandom = _random.nextInt(chars.length);
      return chars[indexRandom];
    }).join('');
  }

  Future<void> savePasskey({
    required String email,
    required String password,
  }) async {
    try {
      final canAuth = await _auth.authenticate(
        localizedReason: 'Secure your password with biometrics',
        options: const AuthenticationOptions(
          biometricOnly: true,
          sensitiveTransaction: true,
        ),
      );

      if (canAuth) {
        // Hash the email to use as storage key
        final emailHash = sha256.convert(utf8.encode(email)).toString();
        await _storage.write(
          key: emailHash,
          value: password,
          iOptions: const IOSOptions(
            accessibility: KeychainAccessibility.unlocked,
            synchronizable: true, // Enable iCloud Keychain sync
          ),
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> getPasskey(String email) async {
    try {
      final canAuth = await _auth.authenticate(
        localizedReason: 'Access your saved password',
        options: const AuthenticationOptions(
          biometricOnly: true,
          sensitiveTransaction: true,
        ),
      );

      if (canAuth) {
        final emailHash = sha256.convert(utf8.encode(email)).toString();
        return await _storage.read(
          key: emailHash,
          iOptions: const IOSOptions(
            accessibility: KeychainAccessibility.unlocked,
            synchronizable: true,
          ),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> deletePasskey(String email) async {
    try {
      final emailHash = sha256.convert(utf8.encode(email)).toString();
      await _storage.delete(
        key: emailHash,
        iOptions: const IOSOptions(
          accessibility: KeychainAccessibility.unlocked,
        ),
      );
    } catch (e) {
      rethrow;
    }
  }
}
