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
      if (Platform.isIOS) {
        print('Initializing iOS/iPadOS audio service...');
        try {
          await JustAudioBackground.init(
            androidNotificationChannelId: 'com.gighub.audio',
            androidNotificationChannelName: 'GigHub Audio',
            androidNotificationChannelDescription:
                'Audio playback for DJ tracks',
            androidNotificationOngoing: false,
            androidStopForegroundOnPause: true,
            androidShowNotificationBadge: true,
            notificationColor: const Color(0xFFD4AF37),
          );
          _isInitialized = true;
          print('iOS background audio service initialized successfully');
        } catch (iosError) {
          print('iOS background init failed, using basic audio: $iosError');
          _isInitialized = true;
        }
      } else {
        await JustAudioBackground.init(
          androidNotificationChannelId: 'com.gighub.audio',
          androidNotificationChannelName: 'GigHub Audio',
          androidNotificationChannelDescription: 'Audio playback for DJ tracks',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: true,
          androidShowNotificationBadge: true,
          notificationColor: const Color(0xFFD4AF37),
        );
        _isInitialized = true;
        print('Android background audio service initialized successfully');
      }
    } catch (e) {
      print('Background audio service initialization failed: $e');
      _isInitialized = true;
      print('Continuing with basic audio support only');
    }
  }

  AudioPlayer getSharedPlayer() {
    if (_sharedPlayer == null) {
      try {
        print('Creating new AudioPlayer...');
        _sharedPlayer = AudioPlayer(
          audioPipeline: AudioPipeline(
            androidAudioEffects:
                Platform.isAndroid ? [AndroidLoudnessEnhancer()] : [],
          ),
        );
        print('AudioPlayer created successfully');
        if (Platform.isIOS) {
          print('Configuring iOS audio session...');
          _configureIOSAudioSession();
        }
      } catch (e) {
        print('Error creating audio player: $e');
        // Fallback for iPad issues
        print('Creating fallback AudioPlayer...');
        _sharedPlayer = AudioPlayer();
      }
    }
    return _sharedPlayer!;
  }

  // Configure iOS audio session for background playback
  static void _configureIOSAudioSession() async {
    try {
      print('Configuring iOS audio session for iPad compatibility...');
      // iOS/iPadOS audio session configuration is handled by just_audio
      // We set the audio category to allow background playback
      // This is automatically managed by the just_audio plugin
    } catch (e) {
      print('iOS audio session configuration failed: $e');
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
          print('Using background metadata for $trackTitle');
        } catch (e) {
          print('Background metadata failed, using simple audio source: $e');
          audioSource = AudioSource.uri(Uri.parse(audioUrl));
        }
      } else {
        // Simple audio source without background metadata
        audioSource = AudioSource.uri(Uri.parse(audioUrl));
        print('Using simple audio source for $trackTitle');
      }

      await player.setAudioSource(audioSource);
      _currentSessionId = sessionId;
      print('Audio source set successfully: $trackTitle');
    } catch (e) {
      print('Error setting audio source: $e');
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
      print('Retrying audio setup for iPad...');
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
      print('Audio retry successful with simple source');
    } catch (e) {
      print('Audio retry failed: $e');
      // Final fallback: mark as failed but don't crash
      print(
        'Audio setup completely failed for iPad - will continue without audio',
      );
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
          print('Using background metadata for file: $trackTitle');
        } catch (e) {
          print('Background metadata failed for file, using simple source: $e');
          audioSource = AudioSource.uri(Uri.file(filePath));
        }
      } else {
        // Simple audio source without background metadata
        audioSource = AudioSource.uri(Uri.file(filePath));
        print('Using simple file source for $trackTitle');
      }

      await player.setAudioSource(audioSource);
      _currentSessionId = sessionId;
      print('File audio source set successfully: $trackTitle');
    } catch (e) {
      print('Error setting file audio source: $e');
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
