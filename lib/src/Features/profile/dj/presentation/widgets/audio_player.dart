import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:gig_hub/src/Data/services/soundcloud_service.dart';
import 'package:gig_hub/src/Data/services/background_audio_service.dart';
import 'package:gig_hub/src/Theme/palette.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AudioPlayerCoordinator {
  static AudioPlayerCoordinator? _instance;
  static AudioPlayerCoordinator get instance =>
      _instance ??= AudioPlayerCoordinator._();

  AudioPlayerCoordinator._();

  AudioPlayerWidgetState? _currentlyPlaying;

  void requestPlayback(AudioPlayerWidgetState player) {
    if (_currentlyPlaying != null && _currentlyPlaying != player) {
      _currentlyPlaying!._stopFromCoordinator();
      // Clear the current player immediately to avoid state conflicts
      _currentlyPlaying = null;
    }
    _currentlyPlaying = player;
  }

  void playerStopped(AudioPlayerWidgetState player) {
    if (_currentlyPlaying == player) {
      _currentlyPlaying = null;
    }
  }

  // Get the currently playing session ID for background service coordination
  String? get currentlyPlayingSessionId => _currentlyPlaying?.widget.sessionId;
}

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String trackTitle;
  final String artistName;
  final String? artworkUrl;
  final String sessionId; // Unique identifier for this player instance

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.trackTitle,
    required this.artistName,
    required this.sessionId,
    this.artworkUrl,
  });

  @override
  State<AudioPlayerWidget> createState() => AudioPlayerWidgetState();

  static Future<String> downloadAndSaveAudio(
    Map<String, dynamic> params,
  ) async {
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

class AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with TickerProviderStateMixin {
  AudioPlayer? _audioPlayer;
  late AnimationController _controller;

  bool _isLoading = true;
  bool _isPlaying = false;
  bool _hasFinished = false;

  Duration? _duration;
  Duration _position = Duration.zero;
  List<double> _waveformData = [];

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(milliseconds: 350),
      vsync: this,
    );

    _init();
  }

  Future<void> _init() async {
    try {
      // Use the shared background player
      final backgroundService = BackgroundAudioService.instance;
      _audioPlayer = backgroundService.getSharedPlayer();

      _playerStateSubscription = _audioPlayer!.playerStateStream.listen((
        state,
      ) {
        if (mounted) {
          // Only update state if this session is active
          final isThisSessionActive = backgroundService.isSessionActive(
            widget.sessionId,
          );
          setState(() {
            _isPlaying = isThisSessionActive && state.playing;
            _hasFinished =
                isThisSessionActive &&
                state.processingState == ProcessingState.completed;
          });

          if (isThisSessionActive && state.playing) {
            _controller.forward();
            AudioPlayerCoordinator.instance.requestPlayback(this);
          } else {
            _controller.reverse();
            if (isThisSessionActive) {
              AudioPlayerCoordinator.instance.playerStopped(this);
            }
          }
        }
      });

      _positionSubscription = _audioPlayer!.positionStream.listen((position) {
        if (mounted) {
          // Only update position if this session is active
          final isThisSessionActive = BackgroundAudioService.instance
              .isSessionActive(widget.sessionId);
          if (isThisSessionActive) {
            setState(() => _position = position);
          }
        }
      });

      _durationSubscription = _audioPlayer!.durationStream.listen((duration) {
        if (mounted) {
          // Only update duration if this session is active
          final isThisSessionActive = BackgroundAudioService.instance
              .isSessionActive(widget.sessionId);
          if (isThisSessionActive) {
            setState(() => _duration = duration);
          }
        }
      });

      // Show simple waveform initially
      _showSimpleWaveform();

      // Load waveform data in the background for better UX
      _loadWaveformInBackground();

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadWaveformInBackground() async {
    try {
      // Get the streaming URL for waveform extraction
      final urlToStream = widget.audioUrl;
      final publicUrl = await SoundcloudService().getPublicStreamUrl(
        urlToStream,
      );

      if (publicUrl.isNotEmpty) {
        _downloadAndExtractWaveformInBackground(publicUrl);
      }
    } catch (e) {
      // Silent error handling for waveform loading
    }
  }

  void _showSimpleWaveform() {
    setState(() {
      _waveformData = List.generate(
        100,
        (i) => 0.2 + (0.6 * sin(i * 0.15)) + (0.2 * sin(i * 0.05)),
      );
    });
  }

  Future<void> _downloadAndSetupPlayer(String publicUrl) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/${publicUrl.hashCode}.mp3';

      final savedFilePath = await compute(
        AudioPlayerWidget.downloadAndSaveAudio,
        {'publicUrl': publicUrl, 'filePath': filePath},
      );

      // Switch the shared player to this audio source from file with background metadata
      final backgroundService = BackgroundAudioService.instance;
      await backgroundService.switchToNewAudioFromFile(
        sessionId: widget.sessionId,
        filePath: savedFilePath,
        trackTitle: widget.trackTitle,
        artistName: widget.artistName,
        artworkUrl: widget.artworkUrl,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      _extractWaveform(savedFilePath);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadAndExtractWaveformInBackground(String publicUrl) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/${publicUrl.hashCode}.mp3';

      if (!await File(filePath).exists()) {
        await compute(AudioPlayerWidget.downloadAndSaveAudio, {
          'publicUrl': publicUrl,
          'filePath': filePath,
        });
      }

      _extractWaveform(filePath);
    } catch (e) {
      // Silent error handling
    }
  }

  Future<void> _extractWaveform(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      const maxSizeForFullWaveform = 150 * 1024 * 1024;

      if (fileSize > maxSizeForFullWaveform) {
        return;
      }

      final progressStream = JustWaveform.extract(
        audioInFile: file,
        waveOutFile: File('$filePath.wave'),
        zoom: const WaveformZoom.pixelsPerSecond(5),
      );

      await progressStream.timeout(Duration(seconds: 60)).listen((progress) {
        if (progress.waveform != null && mounted) {
          setState(() {
            _waveformData = _normalizeWaveformData(
              progress.waveform!.data.map((e) => e.toDouble()).toList(),
            );
          });
        }
      }).asFuture();
    } catch (e) {
      // Silent error handling
    }
  }

  List<double> _normalizeWaveformData(List<double> data) {
    if (data.isEmpty) return [];

    final maxValue = data.map((v) => v.abs()).reduce(max);
    if (maxValue == 0) return List.filled(data.length, 0.0);

    const maxPoints = 500;
    if (data.length > maxPoints) {
      final step = data.length / maxPoints;
      final List<double> downsampled = [];
      for (int i = 0; i < maxPoints; i++) {
        final index = (i * step).round();
        if (index < data.length) {
          downsampled.add(data[index].abs() / maxValue);
        }
      }
      return downsampled;
    }

    return data.map((v) => v.abs() / maxValue).toList();
  }

  void _stopFromCoordinator() {
    if (_audioPlayer != null && _isPlaying) {
      _audioPlayer!.pause();
    }
    // Update UI state immediately when stopped by coordinator
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _hasFinished = false;
      });
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    AudioPlayerCoordinator.instance.playerStopped(this);
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    // Don't dispose the shared player here - it's managed by the service
    _controller.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_audioPlayer == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer!.pause();
      } else {
        // Request playback coordination first to stop other players
        AudioPlayerCoordinator.instance.requestPlayback(this);

        // Always switch to this audio source before playing to ensure the correct track is loaded
        final backgroundService = BackgroundAudioService.instance;

        if (!backgroundService.isSessionActive(widget.sessionId)) {
          // This session is not active, switch to our audio source

          final urlToStream = widget.audioUrl;
          final publicUrl = await SoundcloudService().getPublicStreamUrl(
            urlToStream,
          );

          if (publicUrl.isNotEmpty) {
            try {
              // Try streaming first
              await backgroundService.switchToNewAudio(
                sessionId: widget.sessionId,
                audioUrl: publicUrl,
                trackTitle: widget.trackTitle,
                artistName: widget.artistName,
                artworkUrl: widget.artworkUrl,
              );

              // Start background waveform extraction
              _downloadAndExtractWaveformInBackground(publicUrl);
            } catch (e) {
              // If streaming fails, download and try from file
              await _downloadAndSetupPlayer(publicUrl);
            }
          } else {
            throw Exception('Could not get audio URL');
          }
        }

        // Reset position if finished
        if (_hasFinished) {
          await _audioPlayer!.seek(Duration.zero);
          setState(() => _hasFinished = false);
        }

        // Start playback
        await _audioPlayer!.play();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.primalBlack,
      padding: const EdgeInsets.only(top: 4, bottom: 4, right: 4),
      child:
          _isLoading
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(
                      color: Palette.forgedGold,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await _togglePlayPause();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Palette.shadowGrey.o(0.65),
                            width: 1.65,
                          ),
                        ),
                        child: AnimatedIcon(
                          icon: AnimatedIcons.play_pause,
                          progress: _controller,
                          size: 28,
                          color: Palette.forgedGold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.66,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: CustomWaveformWidget(
                        waveformData: _waveformData,
                        progress:
                            _duration != null && _duration!.inMilliseconds > 0
                                ? _position.inMilliseconds /
                                    _duration!.inMilliseconds
                                : 0.0,
                        onSeek: (progress) async {
                          try {
                            final backgroundService =
                                BackgroundAudioService.instance;

                            // Ensure this session is active before seeking
                            if (!backgroundService.isSessionActive(
                              widget.sessionId,
                            )) {
                              // Load the audio source first
                              final urlToStream = widget.audioUrl;
                              final publicUrl = await SoundcloudService()
                                  .getPublicStreamUrl(urlToStream);

                              if (publicUrl.isNotEmpty) {
                                try {
                                  await backgroundService.switchToNewAudio(
                                    sessionId: widget.sessionId,
                                    audioUrl: publicUrl,
                                    trackTitle: widget.trackTitle,
                                    artistName: widget.artistName,
                                    artworkUrl: widget.artworkUrl,
                                  );
                                } catch (e) {
                                  // If streaming fails, try downloading
                                  try {
                                    final dir = await getTemporaryDirectory();
                                    final filePath =
                                        '${dir.path}/${publicUrl.hashCode}.mp3';
                                    final savedFilePath = await compute(
                                      AudioPlayerWidget.downloadAndSaveAudio,
                                      {
                                        'publicUrl': publicUrl,
                                        'filePath': filePath,
                                      },
                                    );
                                    await backgroundService
                                        .switchToNewAudioFromFile(
                                          sessionId: widget.sessionId,
                                          filePath: savedFilePath,
                                          trackTitle: widget.trackTitle,
                                          artistName: widget.artistName,
                                          artworkUrl: widget.artworkUrl,
                                        );
                                  } catch (downloadError) {
                                    return;
                                  }
                                }
                              }

                              // Wait for duration to be available after loading audio source
                              if (_audioPlayer != null) {
                                Duration? audioDuration =
                                    _audioPlayer!.duration;

                                // If duration is not immediately available, wait for it
                                audioDuration ??=
                                    await _audioPlayer!.durationStream.first;

                                if (audioDuration != null) {
                                  final position = Duration(
                                    milliseconds:
                                        (audioDuration.inMilliseconds *
                                                progress)
                                            .round(),
                                  );
                                  await _audioPlayer!.seek(position);

                                  // Update local position immediately after seeking
                                  if (mounted) {
                                    setState(() {
                                      _position = position;
                                      _duration = audioDuration;
                                    });
                                  }
                                } else {}
                              }
                            } else {
                              // Session is already active, seek directly
                              if (_audioPlayer != null) {
                                // Use the player's current duration if widget duration is null
                                Duration? seekDuration =
                                    _duration ?? _audioPlayer!.duration;

                                if (seekDuration != null) {
                                  final position = Duration(
                                    milliseconds:
                                        (seekDuration.inMilliseconds * progress)
                                            .round(),
                                  );

                                  await _audioPlayer!.seek(position);

                                  // Update local position immediately after seeking
                                  if (mounted) {
                                    setState(() {
                                      _position = position;
                                      _duration ??= seekDuration;
                                    });
                                  }
                                } else {
                                  // Wait for duration to become available
                                  final playerDuration =
                                      await _audioPlayer!.durationStream.first;
                                  if (playerDuration != null) {
                                    final position = Duration(
                                      milliseconds:
                                          (playerDuration.inMilliseconds *
                                                  progress)
                                              .round(),
                                    );

                                    await _audioPlayer!.seek(position);

                                    // Update local position immediately after seeking
                                    if (mounted) {
                                      setState(() {
                                        _position = position;
                                        _duration = playerDuration;
                                      });
                                    }
                                  } else {}
                                }
                              } else {}
                            }
                          } catch (_) {}
                        },
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

class CustomWaveformWidget extends StatelessWidget {
  final List<double> waveformData;
  final double progress;
  final Function(double) onSeek;

  const CustomWaveformWidget({
    super.key,
    required this.waveformData,
    required this.progress,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final progress = details.localPosition.dx / box.size.width;
        onSeek(progress.clamp(0.0, 1.0));
      },
      child: CustomPaint(
        size: Size(370, 85),
        painter: WaveformPainter(
          waveformData: waveformData,
          progress: progress,
          fixedWaveColor: Palette.gigGrey.o(0.65),
          liveWaveColor: Palette.forgedGold,
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Color fixedWaveColor;
  final Color liveWaveColor;

  WaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.fixedWaveColor,
    required this.liveWaveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) {
      _drawPlaceholderWaveform(canvas, size);
      return;
    }

    final paint =
        Paint()
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = 2.65;

    final barWidth = 3.65;
    final barSpacing = 3.65;
    final totalBars = (size.width / (barWidth + barSpacing)).floor();
    final progressBarIndex = (totalBars * progress).round();

    for (int i = 0; i < totalBars && i < waveformData.length; i++) {
      final barHeight = (waveformData[i] * size.height * 0.8).clamp(
        2.0,
        size.height,
      );
      final x = i * (barWidth + barSpacing);
      final y = (size.height - barHeight) / 2;

      paint.color = i <= progressBarIndex ? liveWaveColor : fixedWaveColor;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          Radius.circular(1),
        ),
        paint,
      );
    }
  }

  void _drawPlaceholderWaveform(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = 2.65
          ..color = fixedWaveColor;

    final barWidth = 3.65;
    final barSpacing = 3.65;
    final totalBars = (size.width / (barWidth + barSpacing)).floor();

    for (int i = 0; i < totalBars; i++) {
      final normalizedHeight = 0.3 + (0.7 * sin(i * 0.1));
      final barHeight = (normalizedHeight * size.height * 0.8).clamp(
        2.0,
        size.height,
      );
      final x = i * (barWidth + barSpacing);
      final y = (size.height - barHeight) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
