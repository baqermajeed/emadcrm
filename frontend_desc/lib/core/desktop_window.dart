import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';

/// Opens Windows app maximized with responsive resize behavior.
Future<void> setupDesktopWindow() async {
  if (kIsWeb || !Platform.isWindows) return;

  await windowManager.ensureInitialized();

  const options = WindowOptions(
    center: true,
    skipTaskbar: false,
    title: 'Emad CRM',
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    // Keep desktop controls available so the UI can adapt to user display.
    await windowManager.setResizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.setMinimumSize(const Size(1024, 640));
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  });
}
