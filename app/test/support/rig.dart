import 'package:benq_bridge/data/app_storage.dart';
import 'package:benq_bridge/data/pairing_link.dart';
import 'package:benq_bridge/state/bridge_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

final testLink = PairingLink.tryParseQr('http://192.168.2.220:5080/#t=abc123')!;

class Rig {
  Rig(this.controller, this.api, this.storage, this.secrets);

  final BridgeController controller;
  final FakeBridgeApi api;
  final AppStorage storage;
  final MemorySecretStore secrets;
}

/// A controller wired to an in-memory PC and in-memory storage.
Future<Rig> makeRig({
  FakeBridgeApi? api,
  bool paired = true,
  AppStorage? storage,
  MemorySecretStore? secrets,
  Duration writeDelay = Duration.zero,
  bool disposeAtEnd = true,
}) async {
  final memory = secrets ?? MemorySecretStore();
  final store = storage ?? AppStorage(await _prefs(), memory);
  final pc = api ?? FakeBridgeApi([laptopPanel, sampleMonitor()]);
  pc.writeDelay = writeDelay;

  if (paired) await store.saveLink(testLink);

  final controller = BridgeController(
    storage: store,
    apiFactory: (_) => pc,
    retryBase: const Duration(milliseconds: 10),
    retryMax: const Duration(milliseconds: 20),
    writeGap: const Duration(milliseconds: 5),
    resetSettleDelay: Duration.zero,
  );
  if (disposeAtEnd) addTearDown(controller.dispose);

  await controller.start();
  return Rig(controller, pc, store, memory);
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

/// Polls in real time until [condition] holds.
Future<void> waitFor(bool Function() condition, {String reason = 'condition'}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $reason');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Future<void> settleBriefly() => Future<void>.delayed(const Duration(milliseconds: 20));
