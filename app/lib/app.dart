import 'package:flutter/material.dart';

import 'core/app_info.dart';
import 'core/bridge_scope.dart';
import 'core/theme.dart';
import 'state/bridge_controller.dart';
import 'ui/pair_screen.dart';
import 'ui/remote_screen.dart';

class MonitorRemoteApp extends StatelessWidget {
  const MonitorRemoteApp({super.key, required this.controller, this.scannerBuilder = cameraScanner});

  final BridgeController controller;
  final ScannerBuilder scannerBuilder;

  @override
  Widget build(BuildContext context) {
    return BridgeScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          title: appName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: controller.themeMode,
          home: controller.isPaired ? const RemoteScreen() : PairScreen(scannerBuilder: scannerBuilder),
        ),
      ),
    );
  }
}
