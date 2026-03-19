# Lookup

Lookup is a Flutter desktop break timer focused on the 20-20-20 workflow:
every 20 minutes, take a 20 second eye break and look 20 feet away.

The app runs as a tray/menu bar utility, keeps its main window hidden until
needed, and supports smart pause rules so the timer does not keep counting
during inactivity or selected high-engagement activity.

## Current MVP

- Tray/menu bar app with a hidden settings window
- Work timer, break timer, and pre-break reminder
- Manual pause/resume and start break now actions
- Break skip difficulty modes
- Office hours scheduling
- Smart pause for:
  - idle time
  - meetings/calls
  - frontmost video playback
  - OBS-style screen sharing/recording
- Persisted settings with `shared_preferences`
- Local desktop notifications

## Requirements

- Flutter 3.41.1 or newer
- Dart 3.11.0 or newer
- Full Xcode installation for macOS builds
- CocoaPods for macOS plugin integration

For macOS you need Xcode and `xcodebuild` available in your environment.
If `flutter build macos` fails with `unable to find utility "xcodebuild"`,
install Xcode and complete its first-run setup before building.

Typical macOS setup steps:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods
```

## Run Locally

```bash
flutter pub get
flutter run -d macos
```

The app starts hidden and stays in the macOS menu bar / system tray. Use the
tray icon to open settings, pause/resume the timer, start a break, or quit.

## Verify

```bash
flutter analyze
flutter test
```

## Settings Exposed In The App

- Work interval
- Break length
- Pre-break reminder lead time
- Idle threshold
- Office hours and active weekdays
- Skip difficulty
- Smart pause toggles for idle, meetings/calls, video playback, and screen capture
- Cooldown after engagement

## macOS Smart Pause Notes

The current macOS native heuristics detect:

- Zoom / Teams / Meet / Webex style meeting apps
- VLC / QuickTime / Netflix / YouTube / IINA style frontmost playback
- OBS-style screen capture apps

This MVP does not claim fullscreen-app detection or deep-focus-app detection on
macOS yet, so those controls are intentionally not exposed in the current UI.

## Project Structure

- `lib/app/` contains the main desktop shell and settings window UI
- `lib/core/session/` contains timer state and session progression
- `lib/core/settings/` contains persisted settings models and controller logic
- `lib/core/monitoring/` contains activity-monitor abstractions and platform hooks
- `lib/core/notifications/` contains local notification integration
- `macos/` and `windows/` contain native activity channel implementations

## Status

Code status after the current MVP pass:

- `flutter analyze` passes
- `flutter test` passes
- macOS build on this machine is still blocked by incomplete Xcode setup and missing CocoaPods
