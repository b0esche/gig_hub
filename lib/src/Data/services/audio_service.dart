import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

class AudioService {
  static Future<String> downloadAudio(Map<String, dynamic> params) async {
    final String publicUrl = params['publicUrl'];
    final String filePath = params['filePath'];

    final request = http.Request('GET', Uri.parse(publicUrl));
    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception('failed to download audio');
    }

    final file = File(filePath);
    final sink = file.openWrite();

    try {
      int bytesWritten = 0;
      const yieldInterval = 128 * 1024;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesWritten += chunk.length;

        if (bytesWritten % yieldInterval == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      await sink.flush();
    } finally {
      await sink.close();
    }

    return filePath;
  }
}
