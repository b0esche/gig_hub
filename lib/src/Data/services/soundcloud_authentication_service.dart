import 'package:gig_hub/src/Data/app_imports.dart';
import 'package:http/http.dart' as http;

class SoundcloudAuth {
  static final String clientId = dotenv.env['SOUNDCLOUD_CLIENT_ID'] ?? '';
  static final String clientSecret =
      dotenv.env['SOUNDCLOUD_CLIENT_SECRET'] ?? '';
  static final String redirectUri = dotenv.env['SOUNDCLOUD_REDIRECT_URI'] ?? '';
  static final String authEndpoint =
      dotenv.env['SOUNDCLOUD_AUTH_ENDPOINT'] ?? '';
  static final String tokenEndpoint =
      dotenv.env['SOUNDCLOUD_TOKEN_ENDPOINT'] ?? '';

  final _secureStorage = FlutterSecureStorage();
  String? _codeVerifier;

  Future<void> authenticate() async {
    _codeVerifier = _generateCodeVerifier();
    await _secureStorage.write(key: 'code_verifier', value: _codeVerifier!);

    final codeChallenge = _generateCodeChallenge(_codeVerifier!);

    final authUrl = Uri.parse(authEndpoint).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': 'non-expiring',
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge,
      },
    );

    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('failed to launch SoundCloud login url.');
    }
  }

  Future<void> exchangeCodeForToken(String code) async {
    _codeVerifier ??= await _secureStorage.read(key: 'code_verifier');

    if (_codeVerifier == null) {
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
          'code': code,
          'code_verifier': _codeVerifier!,
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];

        await _secureStorage.write(key: 'access_token', value: accessToken);
        if (refreshToken != null) {
          await _secureStorage.write(key: 'refresh_token', value: refreshToken);
        }
      } else {
        throw Exception('error on token exchange: ${response.body}');
      }
    } catch (e) {
      throw Exception('exception on token exchange: $e');
    }
    await _secureStorage.delete(key: 'code_verifier');
  }

  Future<String?> getAccessToken() async {
    final accessToken = await _secureStorage.read(key: 'access_token');

    if (accessToken != null && accessToken.isNotEmpty) {
      final isValid = await _isTokenValid(accessToken);
      if (isValid) return accessToken;
    }

    return await _refreshAccessToken();
  }

  Future<bool> _isTokenValid(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.soundcloud.com/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _secureStorage.read(key: 'refresh_token');

    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final newAccessToken = data['access_token'];
        final newRefreshToken = data['refresh_token'];

        await _secureStorage.write(key: 'access_token', value: newAccessToken);
        if (newRefreshToken != null) {
          await _secureStorage.write(
            key: 'refresh_token',
            value: newRefreshToken,
          );
        }

        return newAccessToken;
      } else {
        await _clearTokens();
      }
    } catch (e) {
      throw Exception('exception during token refresh: $e');
    }

    return null;
  }

  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
  }

  String _generateCodeVerifier([int length = 64]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
