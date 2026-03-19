import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HighEngagementType {
  none,
  meeting,
  videoPlayback,
  fullscreenApp,
  screenShare,
  focusApp,
}

class ActivitySnapshot {
  const ActivitySnapshot({
    required this.idleFor,
    required this.highEngagement,
    required this.isFrontmost,
  });

  final Duration idleFor;
  final HighEngagementType highEngagement;
  final bool isFrontmost;

  bool get isHighEngagement => highEngagement != HighEngagementType.none;
}

abstract class ActivityMonitor {
  ActivitySnapshot readSnapshot();

  void recordInteraction();

  void dispose();
}

class BaselineDesktopActivityMonitor implements ActivityMonitor {
  DateTime _lastInteraction = DateTime.now();

  @override
  ActivitySnapshot readSnapshot() {
    final idleFor = DateTime.now().difference(_lastInteraction);
    return ActivitySnapshot(
      idleFor: idleFor,
      highEngagement: HighEngagementType.none,
      isFrontmost: true,
    );
  }

  @override
  void recordInteraction() {
    _lastInteraction = DateTime.now();
  }

  @override
  void dispose() {}
}

class PlatformActivityMonitor implements ActivityMonitor {
  PlatformActivityMonitor()
    : _channel = const MethodChannel('lookup/activity') {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshFromPlatform();
    });
    _refreshFromPlatform();
  }

  final MethodChannel _channel;
  late final Timer _refreshTimer;

  DateTime _lastInteraction = DateTime.now();
  Duration _nativeIdle = Duration.zero;
  HighEngagementType _nativeHighEngagement = HighEngagementType.none;
  bool _nativeIsFrontmost = true;

  @override
  ActivitySnapshot readSnapshot() {
    final localIdle = DateTime.now().difference(_lastInteraction);
    final effectiveIdle = _nativeIdle > localIdle ? _nativeIdle : localIdle;
    return ActivitySnapshot(
      idleFor: effectiveIdle,
      highEngagement: _nativeHighEngagement,
      isFrontmost: _nativeIsFrontmost,
    );
  }

  Future<void> _refreshFromPlatform() async {
    try {
      final dynamic result = await _channel.invokeMethod('getActivitySnapshot');
      if (result is! Map) {
        return;
      }

      final idleMillis = result['idleMillis'];
      if (idleMillis is int) {
        _nativeIdle = Duration(milliseconds: idleMillis);
      } else if (idleMillis is num) {
        _nativeIdle = Duration(milliseconds: idleMillis.toInt());
      }

      final highEngagement = result['highEngagement'];
      if (highEngagement is String) {
        _nativeHighEngagement = _parseEngagement(highEngagement);
      }

      final isFrontmost = result['isFrontmost'];
      if (isFrontmost is bool) {
        _nativeIsFrontmost = isFrontmost;
      }
    } catch (_) {
      _nativeHighEngagement = HighEngagementType.none;
      _nativeIsFrontmost = true;
    }
  }

  HighEngagementType _parseEngagement(String raw) {
    switch (raw) {
      case 'meeting':
        return HighEngagementType.meeting;
      case 'videoPlayback':
        return HighEngagementType.videoPlayback;
      case 'fullscreenApp':
        return HighEngagementType.fullscreenApp;
      case 'screenShare':
        return HighEngagementType.screenShare;
      case 'focusApp':
        return HighEngagementType.focusApp;
      default:
        return HighEngagementType.none;
    }
  }

  @override
  void recordInteraction() {
    _lastInteraction = DateTime.now();
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
  }
}

final activityMonitorProvider = Provider<ActivityMonitor>((ref) {
  final monitor = (Platform.isMacOS || Platform.isWindows)
      ? PlatformActivityMonitor()
      : BaselineDesktopActivityMonitor();
  ref.onDispose(monitor.dispose);
  return monitor;
});
