import 'package:flutter_test/flutter_test.dart';
import 'package:gig_hub/src/Data/models/users.dart';

void main() {
  group('AppUser Models', () {
    group('Guest', () {
      test('should create a Guest with default values', () {
        final guest = Guest(
          id: 'test-id',
          avatarImageUrl: 'https://example.com/avatar.jpg',
        );

        expect(guest.id, 'test-id');
        expect(guest.type, UserType.guest);
        expect(guest.avatarImageUrl, 'https://example.com/avatar.jpg');
        expect(guest.name, '');
        expect(guest.favoriteUIds, isEmpty);
        expect(guest.isFlinta, false);
      });

      test('should create a Guest with custom values', () {
        final guest = Guest(
          id: 'test-id',
          avatarImageUrl: 'https://example.com/avatar.jpg',
          name: 'TestUser',
          favoriteUIds: ['dj1', 'dj2'],
          isFlinta: true,
        );

        expect(guest.name, 'TestUser');
        expect(guest.favoriteUIds, ['dj1', 'dj2']);
        expect(guest.isFlinta, true);
      });

      test('should serialize to JSON correctly', () {
        final guest = Guest(
          id: 'test-id',
          avatarImageUrl: 'https://example.com/avatar.jpg',
          name: 'TestUser',
          favoriteUIds: ['dj1', 'dj2'],
          isFlinta: true,
        );

        final json = guest.toJson();

        expect(json['type'], 'guest');
        expect(json['name'], 'TestUser');
        expect(json['favoriteUIds'], ['dj1', 'dj2']);
        expect(json['avatarImageUrl'], 'https://example.com/avatar.jpg');
        expect(json['isFlinta'], true);
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'type': 'guest',
          'name': 'TestUser',
          'favoriteUIds': ['dj1', 'dj2'],
          'avatarImageUrl': 'https://example.com/avatar.jpg',
          'isFlinta': true,
        };

        final guest = Guest.fromJson('test-id', json);

        expect(guest.id, 'test-id');
        expect(guest.type, UserType.guest);
        expect(guest.name, 'TestUser');
        expect(guest.favoriteUIds, ['dj1', 'dj2']);
        expect(guest.avatarImageUrl, 'https://example.com/avatar.jpg');
        expect(guest.isFlinta, true);
      });

      test('should handle missing optional fields in JSON', () {
        final json = {
          'type': 'guest',
          'avatarImageUrl': 'https://example.com/avatar.jpg',
        };

        final guest = Guest.fromJson('test-id', json);

        expect(guest.name, '');
        expect(guest.favoriteUIds, isEmpty);
        expect(guest.isFlinta, false);
      });
    });

    group('DJ', () {
      test('should create a DJ with required fields', () {
        final dj = DJ(
          id: 'dj-id',
          avatarImageUrl: 'https://example.com/avatar.jpg',
          headImageUrl: 'https://example.com/head.jpg',
          name: 'DJ Test',
          city: 'Berlin',
          about: 'About text',
          info: 'Info text',
          genres: ['Techno', 'House'],
          bpm: [120, 130],
          streamingUrls: ['url1', 'url2'],
          trackTitles: ['Track 1', 'Track 2'],
          trackUrls: ['track1.mp3', 'track2.mp3'],
        );

        expect(dj.id, 'dj-id');
        expect(dj.type, UserType.dj);
        expect(dj.name, 'DJ Test');
        expect(dj.city, 'Berlin');
        expect(dj.genres, ['Techno', 'House']);
        expect(dj.bpm, [120, 130]);
        expect(dj.avgRating, 0.0);
        expect(dj.ratingCount, 0);
        expect(dj.mediaImageUrls, isEmpty);
        expect(dj.favoriteUIds, isEmpty);
      });

      test('should serialize to JSON correctly', () {
        final dj = DJ(
          id: 'dj-id',
          avatarImageUrl: 'https://example.com/avatar.jpg',
          headImageUrl: 'https://example.com/head.jpg',
          name: 'DJ Test',
          city: 'Berlin',
          about: 'About text',
          info: 'Info text',
          genres: ['Techno', 'House'],
          bpm: [120, 130],
          streamingUrls: ['url1', 'url2'],
          trackTitles: ['Track 1', 'Track 2'],
          trackUrls: ['track1.mp3', 'track2.mp3'],
          avgRating: 4.5,
          ratingCount: 10,
        );

        final json = dj.toJson();

        expect(json['type'], 'dj');
        expect(json['name'], 'DJ Test');
        expect(json['city'], 'Berlin');
        expect(json['genres'], ['Techno', 'House']);
        expect(json['bpm'], [120, 130]);
        expect(json['avgRating'], 4.5);
        expect(json['ratingCount'], 10);
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'type': 'dj',
          'avatarImageUrl': 'https://example.com/avatar.jpg',
          'headImageUrl': 'https://example.com/head.jpg',
          'name': 'DJ Test',
          'city': 'Berlin',
          'about': 'About text',
          'info': 'Info text',
          'genres': ['Techno', 'House'],
          'bpm': [120, 130],
          'streamingUrls': ['url1', 'url2'],
          'trackTitles': ['Track 1', 'Track 2'],
          'trackUrls': ['track1.mp3', 'track2.mp3'],
          'avgRating': 4.5,
          'ratingCount': 10,
        };

        final dj = DJ.fromJson('dj-id', json);

        expect(dj.id, 'dj-id');
        expect(dj.name, 'DJ Test');
        expect(dj.avgRating, 4.5);
        expect(dj.ratingCount, 10);
      });
    });

    group('Booker', () {
      test('should create a Booker with required fields', () {
        final booker = Booker(
          id: 'booker-id',
          avatarImageUrl: 'https://example.com/avatar.jpg',
          headImageUrl: 'https://example.com/head.jpg',
          name: 'Event Booker',
          city: 'Munich',
          about: 'About text',
          info: 'Info text',
          category: 'Club',
        );

        expect(booker.id, 'booker-id');
        expect(booker.type, UserType.booker);
        expect(booker.name, 'Event Booker');
        expect(booker.city, 'Munich');
        expect(booker.category, 'Club');
        expect(booker.avgRating, 0.0);
        expect(booker.ratingCount, 0);
      });

      test('should serialize and deserialize correctly', () {
        final booker = Booker(
          id: 'booker-id',
          avatarImageUrl: 'https://example.com/avatar.jpg',
          headImageUrl: 'https://example.com/head.jpg',
          name: 'Event Booker',
          city: 'Munich',
          about: 'About text',
          info: 'Info text',
          category: 'Club',
          avgRating: 4.2,
          ratingCount: 5,
        );

        final json = booker.toJson();
        final recreated = Booker.fromJson('booker-id', json);

        expect(recreated.id, booker.id);
        expect(recreated.name, booker.name);
        expect(recreated.city, booker.city);
        expect(recreated.category, booker.category);
        expect(recreated.avgRating, booker.avgRating);
        expect(recreated.ratingCount, booker.ratingCount);
      });
    });

    group('AppUser Factory', () {
      test('should create correct user type from JSON', () {
        final guestJson = {
          'type': 'guest',
          'avatarImageUrl': 'https://example.com/avatar.jpg',
        };

        final djJson = {
          'type': 'dj',
          'avatarImageUrl': 'https://example.com/avatar.jpg',
          'headImageUrl': 'https://example.com/head.jpg',
          'name': 'DJ Test',
          'city': 'Berlin',
          'about': 'About',
          'info': 'Info',
          'genres': [],
          'bpm': [],
          'streamingUrls': [],
          'trackTitles': [],
          'trackUrls': [],
        };

        final bookerJson = {
          'type': 'booker',
          'avatarImageUrl': 'https://example.com/avatar.jpg',
          'headImageUrl': 'https://example.com/head.jpg',
          'name': 'Booker Test',
          'city': 'Munich',
          'about': 'About',
          'info': 'Info',
          'category': 'Club',
        };

        final guest = AppUser.fromJson('id1', guestJson);
        final dj = AppUser.fromJson('id2', djJson);
        final booker = AppUser.fromJson('id3', bookerJson);

        expect(guest, isA<Guest>());
        expect(dj, isA<DJ>());
        expect(booker, isA<Booker>());
      });

      test('should throw exception for unknown user type', () {
        final json = {
          'type': 'unknown',
          'avatarImageUrl': 'https://example.com/avatar.jpg',
        };

        expect(() => AppUser.fromJson('id', json), throwsA(isA<Exception>()));
      });
    });

    group('AppUserView Extension', () {
      test('should return correct display names', () {
        final guest = Guest(
          id: 'guest-id',
          avatarImageUrl: 'url',
          name: 'GuestName',
        );
        final guestEmpty = Guest(id: 'guest-id', avatarImageUrl: 'url');
        final dj = DJ(
          id: 'dj-id',
          avatarImageUrl: 'url',
          headImageUrl: 'url',
          name: 'DJ Name',
          city: 'City',
          about: 'About',
          info: 'Info',
          genres: [],
          bpm: [],
          streamingUrls: [],
          trackTitles: [],
          trackUrls: [],
        );
        final booker = Booker(
          id: 'booker-id',
          avatarImageUrl: 'url',
          headImageUrl: 'url',
          name: 'Booker Name',
          city: 'City',
          about: 'About',
          info: 'Info',
          category: 'Club',
        );

        expect(guest.displayName, 'GuestName');
        expect(guestEmpty.displayName, 'Guest');
        expect(dj.displayName, 'DJ Name');
        expect(booker.displayName, 'Booker Name');
      });

      test('should return correct avatar URLs', () {
        final guest = Guest(
          id: 'guest-id',
          avatarImageUrl: 'https://example.com/guest.jpg',
        );
        final dj = DJ(
          id: 'dj-id',
          avatarImageUrl: 'https://example.com/dj.jpg',
          headImageUrl: 'url',
          name: 'DJ Name',
          city: 'City',
          about: 'About',
          info: 'Info',
          genres: [],
          bpm: [],
          streamingUrls: [],
          trackTitles: [],
          trackUrls: [],
        );

        expect(guest.avatarUrl, 'https://example.com/guest.jpg');
        expect(dj.avatarUrl, 'https://example.com/dj.jpg');
      });
    });
  });
}
