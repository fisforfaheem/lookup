import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lookup/core/settings/planner_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlannerSettingsController extends Notifier<PlannerSettings> {
  static const _workDurationMinutesKey = 'timer.work_duration_minutes';
  static const _breakDurationSecondsKey = 'timer.break_duration_seconds';
  static const _preBreakReminderMinutesKey = 'timer.pre_break_minutes';
  static const _idleThresholdMinutesKey = 'timer.idle_threshold_minutes';
  static const _idlePauseKey = 'smart_pause.idle_enabled';
  static const _highEngagementPauseKey = 'smart_pause.high_engagement_enabled';
  static const _pauseMeetingsKey = 'smart_pause.pause_meetings';
  static const _pauseVideoKey = 'smart_pause.pause_video';
  static const _pauseFullscreenKey = 'smart_pause.pause_fullscreen';
  static const _pauseScreenShareKey = 'smart_pause.pause_screen_share';
  static const _pauseFocusAppsKey = 'smart_pause.pause_focus_apps';
  static const _cooldownMinutesKey = 'smart_pause.cooldown_minutes';
  static const _videoModeKey = 'smart_pause.video_mode';
  static const _officeHoursEnabledKey = 'office_hours.enabled';
  static const _officeHoursWeekdaysKey = 'office_hours.weekdays';
  static const _officeHoursStartHourKey = 'office_hours.start_hour';
  static const _officeHoursEndHourKey = 'office_hours.end_hour';
  static const _skipDifficultyKey = 'break.skip_difficulty';

  @override
  PlannerSettings build() {
    unawaited(_loadFromStorage());
    return PlannerSettings.defaults;
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) {
      return;
    }
    final defaults = PlannerSettings.defaults;

    final workDurationMinutes = prefs.getInt(_workDurationMinutesKey);
    final breakDurationSeconds = prefs.getInt(_breakDurationSecondsKey);
    final preBreakReminderMinutes = prefs.getInt(_preBreakReminderMinutesKey);
    final idleThresholdMinutes = prefs.getInt(_idleThresholdMinutesKey);
    final idleEnabled = prefs.getBool(_idlePauseKey);
    final highEngagementEnabled = prefs.getBool(_highEngagementPauseKey);
    final pauseMeetings = prefs.getBool(_pauseMeetingsKey);
    final pauseVideo = prefs.getBool(_pauseVideoKey);
    final pauseFullscreen = prefs.getBool(_pauseFullscreenKey);
    final pauseScreenShare = prefs.getBool(_pauseScreenShareKey);
    final pauseFocusApps = prefs.getBool(_pauseFocusAppsKey);
    final cooldownMinutes = prefs.getInt(_cooldownMinutesKey);
    final videoModeRaw = prefs.getString(_videoModeKey);
    final officeHoursEnabled = prefs.getBool(_officeHoursEnabledKey);
    final officeHoursWeekdaysRaw = prefs.getStringList(_officeHoursWeekdaysKey);
    final officeStartHour = prefs.getInt(_officeHoursStartHourKey);
    final officeEndHour = prefs.getInt(_officeHoursEndHourKey);
    final skipDifficultyRaw = prefs.getString(_skipDifficultyKey);

    final videoMode =
        _parseVideoMode(videoModeRaw) ?? defaults.smartPause.videoPauseMode;
    final skipDifficulty =
        _parseSkipDifficulty(skipDifficultyRaw) ?? defaults.skipDifficulty;

    final weekdays =
        _parseWeekdays(officeHoursWeekdaysRaw) ??
        defaults.officeHours.activeWeekdays;
    final workDuration = Duration(
      minutes: workDurationMinutes ?? defaults.workDuration.inMinutes,
    );
    final preBreakReminder = _normalizePreBreakReminder(
      Duration(
        minutes:
            preBreakReminderMinutes ?? defaults.preBreakReminder.inMinutes,
      ),
      workDuration,
    );

    state = state.copyWith(
      workDuration: workDuration,
      breakDuration: Duration(
        seconds: breakDurationSeconds ?? defaults.breakDuration.inSeconds,
      ),
      preBreakReminder: preBreakReminder,
      idleThreshold: Duration(
        minutes: idleThresholdMinutes ?? defaults.idleThreshold.inMinutes,
      ),
      skipDifficulty: skipDifficulty,
      officeHours: state.officeHours.copyWith(
        enabled: officeHoursEnabled ?? defaults.officeHours.enabled,
        activeWeekdays: weekdays,
        start: TimeOfDay(
          hour: officeStartHour ?? defaults.officeHours.start.hour,
          minute: 0,
        ),
        end: TimeOfDay(
          hour: officeEndHour ?? defaults.officeHours.end.hour,
          minute: 0,
        ),
      ),
      smartPause: state.smartPause.copyWith(
        enableIdlePause: idleEnabled ?? defaults.smartPause.enableIdlePause,
        enableHighEngagementPause:
            highEngagementEnabled ??
            defaults.smartPause.enableHighEngagementPause,
        pauseDuringMeetings:
            pauseMeetings ?? defaults.smartPause.pauseDuringMeetings,
        pauseDuringVideoPlayback:
            pauseVideo ?? defaults.smartPause.pauseDuringVideoPlayback,
        pauseDuringFullscreenApps:
            pauseFullscreen ?? defaults.smartPause.pauseDuringFullscreenApps,
        pauseDuringScreenShare:
            pauseScreenShare ?? defaults.smartPause.pauseDuringScreenShare,
        pauseDuringFocusApps:
            pauseFocusApps ?? defaults.smartPause.pauseDuringFocusApps,
        cooldownAfterHighEngagement: Duration(
          minutes:
              cooldownMinutes ??
              defaults.smartPause.cooldownAfterHighEngagement.inMinutes,
        ),
        videoPauseMode: videoMode,
      ),
    );
  }

  Future<void> setWorkDurationMinutes(int minutes) async {
    final clamped = minutes.clamp(1, 180);
    final workDuration = Duration(minutes: clamped);
    final preBreakReminder = _normalizePreBreakReminder(
      state.preBreakReminder,
      workDuration,
    );

    state = state.copyWith(
      workDuration: workDuration,
      preBreakReminder: preBreakReminder,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_workDurationMinutesKey, clamped);
    await prefs.setInt(
      _preBreakReminderMinutesKey,
      preBreakReminder.inMinutes,
    );
  }

  Future<void> setBreakDurationSeconds(int seconds) async {
    final clamped = seconds.clamp(5, 300);
    state = state.copyWith(breakDuration: Duration(seconds: clamped));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_breakDurationSecondsKey, clamped);
  }

  Future<void> setPreBreakReminderMinutes(int minutes) async {
    final reminder = _normalizePreBreakReminder(
      Duration(minutes: minutes.clamp(0, 180)),
      state.workDuration,
    );

    state = state.copyWith(preBreakReminder: reminder);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_preBreakReminderMinutesKey, reminder.inMinutes);
  }

  Future<void> setIdleThresholdMinutes(int minutes) async {
    final clamped = minutes.clamp(1, 60);
    state = state.copyWith(idleThreshold: Duration(minutes: clamped));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_idleThresholdMinutesKey, clamped);
  }

  Future<void> setIdlePauseEnabled(bool enabled) async {
    state = state.copyWith(
      smartPause: state.smartPause.copyWith(enableIdlePause: enabled),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_idlePauseKey, enabled);
  }

  Future<void> setHighEngagementPauseEnabled(bool enabled) async {
    state = state.copyWith(
      smartPause: state.smartPause.copyWith(enableHighEngagementPause: enabled),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highEngagementPauseKey, enabled);
  }

  Future<void> setPauseDuringMeetings(bool enabled) async {
    state = state.copyWith(
      smartPause: state.smartPause.copyWith(pauseDuringMeetings: enabled),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pauseMeetingsKey, enabled);
  }

  Future<void> setPauseDuringVideoPlayback(bool enabled) async {
    state = state.copyWith(
      smartPause: state.smartPause.copyWith(pauseDuringVideoPlayback: enabled),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pauseVideoKey, enabled);
  }

  Future<void> setPauseDuringFullscreenApps(bool enabled) async {
    state = state.copyWith(
      smartPause: state.smartPause.copyWith(pauseDuringFullscreenApps: enabled),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pauseFullscreenKey, enabled);
  }

  Future<void> setPauseDuringScreenShare(bool enabled) async {
    state = state.copyWith(
      smartPause: state.smartPause.copyWith(pauseDuringScreenShare: enabled),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pauseScreenShareKey, enabled);
  }

  Future<void> setPauseDuringFocusApps(bool enabled) async {
    state = state.copyWith(
      smartPause: state.smartPause.copyWith(pauseDuringFocusApps: enabled),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pauseFocusAppsKey, enabled);
  }

  Future<void> setCooldownMinutes(int minutes) async {
    final clamped = minutes.clamp(0, 15);
    state = state.copyWith(
      smartPause: state.smartPause.copyWith(
        cooldownAfterHighEngagement: Duration(minutes: clamped),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cooldownMinutesKey, clamped);
  }

  Future<void> setVideoPauseMode(VideoPauseMode mode) async {
    state = state.copyWith(
      smartPause: state.smartPause.copyWith(videoPauseMode: mode),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_videoModeKey, mode.name);
  }

  Future<void> setOfficeHoursEnabled(bool enabled) async {
    state = state.copyWith(
      officeHours: state.officeHours.copyWith(enabled: enabled),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_officeHoursEnabledKey, enabled);
  }

  Future<void> setOfficeHoursStartHour(int hour) async {
    final clamped = hour.clamp(0, 23);
    state = state.copyWith(
      officeHours: state.officeHours.copyWith(
        start: TimeOfDay(hour: clamped, minute: 0),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_officeHoursStartHourKey, clamped);
  }

  Future<void> setOfficeHoursEndHour(int hour) async {
    final clamped = hour.clamp(0, 23);
    state = state.copyWith(
      officeHours: state.officeHours.copyWith(
        end: TimeOfDay(hour: clamped, minute: 0),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_officeHoursEndHourKey, clamped);
  }

  Future<void> toggleActiveWeekday(int weekday) async {
    final next = {...state.officeHours.activeWeekdays};
    if (next.contains(weekday)) {
      if (next.length == 1) {
        return;
      }
      next.remove(weekday);
    } else {
      next.add(weekday);
    }

    state = state.copyWith(
      officeHours: state.officeHours.copyWith(activeWeekdays: next),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _officeHoursWeekdaysKey,
      next.map((e) => e.toString()).toList(),
    );
  }

  Future<void> setSkipDifficulty(SkipDifficulty difficulty) async {
    state = state.copyWith(skipDifficulty: difficulty);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skipDifficultyKey, difficulty.name);
  }

  VideoPauseMode? _parseVideoMode(String? raw) {
    if (raw == null) {
      return null;
    }

    for (final mode in VideoPauseMode.values) {
      if (mode.name == raw) {
        return mode;
      }
    }

    return null;
  }

  SkipDifficulty? _parseSkipDifficulty(String? raw) {
    if (raw == null) {
      return null;
    }

    for (final difficulty in SkipDifficulty.values) {
      if (difficulty.name == raw) {
        return difficulty;
      }
    }

    return null;
  }

  Set<int>? _parseWeekdays(List<String>? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final values = raw
        .map(int.tryParse)
        .whereType<int>()
        .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
        .toSet();

    return values.isEmpty ? null : values;
  }

  Duration _normalizePreBreakReminder(
    Duration reminder,
    Duration workDuration,
  ) {
    final maxMinutes = workDuration.inMinutes > 0
        ? workDuration.inMinutes - 1
        : 0;
    final reminderMinutes = reminder.inMinutes.clamp(0, maxMinutes);
    return Duration(minutes: reminderMinutes);
  }
}

final plannerSettingsProvider =
    NotifierProvider<PlannerSettingsController, PlannerSettings>(
      PlannerSettingsController.new,
    );

final plannerSettingsValueProvider = Provider<PlannerSettings>((ref) {
  return ref.watch(plannerSettingsProvider);
});
