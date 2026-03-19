import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lookup/core/settings/planner_settings.dart';
import 'package:lookup/core/settings/planner_settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads persisted timer settings from shared preferences', () async {
    SharedPreferences.setMockInitialValues({
      'timer.work_duration_minutes': 30,
      'timer.break_duration_seconds': 45,
      'timer.pre_break_minutes': 5,
      'timer.idle_threshold_minutes': 3,
      'break.skip_difficulty': SkipDifficulty.hardcore.name,
      'office_hours.enabled': true,
      'office_hours.weekdays': ['1', '2', '3'],
      'office_hours.start_hour': 8,
      'office_hours.end_hour': 17,
      'smart_pause.idle_enabled': true,
      'smart_pause.high_engagement_enabled': true,
      'smart_pause.pause_meetings': true,
      'smart_pause.pause_video': false,
      'smart_pause.pause_screen_share': true,
      'smart_pause.cooldown_minutes': 4,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(plannerSettingsProvider);
    await _settleAsyncState();

    final settings = container.read(plannerSettingsProvider);
    expect(settings.workDuration, const Duration(minutes: 30));
    expect(settings.breakDuration, const Duration(seconds: 45));
    expect(settings.preBreakReminder, const Duration(minutes: 5));
    expect(settings.idleThreshold, const Duration(minutes: 3));
    expect(settings.skipDifficulty, SkipDifficulty.hardcore);
    expect(settings.officeHours.enabled, isTrue);
    expect(settings.officeHours.activeWeekdays, {1, 2, 3});
    expect(settings.officeHours.start.hour, 8);
    expect(settings.officeHours.end.hour, 17);
    expect(settings.smartPause.pauseDuringVideoPlayback, isFalse);
    expect(
      settings.smartPause.cooldownAfterHighEngagement,
      const Duration(minutes: 4),
    );
  });

  test('work duration update also clamps and persists pre-break reminder', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(plannerSettingsProvider);
    await _settleAsyncState();

    final controller = container.read(plannerSettingsProvider.notifier);
    await controller.setPreBreakReminderMinutes(10);
    await controller.setWorkDurationMinutes(5);

    final settings = container.read(plannerSettingsProvider);
    final prefs = await SharedPreferences.getInstance();

    expect(settings.workDuration, const Duration(minutes: 5));
    expect(settings.preBreakReminder, const Duration(minutes: 4));
    expect(prefs.getInt('timer.work_duration_minutes'), 5);
    expect(prefs.getInt('timer.pre_break_minutes'), 4);
  });

  test('break duration and idle threshold updates persist immediately', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(plannerSettingsProvider);
    await _settleAsyncState();

    final controller = container.read(plannerSettingsProvider.notifier);
    await controller.setBreakDurationSeconds(60);
    await controller.setIdleThresholdMinutes(10);

    final settings = container.read(plannerSettingsProvider);
    final prefs = await SharedPreferences.getInstance();

    expect(settings.breakDuration, const Duration(seconds: 60));
    expect(settings.idleThreshold, const Duration(minutes: 10));
    expect(prefs.getInt('timer.break_duration_seconds'), 60);
    expect(prefs.getInt('timer.idle_threshold_minutes'), 10);
  });
}

Future<void> _settleAsyncState() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
