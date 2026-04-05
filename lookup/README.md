# Lookup ⏱️👀

Lookup is a Flutter-based desktop application designed to help you maintain healthy computer habits using the 20-20-20 rule. Every 20 minutes, it reminds you to take a 20-second break and look at something 20 feet away. 

Built to be unobtrusive, Lookup runs quietly in your system tray or menu bar. Its smart pause features ensure it only runs when you're actually working—automatically pausing during meetings, video playback, or when you step away from your desk.

## Features

- **20-20-20 Timer**: Automated work and break intervals with pre-break reminders.
- **Smart Pause**: Automatic detection and pausing when:
  - You are idle or away from your desk.
  - You are in a meeting or call (e.g., Zoom, Teams).
  - You are watching a video (frontmost playback).
  - You are sharing or recording your screen.
- **System Tray Integration**: Stays out of your way until needed. The main window remains hidden, accessible directly from the tray.
- **Customizable Difficulty**: Adjust how easy or difficult it is to skip a break.
- **Office Hours**: Schedule the timer to only run during your active work hours.
- **Desktop Notifications**: Seamless integration with local system notifications.
- **Persistent Settings**: Your preferences are saved automatically and persist across restarts.

## Tech Stack

- **Framework**: Flutter (Desktop)
- **Language**: Dart
- **State Management**: Riverpod
- **Storage**: `shared_preferences`
- **Native Integrations**: 
  - `window_manager` for application window control
  - `tray_manager` for system tray and menu bar support
  - `local_notifier` for native system notifications

## Project Structure

- `lib/app/` - Main desktop shell and settings window UI.
- `lib/core/session/` - Timer state and session progression logic.
- `lib/core/settings/` - Persisted settings models and controller logic.
- `lib/core/monitoring/` - Activity monitor abstractions and native platform hooks.
- `lib/core/notifications/` - Local notification integration.
- `macos/` & `windows/` - Platform-specific native activity channel implementations.

## Installation

### Prerequisites

- Flutter `3.41.1` or newer
- Dart `3.11.0` or newer
- For macOS development:
  - Full Xcode installation
  - CocoaPods 

If you encounter the `unable to find utility "xcodebuild"` error when building for macOS, run the following setup steps:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods
```

## Usage

1. **Clone the repository** and navigate to the project directory (or adjust depending on your local setup):
   ```bash
   git clone https://github.com/fisforfaheem/lookup.git
   cd lookup
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the application**:
   ```bash
   flutter run -d macos
   ```
   *(Replace `macos` with `windows` if you are on a Windows machine.)*

When you launch Lookup, the main window will be hidden. Look for the Lookup icon in your system tray or menu bar. Click it to open the settings, manually pause/resume your timer, start a break immediately, or quit the application.

## Configuration

All configuration is handled directly within the app's settings window. Exposed settings include:
- Work and break intervals.
- The lead time for pre-break reminders.
- Idle time thresholds and active office hours.
- Break skip difficulty.
- Smart pause toggles for idle, meetings, media playback, and screen capture.
- Cooldown period after engagement.

## Contributing

Contributions are welcome! Please ensure that your code passes all linting rules and tests before opening a PR.

To verify your changes locally:

```bash
flutter analyze
flutter test
```

## License

This project is licensed under the MIT License - see the LICENSE file for details. (If no license exists, please ignore or update as needed).
