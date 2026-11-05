import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_storage.dart';
import 'data/bridge_api.dart';
import 'state/bridge_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = BridgeController(
    storage: await AppStorage.open(),
    apiFactory: HttpBridgeApi.new,
  );
  await controller.start();

  runApp(BenqBridgeApp(controller: controller));
}
