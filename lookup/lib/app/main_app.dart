import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lookup/core/session/session_controller.dart';
import 'package:lookup/core/session/session_state.dart';
import 'package:lookup/core/settings/planner_settings.dart';
import 'package:lookup/core/settings/planner_settings_controller.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp>
    with TrayListener, WindowListener {
  ProviderSubscription<SessionState>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initDesktopShell();

    _sessionSubscription = ref.listenManual<SessionState>(
      sessionControllerProvider,
      (_, state) {
        _updateTray(state);
      },
      fireImmediately: true,
    );
  }

  Future<void> _initDesktopShell() async {
    await windowManager.setPreventClose(true);
    await _setTrayIcon();
  }

  Future<void> _setTrayIcon() async {
    final iconPath = Platform.isWindows
        ? 'assets/images/tray_icon.ico'
        : 'assets/images/tray_icon.png';

    try {
      await trayManager.setIcon(iconPath);
    } catch (_) {
      await trayManager.setIcon('assets/images/tray_icon.png');
    }
  }

  Future<void> _updateTray(SessionState state) async {
    await trayManager.setToolTip(
      'Lookup • ${state.modeLabel} ${state.remainingLabel}${state.isPaused ? ' • ${state.pauseReasonLabel}' : ''}',
    );

    final pauseLabel = state.userPaused ? 'Resume Timer' : 'Pause Timer';
    final isBreak = state.mode == SessionMode.pause;
    final breakActionKey = isBreak
        ? (state.canSkipBreak ? 'skip_break' : 'skip_locked')
        : 'start_break';
    final breakActionLabel = isBreak
        ? (state.canSkipBreak ? 'Skip Break' : 'Skip Locked')
        : 'Start Break Now';

    final menu = Menu(
      items: [
        MenuItem(key: 'show_settings', label: 'Open Settings'),
        MenuItem(key: 'toggle_pause', label: pauseLabel),
        MenuItem(key: breakActionKey, label: breakActionLabel),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Exit'),
      ],
    );

    await trayManager.setContextMenu(menu);
  }

  @override
  void dispose() {
    _sessionSubscription?.close();
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    ref.read(sessionControllerProvider.notifier).recordInteraction();
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    ref.read(sessionControllerProvider.notifier).recordInteraction();
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final controller = ref.read(sessionControllerProvider.notifier);
    controller.recordInteraction();

    switch (menuItem.key) {
      case 'show_settings':
        windowManager.show();
        windowManager.focus();
        return;
      case 'toggle_pause':
        controller.togglePause();
        return;
      case 'start_break':
        controller.startBreakNow();
        return;
      case 'skip_break':
        controller.skipBreak();
        return;
      case 'skip_locked':
        return;
      case 'exit_app':
        windowManager.destroy();
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final settings = ref.watch(plannerSettingsProvider);
    final smartPause = settings.smartPause;
    final officeHours = settings.officeHours;
    final weekdayLabels = const {
      DateTime.monday: 'M',
      DateTime.tuesday: 'T',
      DateTime.wednesday: 'W',
      DateTime.thursday: 'T',
      DateTime.friday: 'F',
      DateTime.saturday: 'S',
      DateTime.sunday: 'S',
    };
    const workDurationOptions = [5, 10, 15, 20, 25, 30, 45, 60];
    const breakDurationOptions = [10, 20, 30, 45, 60, 90, 120];
    final preBreakReminderOptions = <int>{
      0,
      1,
      2,
      3,
      5,
      10,
      15,
      settings.preBreakReminder.inMinutes,
      settings.workDuration.inMinutes - 1,
    }.where((minutes) {
      return minutes >= 0 && minutes < settings.workDuration.inMinutes;
    }).toList()
      ..sort();
    final idleThresholdOptions = <int>{
      1,
      2,
      3,
      5,
      10,
      15,
      settings.idleThreshold.inMinutes,
    }.toList()
      ..sort();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Lookup Settings'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                ref
                    .read(sessionControllerProvider.notifier)
                    .recordInteraction();
                await windowManager.hide();
              },
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 560,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${session.modeLabel} • ${session.remainingLabel}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          session.isPaused
                              ? session.pauseReasonLabel
                              : 'Running',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.tonal(
                              onPressed: () {
                                ref
                                    .read(sessionControllerProvider.notifier)
                                    .recordInteraction();
                                ref
                                    .read(sessionControllerProvider.notifier)
                                    .togglePause();
                              },
                              child: Text(
                                session.userPaused ? 'Resume' : 'Pause',
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () {
                                ref
                                    .read(sessionControllerProvider.notifier)
                                    .recordInteraction();
                                ref
                                    .read(sessionControllerProvider.notifier)
                                    .startBreakNow();
                              },
                              child: const Text('Start Break Now'),
                            ),
                            FilledButton.tonal(
                              onPressed: session.canSkipBreak
                                  ? () {
                                      ref
                                          .read(
                                            sessionControllerProvider.notifier,
                                          )
                                          .recordInteraction();
                                      ref
                                          .read(
                                            sessionControllerProvider.notifier,
                                          )
                                          .skipBreak();
                                    }
                                  : null,
                              child: Text(
                                session.canSkipBreak
                                    ? 'Skip Break'
                                    : 'Skip Locked',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Close this window to keep Lookup running in the menu bar / system tray.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white30),
                        const SizedBox(height: 10),
                        Text(
                          'Timer',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: settings.workDuration.inMinutes,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Work interval',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: [
                                  for (final minutes in workDurationOptions)
                                    DropdownMenuItem(
                                      value: minutes,
                                      child: Text('$minutes min'),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  ref
                                      .read(plannerSettingsProvider.notifier)
                                      .setWorkDurationMinutes(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: settings.breakDuration.inSeconds,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Break length',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: [
                                  for (final seconds in breakDurationOptions)
                                    DropdownMenuItem(
                                      value: seconds,
                                      child: Text('${seconds}s'),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  ref
                                      .read(plannerSettingsProvider.notifier)
                                      .setBreakDurationSeconds(value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: settings.preBreakReminder.inMinutes,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Reminder lead time',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: [
                                  for (final minutes in preBreakReminderOptions)
                                    DropdownMenuItem(
                                      value: minutes,
                                      child: Text(
                                        minutes == 0
                                            ? 'Off'
                                            : '$minutes min',
                                      ),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  ref
                                      .read(plannerSettingsProvider.notifier)
                                      .setPreBreakReminderMinutes(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: settings.idleThreshold.inMinutes,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Idle threshold',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: [
                                  for (final minutes in idleThresholdOptions)
                                    DropdownMenuItem(
                                      value: minutes,
                                      child: Text('$minutes min'),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  ref
                                      .read(plannerSettingsProvider.notifier)
                                      .setIdleThresholdMinutes(value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white30),
                        const SizedBox(height: 10),
                        Text(
                          'Office Hours',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile.adaptive(
                          dense: true,
                          value: officeHours.enabled,
                          activeThumbColor: Colors.white,
                          title: const Text(
                            'Enable office hours',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Run reminders only during selected days and hours.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          onChanged: (value) {
                            ref
                                .read(plannerSettingsProvider.notifier)
                                .setOfficeHoursEnabled(value);
                          },
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final weekday in List<int>.generate(
                              7,
                              (i) => i + 1,
                            ))
                              FilterChip(
                                selected: officeHours.activeWeekdays.contains(
                                  weekday,
                                ),
                                checkmarkColor: Colors.white,
                                selectedColor: Colors.white.withValues(
                                  alpha: 0.22,
                                ),
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.08,
                                ),
                                label: Text(
                                  weekdayLabels[weekday]!,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                onSelected: (_) {
                                  ref
                                      .read(plannerSettingsProvider.notifier)
                                      .toggleActiveWeekday(weekday);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: officeHours.start.hour,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Start hour',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: [
                                  for (var hour = 0; hour < 24; hour++)
                                    DropdownMenuItem(
                                      value: hour,
                                      child: Text(
                                        '${hour.toString().padLeft(2, '0')}:00',
                                      ),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  ref
                                      .read(plannerSettingsProvider.notifier)
                                      .setOfficeHoursStartHour(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: officeHours.end.hour,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'End hour',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.08,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: [
                                  for (var hour = 0; hour < 24; hour++)
                                    DropdownMenuItem(
                                      value: hour,
                                      child: Text(
                                        '${hour.toString().padLeft(2, '0')}:00',
                                      ),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  ref
                                      .read(plannerSettingsProvider.notifier)
                                      .setOfficeHoursEndHour(value);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Skip difficulty',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<SkipDifficulty>(
                          initialValue: settings.skipDifficulty,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: SkipDifficulty.casual,
                              child: Text('Casual (always skip)'),
                            ),
                            DropdownMenuItem(
                              value: SkipDifficulty.balanced,
                              child: Text('Balanced (brief lock before skip)'),
                            ),
                            DropdownMenuItem(
                              value: SkipDifficulty.hardcore,
                              child: Text('Hardcore (skip disabled)'),
                            ),
                          ],
                          onChanged: (difficulty) {
                            if (difficulty == null) {
                              return;
                            }
                            ref
                                .read(plannerSettingsProvider.notifier)
                                .setSkipDifficulty(difficulty);
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Smart Pause',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        SwitchListTile.adaptive(
                          dense: true,
                          value: smartPause.enableIdlePause,
                          activeThumbColor: Colors.white,
                          title: const Text(
                            'Pause when idle',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Automatically pause timer when away from keyboard/mouse.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          onChanged: (value) {
                            ref
                                .read(plannerSettingsProvider.notifier)
                                .setIdlePauseEnabled(value);
                          },
                        ),
                        SwitchListTile.adaptive(
                          dense: true,
                          value: smartPause.enableHighEngagementPause,
                          activeThumbColor: Colors.white,
                          title: const Text(
                            'Pause for high-engagement activity',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Meetings, fullscreen apps, and playback heuristics.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          onChanged: (value) {
                            ref
                                .read(plannerSettingsProvider.notifier)
                                .setHighEngagementPauseEnabled(value);
                          },
                        ),
                        SwitchListTile.adaptive(
                          dense: true,
                          value: smartPause.pauseDuringMeetings,
                          activeThumbColor: Colors.white,
                          title: const Text(
                            'Pause during meetings/calls',
                            style: TextStyle(color: Colors.white),
                          ),
                          onChanged: (value) {
                            ref
                                .read(plannerSettingsProvider.notifier)
                                .setPauseDuringMeetings(value);
                          },
                        ),
                        SwitchListTile.adaptive(
                          dense: true,
                          value: smartPause.pauseDuringVideoPlayback,
                          activeThumbColor: Colors.white,
                          title: const Text(
                            'Pause during video playback',
                            style: TextStyle(color: Colors.white),
                          ),
                          onChanged: (value) {
                            ref
                                .read(plannerSettingsProvider.notifier)
                                .setPauseDuringVideoPlayback(value);
                          },
                        ),
                        SwitchListTile.adaptive(
                          dense: true,
                          value: smartPause.pauseDuringScreenShare,
                          activeThumbColor: Colors.white,
                          title: const Text(
                            'Pause during screen sharing/recording',
                            style: TextStyle(color: Colors.white),
                          ),
                          onChanged: (value) {
                            ref
                                .read(plannerSettingsProvider.notifier)
                                .setPauseDuringScreenShare(value);
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Platform.isMacOS
                              ? 'Current macOS heuristics detect meetings/calls, frontmost video playback, and OBS-style screen capture.'
                              : 'Current heuristics prioritize meetings, video playback, and screen capture activity.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Cooldown after engagement: ${smartPause.cooldownAfterHighEngagement.inMinutes} min',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                        ),
                        Slider(
                          value: smartPause
                              .cooldownAfterHighEngagement
                              .inMinutes
                              .toDouble(),
                          min: 0,
                          max: 10,
                          divisions: 10,
                          label:
                              '${smartPause.cooldownAfterHighEngagement.inMinutes} min',
                          onChanged: (value) {
                            ref
                                .read(plannerSettingsProvider.notifier)
                                .setCooldownMinutes(value.round());
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
