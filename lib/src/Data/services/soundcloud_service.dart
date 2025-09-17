import 'dart:convert';
import 'package:gig_hub/src/data/services/soundcloud_authentication_service.dart';
import 'package:http/http.dart' as http;

class SoundcloudTrack {
  final int id;
  final String title;
  final String? streamUrl;
  final String permalinkUrl;
  final bool streamable;

  SoundcloudTrack({
    required this.id,
    required this.title,
    required this.streamable,
    required this.permalinkUrl,
    this.streamUrl,
  });

  factory SoundcloudTrack.fromJson(Map<String, dynamic> json) {
    return SoundcloudTrack(
      id: json['id'],
      title: json['title'] ?? '',
      streamable: json['streamable'],
      streamUrl: json['uri'],
      permalinkUrl: json['permalink_url'],
    );
  }
}

class SoundcloudService {
  final auth = SoundcloudAuth();
  Future<List<SoundcloudTrack>> fetchUserTracks() async {
    final accessToken = await auth.getAccessToken();
    final url = Uri.parse('https://api.soundcloud.com/me/tracks');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('failed to load tracks: ${response.statusCode}');
    }

    final List<dynamic> list = json.decode(response.body);
    final List<SoundcloudTrack> tracks = [];

    for (final raw in list) {
      final track = SoundcloudTrack.fromJson(raw);
      if (track.streamable) {
        if (track.permalinkUrl.isEmpty) {
          final details = await _fetchTrackDetails(track.id, accessToken!);
          tracks.add(
            SoundcloudTrack(
              id: track.id,
              title: track.title,
              streamable: track.streamable,
              streamUrl: track.streamUrl,
              permalinkUrl: details['permalink_url'],
            ),
          );
        } else {
          tracks.add(track);
        }
      }
    }
    return tracks;
  }

  Future<Map<String, dynamic>> _fetchTrackDetails(
    int id,
    String accessToken,
  ) async {
    final trackUrl = Uri.parse('https://api.soundcloud.com/tracks/$id');
    final response = await http.get(
      trackUrl,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {};
    }
  }

  Future<String> getPublicStreamUrl(String trackUri) async {
    final accessToken = await auth.getAccessToken();
    final client = http.Client();

    try {
      final uri = Uri.parse(trackUri);
      final urn = uri.pathSegments.last;

      final parts = urn.split(':');
      final trackId = parts.last;

      final streamsUrl = Uri.https(
        'api.soundcloud.com',
        '/tracks/$trackId/streams',
      );

      final response = await client.get(
        streamsUrl,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return '';
      }

      final data = jsonDecode(response.body);
      final streamUrl = data['http_mp3_128_url'];

      if (streamUrl != null && streamUrl.toString().isNotEmpty) {
        return streamUrl;
      }

      return '';
    } catch (e) {
      throw Exception(e.toString());
    } finally {
      client.close();
    }
  }
}
