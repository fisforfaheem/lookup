import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';

class ReminderNotifier {
  bool _isReady = false;

  Future<void> initialize() async {
    if (_isReady) {
      return;
    }

    await localNotifier.setup(
      appName: 'Lookup',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );

    _isReady = true;
  }

  Future<void> show({required String title, required String body}) async {
    if (!_isReady) {
      await initialize();
    }

    final notification = LocalNotification(title: title, body: body);
    await notification.show();
  }
}

final reminderNotifierProvider = Provider<ReminderNotifier>((ref) {
  return ReminderNotifier();
});
