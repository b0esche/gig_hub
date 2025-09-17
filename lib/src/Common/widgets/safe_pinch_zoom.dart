import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pinch_zoom/pinch_zoom.dart';

/// A wrapper around PinchZoom that ensures proper cleanup of overlay entries
/// to prevent stuck zoom overlays that require app restart.
class SafePinchZoom extends StatefulWidget {
  final Widget child;
  final double maxScale;
  final bool zoomEnabled;
  final VoidCallback? onZoomStart;
  final VoidCallback? onZoomEnd;

  const SafePinchZoom({
    super.key,
    required this.child,
    this.maxScale = 3.0,
    this.zoomEnabled = true,
    this.onZoomStart,
    this.onZoomEnd,
  });

  @override
  State<SafePinchZoom> createState() => _SafePinchZoomState();
}

class _SafePinchZoomState extends State<SafePinchZoom>
    with WidgetsBindingObserver {
  Timer? _cleanupTimer;
  bool _isZooming = false;
  Key _pinchZoomKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupTimer?.cancel();
    // Don't call setState in dispose - just clean up resources
    _isZooming = false;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Force cleanup when app goes to background or becomes inactive
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) &&
        mounted) {
      _safeForceCleanup();
    }
  }

  /// Safely force cleanup - only if widget is still mounted
  void _safeForceCleanup() {
    if (!mounted) return;

    _isZooming = false;
    _cleanupTimer?.cancel();

    // Recreate the PinchZoom widget to ensure clean state
    setState(() {
      _pinchZoomKey = UniqueKey();
    });
  }

  void _handleZoomStart() {
    if (!mounted) return;

    _isZooming = true;
    widget.onZoomStart?.call();

    // Set a maximum zoom duration as a safety net
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer(const Duration(seconds: 10), () {
      if (_isZooming && mounted) {
        _safeForceCleanup();
      }
    });
  }

  void _handleZoomEnd() {
    if (!mounted) return;

    _isZooming = false;
    _cleanupTimer?.cancel();
    widget.onZoomEnd?.call();

    // Schedule a delayed check to ensure cleanup happened
    Timer(const Duration(milliseconds: 100), () {
      if (mounted && !_isZooming) {
        // Additional safety: recreate the widget to ensure clean state
        setState(() {
          _pinchZoomKey = UniqueKey();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Add tap detection to help with cleanup
      onTap: () {
        if (_isZooming && mounted) {
          _safeForceCleanup();
        }
      },
      // Double tap to force cleanup as emergency exit
      onDoubleTap: () {
        if (mounted) {
          _safeForceCleanup();
        }
      },
      child: PinchZoom(
        key: _pinchZoomKey,
        maxScale: widget.maxScale,
        zoomEnabled: widget.zoomEnabled,
        onZoomStart: _handleZoomStart,
        onZoomEnd: _handleZoomEnd,
        child: widget.child,
      ),
    );
  }
}
