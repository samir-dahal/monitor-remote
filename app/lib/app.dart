import 'package:flutter/material.dart';

import 'core/bridge_scope.dart';
import 'core/theme.dart';
import 'state/bridge_controller.dart';
import 'ui/home_shell.dart';
import 'ui/pair_screen.dart';

class BenqBridgeApp extends StatelessWidget {
  const BenqBridgeApp({super.key, required this.controller, this.scannerBuilder = cameraScanner});

  final BridgeController controller;
  final ScannerBuilder scannerBuilder;

  @override
  Widget build(BuildContext context) {
    return BridgeScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          title: 'BenQ Bridge',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: controller.themeMode,
          home: controller.isPaired ? const HomeShell() : PairScreen(scannerBuilder: scannerBuilder),
        ),
      ),
    );
  }
}
