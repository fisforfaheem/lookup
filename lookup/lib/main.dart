import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lookup/app/main_app.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.hide(); // Hide the main window initially
  });

  runApp(const ProviderScope(child: MainApp()));
}
