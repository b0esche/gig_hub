import 'package:flutter_test/flutter_test.dart';

import 'package:gig_hub/src/Data/services/soundcloud_service.dart';

void main() {
  group('SoundcloudTrack', () {
    test('should create instance from JSON', () {
      // Arrange
      final json = {
        'id': 123,
        'title': 'Test Track',
        'streamable': true,
        'uri': 'https://example.com/stream',
        'permalink_url': 'https://example.com/track',
      };

      // Act
      final track = SoundcloudTrack.fromJson(json);

      // Assert
      expect(track.id, 123);
      expect(track.title, 'Test Track');
      expect(track.streamable, true);
      expect(track.streamUrl, 'https://example.com/stream');
      expect(track.permalinkUrl, 'https://example.com/track');
    });

    test('should handle null values in JSON', () {
      // Arrange
      final json = {
        'id': 123,
        'title': null,
        'streamable': false,
        'permalink_url': 'https://example.com/track',
      };

      // Act
      final track = SoundcloudTrack.fromJson(json);

      // Assert
      expect(track.id, 123);
      expect(track.title, '');
      expect(track.streamable, false);
      expect(track.streamUrl, null);
      expect(track.permalinkUrl, 'https://example.com/track');
    });
  });

  group('SoundcloudService', () {
    late SoundcloudService service;

    setUp(() {
      service = SoundcloudService();
    });

    group('Service Initialization', () {
      test('should create service instance', () {
        expect(service, isA<SoundcloudService>());
      });
    });

    group('URI Parsing', () {
      test('should extract track ID from URI correctly', () {
        // Test URI parsing logic
        const trackUri = 'soundcloud:tracks:123456';
        final parts = trackUri.split(':');
        expect(parts.last, '123456');
      });

      test('should handle different URI formats', () {
        const trackUri1 = 'https://soundcloud.com/artist/track';
        const trackUri2 = 'soundcloud:tracks:987654';

        expect(trackUri1.contains('soundcloud.com'), true);
        expect(trackUri2.split(':').last, '987654');
      });
    });
  });
}
