import 'package:flutter/foundation.dart';

enum SessionMode { work, pause }

enum PauseReason { user, idle, highEngagement, outsideOfficeHours }

@immutable
class SessionState {
  const SessionState({
    required this.mode,
    required this.remaining,
    required this.canSkipBreak,
    required this.userPaused,
    required this.smartPaused,
    required this.pauseReason,
  });

  final SessionMode mode;
  final Duration remaining;
  final bool canSkipBreak;
  final bool userPaused;
  final bool smartPaused;
  final PauseReason? pauseReason;

  bool get isPaused => userPaused || smartPaused;

  SessionState copyWith({
    SessionMode? mode,
    Duration? remaining,
    bool? canSkipBreak,
    bool? userPaused,
    bool? smartPaused,
    PauseReason? pauseReason,
    bool clearPauseReason = false,
  }) {
    return SessionState(
      mode: mode ?? this.mode,
      remaining: remaining ?? this.remaining,
      canSkipBreak: canSkipBreak ?? this.canSkipBreak,
      userPaused: userPaused ?? this.userPaused,
      smartPaused: smartPaused ?? this.smartPaused,
      pauseReason: clearPauseReason ? null : (pauseReason ?? this.pauseReason),
    );
  }

  String get modeLabel => mode == SessionMode.work ? 'Work' : 'Break';

  String get remainingLabel {
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get pauseReasonLabel {
    switch (pauseReason) {
      case PauseReason.user:
        return 'Paused manually';
      case PauseReason.idle:
        return 'Paused while idle';
      case PauseReason.highEngagement:
        return 'Paused for high-engagement activity';
      case PauseReason.outsideOfficeHours:
        return 'Paused outside office hours';
      case null:
        return 'Running';
    }
  }
}
