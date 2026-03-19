import 'package:flutter/material.dart';

enum VideoPauseMode { frontmostOnly, backgroundToo }

enum SkipDifficulty { casual, balanced, hardcore }

@immutable
class SmartPauseSettings {
  const SmartPauseSettings({
    required this.enableIdlePause,
    required this.enableHighEngagementPause,
    required this.pauseDuringMeetings,
    required this.pauseDuringVideoPlayback,
    required this.pauseDuringFullscreenApps,
    required this.pauseDuringScreenShare,
    required this.pauseDuringFocusApps,
    required this.cooldownAfterHighEngagement,
    required this.videoPauseMode,
  });

  final bool enableIdlePause;
  final bool enableHighEngagementPause;
  final bool pauseDuringMeetings;
  final bool pauseDuringVideoPlayback;
  final bool pauseDuringFullscreenApps;
  final bool pauseDuringScreenShare;
  final bool pauseDuringFocusApps;
  final Duration cooldownAfterHighEngagement;
  final VideoPauseMode videoPauseMode;

  SmartPauseSettings copyWith({
    bool? enableIdlePause,
    bool? enableHighEngagementPause,
    bool? pauseDuringMeetings,
    bool? pauseDuringVideoPlayback,
    bool? pauseDuringFullscreenApps,
    bool? pauseDuringScreenShare,
    bool? pauseDuringFocusApps,
    Duration? cooldownAfterHighEngagement,
    VideoPauseMode? videoPauseMode,
  }) {
    return SmartPauseSettings(
      enableIdlePause: enableIdlePause ?? this.enableIdlePause,
      enableHighEngagementPause:
          enableHighEngagementPause ?? this.enableHighEngagementPause,
      pauseDuringMeetings: pauseDuringMeetings ?? this.pauseDuringMeetings,
      pauseDuringVideoPlayback:
          pauseDuringVideoPlayback ?? this.pauseDuringVideoPlayback,
      pauseDuringFullscreenApps:
          pauseDuringFullscreenApps ?? this.pauseDuringFullscreenApps,
      pauseDuringScreenShare:
          pauseDuringScreenShare ?? this.pauseDuringScreenShare,
      pauseDuringFocusApps: pauseDuringFocusApps ?? this.pauseDuringFocusApps,
      cooldownAfterHighEngagement:
          cooldownAfterHighEngagement ?? this.cooldownAfterHighEngagement,
      videoPauseMode: videoPauseMode ?? this.videoPauseMode,
    );
  }
}

@immutable
class OfficeHours {
  const OfficeHours({
    required this.enabled,
    required this.activeWeekdays,
    required this.start,
    required this.end,
  });

  final bool enabled;
  final Set<int> activeWeekdays;
  final TimeOfDay start;
  final TimeOfDay end;

  OfficeHours copyWith({
    bool? enabled,
    Set<int>? activeWeekdays,
    TimeOfDay? start,
    TimeOfDay? end,
  }) {
    return OfficeHours(
      enabled: enabled ?? this.enabled,
      activeWeekdays: activeWeekdays ?? this.activeWeekdays,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  bool isActiveAt(DateTime now) {
    if (!enabled) {
      return true;
    }

    if (!activeWeekdays.contains(now.weekday)) {
      return false;
    }

    final minutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return minutes >= startMinutes && minutes <= endMinutes;
  }
}

@immutable
class PlannerSettings {
  const PlannerSettings({
    required this.workDuration,
    required this.breakDuration,
    required this.preBreakReminder,
    required this.idleThreshold,
    required this.skipDifficulty,
    required this.officeHours,
    required this.smartPause,
  });

  final Duration workDuration;
  final Duration breakDuration;
  final Duration preBreakReminder;
  final Duration idleThreshold;
  final SkipDifficulty skipDifficulty;
  final OfficeHours officeHours;
  final SmartPauseSettings smartPause;

  PlannerSettings copyWith({
    Duration? workDuration,
    Duration? breakDuration,
    Duration? preBreakReminder,
    Duration? idleThreshold,
    SkipDifficulty? skipDifficulty,
    OfficeHours? officeHours,
    SmartPauseSettings? smartPause,
  }) {
    return PlannerSettings(
      workDuration: workDuration ?? this.workDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      preBreakReminder: preBreakReminder ?? this.preBreakReminder,
      idleThreshold: idleThreshold ?? this.idleThreshold,
      skipDifficulty: skipDifficulty ?? this.skipDifficulty,
      officeHours: officeHours ?? this.officeHours,
      smartPause: smartPause ?? this.smartPause,
    );
  }

  static const defaults = PlannerSettings(
    workDuration: Duration(minutes: 20),
    breakDuration: Duration(seconds: 20),
    preBreakReminder: Duration(minutes: 1),
    idleThreshold: Duration(minutes: 2),
    skipDifficulty: SkipDifficulty.balanced,
    officeHours: OfficeHours(
      enabled: false,
      activeWeekdays: {1, 2, 3, 4, 5},
      start: TimeOfDay(hour: 9, minute: 0),
      end: TimeOfDay(hour: 18, minute: 0),
    ),
    smartPause: SmartPauseSettings(
      enableIdlePause: true,
      enableHighEngagementPause: true,
      pauseDuringMeetings: true,
      pauseDuringVideoPlayback: true,
      pauseDuringFullscreenApps: true,
      pauseDuringScreenShare: true,
      pauseDuringFocusApps: true,
      cooldownAfterHighEngagement: Duration(minutes: 2),
      videoPauseMode: VideoPauseMode.frontmostOnly,
    ),
  );
}
