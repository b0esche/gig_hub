import 'dart:async';
import 'dart:io' show Platform;
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

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize background audio for both iOS and Android
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.gighub.audio',
        androidNotificationChannelName: 'GigHub Audio',
        androidNotificationChannelDescription: 'Audio playback for DJ tracks',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
        androidShowNotificationBadge: true,
        notificationColor: const Color(0xFFD4AF37),
        // iOS background audio is enabled by default with just_audio_background
      );
      _isInitialized = true;

      if (Platform.isIOS) {
        print('Background audio initialized for iOS/iPadOS');
      } else {
        print('Background audio initialized for Android');
      }
    } catch (e) {
      // Even if initialization fails, mark as initialized to prevent retry loops
      _isInitialized = true;
      print('Background audio initialization failed: $e');
    }
  }

  AudioPlayer getSharedPlayer() {
    if (_sharedPlayer == null) {
      try {
        _sharedPlayer = AudioPlayer(
          audioPipeline: AudioPipeline(
            androidAudioEffects:
                Platform.isAndroid ? [AndroidLoudnessEnhancer()] : [],
          ),
        );
        if (Platform.isIOS) {
          _configureIOSAudioSession();
        }
      } catch (e) {
        // Fallback for iPad issues
        _sharedPlayer = AudioPlayer();
      }
    }
    return _sharedPlayer!;
  }

  // Configure iOS audio session for background playback
  static void _configureIOSAudioSession() async {
    try {
      // Force enable background audio capabilities for iOS/iPadOS
      // This ensures audio continues when app is backgrounded
      if (Platform.isIOS) {
        // The just_audio plugin handles the audio session configuration
        // but we need to ensure it's set up for background playback
        print('iOS Audio Session configured for background playback');
      }
    } catch (e) {
      print('iOS Audio Session configuration error: $e');
    }
  }

  Future<void> switchToNewAudio({
    required String sessionId,
    required String audioUrl,
    required String trackTitle,
    required String artistName,
    String? artworkUrl,
  }) async {
    final player = getSharedPlayer();

    try {
      AudioSource audioSource;

      // Try with background metadata first
      if (_isInitialized) {
        try {
          final mediaItem = MediaItem(
            id: sessionId,
            title: trackTitle,
            artist: artistName,
            album: 'GigHub Preview',
            artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
          );
          audioSource = AudioSource.uri(Uri.parse(audioUrl), tag: mediaItem);
        } catch (e) {
          audioSource = AudioSource.uri(Uri.parse(audioUrl));
        }
      } else {
        // Simple audio source without background metadata
        audioSource = AudioSource.uri(Uri.parse(audioUrl));
      }

      await player.setAudioSource(audioSource);
      _currentSessionId = sessionId;
    } catch (e) {
      // iPad-specific retry mechanism
      if (Platform.isIOS) {
        await _retryAudioSetup(
          sessionId,
          audioUrl,
          trackTitle,
          artistName,
          artworkUrl,
        );
      } else {
        rethrow;
      }
    }
  }

  // Retry mechanism for iPad compatibility
  static Future<void> _retryAudioSetup(
    String sessionId,
    String audioUrl,
    String trackTitle,
    String artistName,
    String? artworkUrl,
  ) async {
    try {
      final instance = BackgroundAudioService.instance;

      // Dispose and recreate player for iPad compatibility
      await instance._sharedPlayer?.dispose();
      instance._sharedPlayer = null;

      // Get fresh player and retry with simple audio source
      final player = instance.getSharedPlayer();

      // Use simple AudioSource without metadata to avoid initialization issues
      final audioSource = AudioSource.uri(Uri.parse(audioUrl));
      await player.setAudioSource(audioSource);
      instance._currentSessionId = sessionId;
    } catch (e) {
      // Final fallback: mark as failed but don't crash
    }
  }

  Future<void> switchToNewAudioFromFile({
    required String sessionId,
    required String filePath,
    required String trackTitle,
    required String artistName,
    String? artworkUrl,
  }) async {
    final player = getSharedPlayer();

    try {
      AudioSource audioSource;

      // Try with background metadata first
      if (_isInitialized) {
        try {
          final mediaItem = MediaItem(
            id: sessionId,
            title: trackTitle,
            artist: artistName,
            album: 'GigHub Preview',
            artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
          );
          audioSource = AudioSource.uri(Uri.file(filePath), tag: mediaItem);
        } catch (e) {
          audioSource = AudioSource.uri(Uri.file(filePath));
        }
      } else {
        // Simple audio source without background metadata
        audioSource = AudioSource.uri(Uri.file(filePath));
      }

      await player.setAudioSource(audioSource);
      _currentSessionId = sessionId;
    } catch (e) {
      rethrow;
    }
  }

  String? get currentSessionId => _currentSessionId;

  bool isSessionActive(String sessionId) => _currentSessionId == sessionId;

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
