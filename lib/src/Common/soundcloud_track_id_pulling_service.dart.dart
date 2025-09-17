import 'package:http/http.dart' as http;

import '../Data/app_imports.dart';

class SoundcloudTrackIdScreen extends StatefulWidget {
  const SoundcloudTrackIdScreen({super.key});

  @override
  SoundcloudTrackIdScreenState createState() => SoundcloudTrackIdScreenState();
}

class SoundcloudTrackIdScreenState extends State<SoundcloudTrackIdScreen> {
  final TextEditingController _urlController = TextEditingController();
  String? _trackId;
  bool _isLoading = false;
  String? _error;

  Future<void> _fetchTrackId() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _error = 'Bitte gib eine SoundCloud-URL ein.';
        _trackId = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _trackId = null;
    });

    try {
      final accessToken = await SoundcloudAuth().getAccessToken();

      final apiUrl = Uri.parse('https://api.soundcloud.com/resolve?url=$url');

      final response = await http.get(
        apiUrl,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final kind = data['kind'];
        final id = data['id'];

        if (kind == 'track' && id != null) {
          setState(() {
            _trackId = 'soundcloud:tracks:$id';
          });
        } else {
          setState(() {
            _error = 'Kein gültiger Track gefunden.';
          });
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _error = 'Unauthorized. Access Token ungültig oder abgelaufen.';
        });
      } else {
        setState(() {
          _error = 'Fehler ${response.statusCode}: ${response.reasonPhrase}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Fehler: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SoundCloud Track-ID holen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'SoundCloud Track-URL',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _fetchTrackId,
              child:
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Track-ID holen'),
            ),
            const SizedBox(height: 24),
            if (_trackId != null) ...[
              Text('Track-ID:', style: TextStyle(color: Palette.primalBlack)),
              const SizedBox(height: 8),
              SelectableText(
                _trackId!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
