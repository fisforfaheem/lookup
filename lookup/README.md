# Lookup

Lookup is a simple Flutter desktop break timer. It follows the 20-20-20 rule: every 20 minutes, you take a 20-second eye break and look 20 feet away.

## Why I Built This

I needed a break timer that actually understood when I was working. Existing timers just run blindly in the background and tell you to take a break when you've been away from your desk for an hour or when you are in the middle of a Zoom call. I built Lookup to fix that by adding smart heuristics so the timer only runs when it makes sense.

## Features

- Tray/menu bar app that stays out of the way
- Work timer, break timer, and pre-break reminders
- Customizable skip difficulty for breaks
- Office hours scheduling
- Smart pause: automatically suspends the timer when idle, in a meeting, watching a video, or screen sharing
- Local desktop notifications

## Tech Stack

- Flutter (Desktop)
- Dart
- Riverpod for state management
- Shared Preferences for local storage
- Native macOS/Windows platform channels for activity monitoring

## Getting Started

You need Flutter 3.41.1+ and Dart 3.11.0+. If you are building for macOS, make sure you have a full Xcode installation and CocoaPods setup first (`sudo xcodebuild -runFirstLaunch` and `sudo gem install cocoapods`).

```bash
git clone https://github.com/fisforfaheem/lookup.git
cd lookup/lookup
flutter pub get
flutter run -d macos
```

*(Swap `macos` for `windows` if needed)*

## Project Structure

- `lib/app/`: The main application shell and settings UI
- `lib/core/session/`: Timer state and session logic
- `lib/core/settings/`: Persisted settings and controllers
- `lib/core/monitoring/`: Activity monitor and platform hooks
- `lib/core/notifications/`: Local notification handler
- `macos/` and `windows/`: Native platform activity implementations

## Usage

When you run it, the main window is hidden. Check your system tray or menu bar for the Lookup icon. From there, you can open settings, manually pause or resume the timer, or start a break immediately. 

## Notes

The macOS smart pause currently detects meeting apps (Zoom, Teams, etc.), media players (VLC, YouTube, etc.), and screen capture apps (like OBS). I haven't added fullscreen-app or deep-focus detection yet, so those toggles aren't exposed in the UI right now.

## Contributing

Feel free to open an issue or PR. Before submitting code, run `flutter analyze` and `flutter test` to make sure everything passes.

## License

MIT License
