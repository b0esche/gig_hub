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

  // Initialize the background service - call this in main.dart
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.gighub.audio',
        androidNotificationChannelName: 'GigHub Audio',
        androidNotificationChannelDescription: 'Audio playback for DJ tracks',
        androidNotificationOngoing:
            false, // Fixed: compatible with androidStopForegroundOnPause
        androidStopForegroundOnPause: true, // Stop notification when paused
        androidShowNotificationBadge: true,
        notificationColor: const Color(
          0xFFD4AF37,
        ), // Palette.forgedGold equivalent
      );

      _isInitialized = true;
      print('Background audio service initialized successfully');
    } catch (e) {
      print('Background audio service initialization failed: $e');
      // iPad fallback: Initialize without background support
      if (Platform.isIOS) {
        print('Initializing iOS fallback without background support...');
        _isInitialized = true; // Allow basic audio playback
      } else {
        _isInitialized = false;
      }
    }
  }

  // Get the shared audio player with background support
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
        // iPad-specific configuration
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
      // This ensures proper background audio on iOS/iPadOS
      // The audio session is configured through just_audio_background
    } catch (e) {
      print('iOS audio session configuration failed: $e');
    }
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
