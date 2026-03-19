import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lookup/core/monitoring/activity_monitor.dart';
import 'package:lookup/core/notifications/reminder_notifier.dart';
import 'package:lookup/core/session/session_controller.dart';
import 'package:lookup/core/session/session_state.dart';
import 'package:lookup/core/settings/planner_settings.dart';
import 'package:lookup/core/settings/planner_settings_controller.dart';

void main() {
  group('SessionController', () {
    test('sends pre-break reminder and transitions into a break', () {
      final harness = SessionHarness(
        settings: _testSettings(
          workDuration: const Duration(seconds: 3),
          breakDuration: const Duration(seconds: 2),
          preBreakReminder: const Duration(seconds: 2),
        ),
      );
      addTearDown(harness.dispose);

      expect(
        harness.container.read(sessionControllerProvider).remaining,
        const Duration(seconds: 3),
      );

      harness.tick();
      expect(
        harness.container.read(sessionControllerProvider).remaining,
        const Duration(seconds: 2),
      );
      expect(harness.notifier.messages, isEmpty);

      harness.tick();
      expect(
        harness.container.read(sessionControllerProvider).remaining,
        const Duration(seconds: 1),
      );
      expect(harness.notifier.messages.first.title, 'Break coming up');

      harness.tick();
      final state = harness.container.read(sessionControllerProvider);
      expect(state.mode, SessionMode.pause);
      expect(state.remaining, const Duration(seconds: 2));
      expect(harness.notifier.messages.last.title, 'Time for a break');
    });

    test('balanced skip unlocks after the lock delay', () {
      final harness = SessionHarness(
        settings: _testSettings(skipDifficulty: SkipDifficulty.balanced),
      );
      addTearDown(harness.dispose);

      harness.container.read(sessionControllerProvider.notifier).startBreakNow();
      expect(harness.container.read(sessionControllerProvider).canSkipBreak, isFalse);

      harness.tick(const Duration(seconds: 4));
      expect(harness.container.read(sessionControllerProvider).canSkipBreak, isFalse);

      harness.tick();
      expect(harness.container.read(sessionControllerProvider).canSkipBreak, isTrue);
    });

    test('idle activity smart-pauses the timer without decrementing', () {
      final harness = SessionHarness(
        settings: _testSettings(idleThreshold: const Duration(minutes: 2)),
      );
      addTearDown(harness.dispose);

      harness.monitor.snapshot = const ActivitySnapshot(
        idleFor: Duration(minutes: 3),
        highEngagement: HighEngagementType.none,
        isFrontmost: false,
      );

      harness.tick();
      final state = harness.container.read(sessionControllerProvider);
      expect(state.smartPaused, isTrue);
      expect(state.pauseReason, PauseReason.idle);
      expect(state.remaining, harness.settings.workDuration);
    });

    test('outside office hours smart-pauses the timer', () {
      final harness = SessionHarness(
        settings: _testSettings(
          officeHours: const OfficeHours(
            enabled: true,
            activeWeekdays: {DateTime.monday},
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0),
          ),
        ),
        startTime: DateTime(2026, 3, 23, 20),
      );
      addTearDown(harness.dispose);

      harness.tick();
      final state = harness.container.read(sessionControllerProvider);
      expect(state.smartPaused, isTrue);
      expect(state.pauseReason, PauseReason.outsideOfficeHours);
      expect(state.remaining, harness.settings.workDuration);
    });
  });
}

PlannerSettings _testSettings({
  Duration workDuration = const Duration(minutes: 20),
  Duration breakDuration = const Duration(seconds: 20),
  Duration preBreakReminder = const Duration(minutes: 1),
  Duration idleThreshold = const Duration(minutes: 2),
  SkipDifficulty skipDifficulty = SkipDifficulty.balanced,
  OfficeHours? officeHours,
}) {
  return PlannerSettings.defaults.copyWith(
    workDuration: workDuration,
    breakDuration: breakDuration,
    preBreakReminder: preBreakReminder,
    idleThreshold: idleThreshold,
    skipDifficulty: skipDifficulty,
    officeHours: officeHours,
    smartPause: PlannerSettings.defaults.smartPause.copyWith(
      enableIdlePause: true,
      enableHighEngagementPause: false,
      pauseDuringMeetings: true,
      pauseDuringVideoPlayback: true,
      pauseDuringFullscreenApps: false,
      pauseDuringScreenShare: true,
      pauseDuringFocusApps: false,
    ),
  );
}

class SessionHarness {
  SessionHarness({
    required this.settings,
    DateTime? startTime,
  }) : clock = TestClock(startTime ?? DateTime(2026, 3, 23, 9)),
       monitor = FakeActivityMonitor(),
       notifier = FakeReminderNotifier() {
    container = ProviderContainer(
      overrides: [
        plannerSettingsValueProvider.overrideWith((ref) => settings),
        activityMonitorProvider.overrideWith((ref) => monitor),
        reminderNotifierProvider.overrideWith((ref) => notifier),
        currentTimeProvider.overrideWith((ref) => clock.now),
        repeatingTimerFactoryProvider.overrideWith((ref) {
          return (duration, callback) {
            timer = ManualTimer(duration, callback);
            return timer;
          };
        }),
      ],
    );

    container.read(sessionControllerProvider);
  }

  final PlannerSettings settings;
  final TestClock clock;
  final FakeActivityMonitor monitor;
  final FakeReminderNotifier notifier;
  late final ProviderContainer container;
  late final ManualTimer timer;

  void tick([Duration step = const Duration(seconds: 1)]) {
    clock.advance(step);
    timer.fire();
  }

  void dispose() {
    container.dispose();
  }
}

class TestClock {
  TestClock(this.value);

  DateTime value;

  DateTime now() => value;

  void advance(Duration duration) {
    value = value.add(duration);
  }
}

class ManualTimer implements Timer {
  ManualTimer(this.duration, this._callback);

  final Duration duration;
  final void Function(Timer timer) _callback;

  bool _isActive = true;
  int _tick = 0;

  void fire() {
    if (!_isActive) {
      return;
    }
    _tick += 1;
    _callback(this);
  }

  @override
  void cancel() {
    _isActive = false;
  }

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _tick;
}

class FakeActivityMonitor implements ActivityMonitor {
  ActivitySnapshot snapshot = const ActivitySnapshot(
    idleFor: Duration.zero,
    highEngagement: HighEngagementType.none,
    isFrontmost: true,
  );

  int interactionCount = 0;

  @override
  void dispose() {}

  @override
  ActivitySnapshot readSnapshot() => snapshot;

  @override
  void recordInteraction() {
    interactionCount += 1;
  }
}

class FakeReminderNotifier extends ReminderNotifier {
  final List<ReminderMessage> messages = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> show({required String title, required String body}) async {
    messages.add(ReminderMessage(title: title, body: body));
  }
}

class ReminderMessage {
  const ReminderMessage({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}
