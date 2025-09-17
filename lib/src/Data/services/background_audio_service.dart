import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class BackgroundAudioService {
  static BackgroundAudioService? _instance;
  static BackgroundAudioService get instance =>
      _instance ??= BackgroundAudioService._();

  BackgroundAudioService._();

  static bool _isInitialized = false;
  AudioPlayer? _sharedPlayer;
  String? _currentSessionId;

  // Initialize the background service - call this in main.dart
  static Future<void> initialize() async {
    if (_isInitialized) return;

    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.gighub.audio',
      androidNotificationChannelName: 'GigHub Audio',
      androidNotificationChannelDescription: 'Audio playback for DJ tracks',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
      notificationColor: const Color(
        0xFFD4AF37,
      ), // Palette.forgedGold equivalent
    );

    _isInitialized = true;
  }

  // Get the shared audio player with background support
  AudioPlayer getSharedPlayer() {
    _sharedPlayer ??= AudioPlayer(
      audioPipeline: AudioPipeline(
        androidAudioEffects: [AndroidLoudnessEnhancer()],
      ),
    );
    return _sharedPlayer!;
  }

  // Switch to a new audio source with background metadata
  Future<void> switchToNewAudio({
    required String sessionId,
    required String audioUrl,
    required String trackTitle,
    required String artistName,
    String? artworkUrl,
  }) async {
    final player = getSharedPlayer();

    // Create audio source with background metadata
    final mediaItem = MediaItem(
      id: sessionId,
      title: trackTitle,
      artist: artistName,
      album: 'GigHub Preview',
      artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
    );

    final audioSource = AudioSource.uri(Uri.parse(audioUrl), tag: mediaItem);

    await player.setAudioSource(audioSource);
    _currentSessionId = sessionId;
  }

  // Switch to a new audio source from file with background metadata
  Future<void> switchToNewAudioFromFile({
    required String sessionId,
    required String filePath,
    required String trackTitle,
    required String artistName,
    String? artworkUrl,
  }) async {
    final player = getSharedPlayer();

    // Create audio source with background metadata
    final mediaItem = MediaItem(
      id: sessionId,
      title: trackTitle,
      artist: artistName,
      album: 'GigHub Preview',
      artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
    );

    final audioSource = AudioSource.uri(Uri.file(filePath), tag: mediaItem);

    await player.setAudioSource(audioSource);
    _currentSessionId = sessionId;
  }

  // Get current session ID
  String? get currentSessionId => _currentSessionId;

  // Check if a specific session is currently active
  bool isSessionActive(String sessionId) => _currentSessionId == sessionId;

  // Stop and dispose of the shared player
  Future<void> dispose() async {
    if (_sharedPlayer != null) {
      try {
        await _sharedPlayer!.stop();
        await _sharedPlayer!.dispose();
      } catch (e) {
        // Silent error handling
      }
      _sharedPlayer = null;
      _currentSessionId = null;
    }
  }
}
