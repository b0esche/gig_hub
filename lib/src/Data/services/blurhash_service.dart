import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:image/image.dart' as img;

class BlurHashService {
  /// Generates a BlurHash string from an image file
  static Future<String> generateBlurHash(File imageFile) async {
    try {
      // Read the image file
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Decode the image
      final img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize image for BlurHash generation (smaller = faster)
      // BlurHash generation works best with smaller images
      final img.Image resizedImage = img.copyResize(
        image,
        width: 64,
        height: 64,
      );

      // Generate BlurHash with 4x3 components (good balance of quality and performance)
      final BlurHash blurHash = BlurHash.encode(
        resizedImage,
        numCompX: 4,
        numCompY: 3,
      );

      return blurHash.hash;
    } catch (e) {
      // Return a default BlurHash for a gray color if generation fails
      return defaultBlurHash;
    }
  }

  /// Generates BlurHash from image bytes (useful for network images)
  static Future<String> generateBlurHashFromBytes(Uint8List imageBytes) async {
    try {
      // Decode the image
      final img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image from bytes');
      }

      // Resize image for BlurHash generation
      final img.Image resizedImage = img.copyResize(
        image,
        width: 64,
        height: 64,
      );

      // Generate BlurHash
      final BlurHash blurHash = BlurHash.encode(
        resizedImage,
        numCompX: 4,
        numCompY: 3,
      );

      return blurHash.hash;
    } catch (e) {
      // Return a default BlurHash for a gray color if generation fails
      return defaultBlurHash;
    }
  }

  /// Default BlurHash for when no image is available or generation fails
  static const String defaultBlurHash = 'L9ABc#xu00%M~qRj%Mt7M{j[s:kC';

  /// Validates if a BlurHash string is valid
  static bool isValidBlurHash(String? hash) {
    if (hash == null || hash.isEmpty) return false;
    try {
      // Try to decode the BlurHash to validate it
      BlurHash.decode(hash);
      return true;
    } catch (e) {
      return false;
    }
  }
}
