import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lookup/core/monitoring/activity_monitor.dart';
import 'package:lookup/core/notifications/reminder_notifier.dart';
import 'package:lookup/core/session/session_state.dart';
import 'package:lookup/core/settings/planner_settings.dart';
import 'package:lookup/core/settings/planner_settings_controller.dart';

typedef RepeatingTimerFactory = Timer Function(
  Duration duration,
  void Function(Timer timer) callback,
);

class SessionController extends Notifier<SessionState> {
  static const _balancedSkipDelay = Duration(seconds: 5);

  Timer? _timer;
  bool _preBreakReminderSent = false;
  bool _wasHighEngagementActive = false;
  DateTime? _highEngagementEndedAt;
  DateTime? _breakStartedAt;

  PlannerSettings get _settings => ref.read(plannerSettingsValueProvider);

  ActivityMonitor get _monitor => ref.read(activityMonitorProvider);

  ReminderNotifier get _notifier => ref.read(reminderNotifierProvider);

  DateTime get _now => ref.read(currentTimeProvider)();

  @override
  SessionState build() {
    _startTicker();
    ref.onDispose(() {
      _timer?.cancel();
    });

    return SessionState(
      mode: SessionMode.work,
      remaining: _settings.workDuration,
      canSkipBreak: true,
      userPaused: false,
      smartPaused: false,
      pauseReason: null,
    );
  }

  void _startTicker() {
    _timer ??= ref.read(repeatingTimerFactoryProvider)(
      const Duration(seconds: 1),
      (_) {
        _updateSkipAvailability();
        _evaluateSmartPause();

        if (state.isPaused) {
          return;
        }

        _maybeSendPreBreakReminder();

        if (state.remaining > const Duration(seconds: 1)) {
          state = state.copyWith(
            remaining: state.remaining - const Duration(seconds: 1),
          );
          return;
        }

        _advanceSession();
      },
    );
  }

  void _updateSkipAvailability() {
    if (state.mode != SessionMode.pause) {
      if (!state.canSkipBreak) {
        state = state.copyWith(canSkipBreak: true);
      }
      return;
    }

    final canSkip = _canSkipCurrentBreak();
    if (canSkip != state.canSkipBreak) {
      state = state.copyWith(canSkipBreak: canSkip);
    }
  }

  bool _canSkipCurrentBreak() {
    switch (_settings.skipDifficulty) {
      case SkipDifficulty.casual:
        return true;
      case SkipDifficulty.balanced:
        if (_breakStartedAt == null) {
          return false;
        }
        return _now.difference(_breakStartedAt!) >= _balancedSkipDelay;
      case SkipDifficulty.hardcore:
        return false;
    }
  }

  void _evaluateSmartPause() {
    final now = _now;
    final inOfficeHours = _settings.officeHours.isActiveAt(now);

    if (!inOfficeHours) {
      state = state.copyWith(
        smartPaused: true,
        pauseReason: PauseReason.outsideOfficeHours,
      );
      return;
    }

    final snapshot = _monitor.readSnapshot();

    if (snapshot.isHighEngagement) {
      _wasHighEngagementActive = true;
      _highEngagementEndedAt = null;
    } else if (_wasHighEngagementActive) {
      _wasHighEngagementActive = false;
      _highEngagementEndedAt = now;
    }

    if (_settings.smartPause.enableIdlePause &&
        snapshot.idleFor >= _settings.idleThreshold) {
      state = state.copyWith(smartPaused: true, pauseReason: PauseReason.idle);
      return;
    }

    final shouldPauseForEngagement =
        _settings.smartPause.enableHighEngagementPause &&
        _shouldPauseForEngagement(snapshot);

    if (shouldPauseForEngagement) {
      state = state.copyWith(
        smartPaused: true,
        pauseReason: PauseReason.highEngagement,
      );
      return;
    }

    final cooldown = _settings.smartPause.cooldownAfterHighEngagement;
    if (_settings.smartPause.enableHighEngagementPause &&
        _highEngagementEndedAt != null &&
        now.difference(_highEngagementEndedAt!) < cooldown) {
      state = state.copyWith(
        smartPaused: true,
        pauseReason: PauseReason.highEngagement,
      );
      return;
    }

    state = state.copyWith(
      smartPaused: false,
      clearPauseReason: !state.userPaused,
    );
  }

  bool _shouldPauseForEngagement(ActivitySnapshot snapshot) {
    switch (snapshot.highEngagement) {
      case HighEngagementType.none:
        return false;
      case HighEngagementType.meeting:
        return _settings.smartPause.pauseDuringMeetings;
      case HighEngagementType.videoPlayback:
        final videoAllowed = _settings.smartPause.pauseDuringVideoPlayback;
        if (!videoAllowed) {
          return false;
        }
        return _settings.smartPause.videoPauseMode ==
                VideoPauseMode.backgroundToo
            ? true
            : snapshot.isFrontmost;
      case HighEngagementType.fullscreenApp:
        return _settings.smartPause.pauseDuringFullscreenApps;
      case HighEngagementType.screenShare:
        return _settings.smartPause.pauseDuringScreenShare;
      case HighEngagementType.focusApp:
        return _settings.smartPause.pauseDuringFocusApps;
    }
  }

  void _maybeSendPreBreakReminder() {
    if (state.mode != SessionMode.work) {
      return;
    }

    if (_preBreakReminderSent) {
      return;
    }

    final preBreak = _settings.preBreakReminder;
    if (preBreak > Duration.zero && state.remaining == preBreak) {
      _preBreakReminderSent = true;
      unawaited(
        _notifier.show(
          title: 'Break coming up',
          body: 'Wrap up this task. Your eye break starts soon.',
        ),
      );
    }
  }

  void _advanceSession() {
    if (state.mode == SessionMode.work) {
      _preBreakReminderSent = false;
      _breakStartedAt = _now;
      state = state.copyWith(
        mode: SessionMode.pause,
        remaining: _settings.breakDuration,
        canSkipBreak: _canSkipCurrentBreak(),
        clearPauseReason: !state.userPaused,
      );
      unawaited(
        _notifier.show(
          title: 'Time for a break',
          body: 'Look 20 feet away for 20 seconds.',
        ),
      );
      return;
    }

    _breakStartedAt = null;
    state = state.copyWith(
      mode: SessionMode.work,
      remaining: _settings.workDuration,
      canSkipBreak: true,
      clearPauseReason: !state.userPaused,
    );
    unawaited(
      _notifier.show(
        title: 'Break complete',
        body: 'Back to focus. The next break timer has started.',
      ),
    );
  }

  void togglePause() {
    final nextUserPaused = !state.userPaused;
    state = state.copyWith(
      userPaused: nextUserPaused,
      pauseReason: nextUserPaused ? PauseReason.user : state.pauseReason,
      clearPauseReason: !nextUserPaused && !state.smartPaused,
    );
  }

  void startBreakNow() {
    _preBreakReminderSent = false;
    _breakStartedAt = _now;
    state = state.copyWith(
      mode: SessionMode.pause,
      remaining: _settings.breakDuration,
      canSkipBreak: _canSkipCurrentBreak(),
      clearPauseReason: !state.userPaused,
    );
    unawaited(
      _notifier.show(
        title: 'Break started',
        body: 'Step away briefly to reduce eye strain.',
      ),
    );
  }

  void skipBreak() {
    if (state.mode == SessionMode.pause && !state.canSkipBreak) {
      return;
    }

    _preBreakReminderSent = false;
    _breakStartedAt = null;
    state = state.copyWith(
      mode: SessionMode.work,
      remaining: _settings.workDuration,
      canSkipBreak: true,
      clearPauseReason: !state.userPaused,
    );
  }

  void recordInteraction() {
    _monitor.recordInteraction();
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

final currentTimeProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final repeatingTimerFactoryProvider = Provider<RepeatingTimerFactory>((ref) {
  return (duration, callback) => Timer.periodic(duration, callback);
});
