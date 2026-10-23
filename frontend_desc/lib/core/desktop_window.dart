import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:window_manager/window_manager.dart';

/// Opens Windows app maximized and disables restore/resize controls.
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
    await windowManager.setResizable(false);
    await windowManager.setMaximizable(false);
    await windowManager.setMinimumSize(const Size(1280, 720));
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  });
}
