import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Service for compressing images before upload to reduce storage costs and improve performance
///
/// Features:
/// - Reduces image file size while maintaining reasonable quality
/// - Converts images to JPEG format for consistency
/// - Generates unique filenames to prevent conflicts
/// - Uses temporary directory for compressed file storage
class ImageCompressionService {
  /// Compresses an image file and returns the compressed version
  ///
  /// Takes an input file, compresses it to 70% quality in JPEG format,
  /// and saves it to a temporary location with a unique filename.
  ///
  /// @param file The original image file to compress
  /// @returns A compressed File object ready for upload
  /// @throws Exception if compression fails
  static Future<File> compressImage(File file) async {
    // Get temporary directory for storing compressed file
    final tempDir = await getTemporaryDirectory();
    // Generate unique filename to prevent conflicts
    final targetPath = '${tempDir.path}/${const Uuid().v4()}.jpg';

    // Compress the image with 70% quality and convert to JPEG
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      file.path,
      quality: 70, // Balance between file size and visual quality
      format: CompressFormat.jpeg, // Standardize format
    );

    if (compressedBytes == null) {
      throw Exception('image compression failed');
    }

    // Write compressed bytes to new file
    final compressedFile = File(targetPath);
    await compressedFile.writeAsBytes(compressedBytes);

    return compressedFile;
  }
}
