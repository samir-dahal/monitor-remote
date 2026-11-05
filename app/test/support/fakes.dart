import 'dart:async';

import 'package:benq_bridge/data/app_storage.dart';
import 'package:benq_bridge/data/bridge_api.dart';
import 'package:benq_bridge/data/models.dart';

class MemorySecretStore implements SecretStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

typedef Write = ({String monitorId, int code, int value});

/// A PC that lives in memory. Tests drive it: change what it reports, push updates,
/// drop the connection, or make it fail.
class FakeBridgeApi implements BridgeApi {
  FakeBridgeApi(this.reported);

  List<Monitor> reported;
  final List<Write> writes = [];
  int refreshes = 0;
  int closes = 0;
  int monitorsCalls = 0;

  /// Thrown by the next calls to [monitors] while set.
  BridgeException? monitorsError;

  /// Thrown by [writeVcp] while set.
  BridgeException? writeError;

  /// How long each write takes, so tests can queue several behind one.
  Duration writeDelay = Duration.zero;

  StreamController<List<Monitor>> _push = StreamController<List<Monitor>>.broadcast();

  @override
  Future<List<Monitor>> monitors() async {
    monitorsCalls++;
    final error = monitorsError;
    if (error != null) throw error;
    return reported;
  }

  @override
  Future<void> writeVcp(String monitorId, int code, int value) async {
    if (writeDelay > Duration.zero) await Future<void>.delayed(writeDelay);
    final error = writeError;
    if (error != null) throw error;
    writes.add((monitorId: monitorId, code: code, value: value));
  }

  @override
  Future<void> refresh(String monitorId) async => refreshes++;

  @override
  Stream<List<Monitor>> watch() => _push.stream;

  /// The PC announces a change.
  void push(List<Monitor> monitors) {
    reported = monitors;
    _push.add(monitors);
  }

  /// The connection drops: the live stream ends.
  Future<void> dropConnection() async {
    final old = _push;
    _push = StreamController<List<Monitor>>.broadcast();
    await old.close();
  }

  @override
  void close() => closes++;
}

/// A monitor shaped like the BenQ GW2490 the app was developed against.
Monitor sampleMonitor({int brightness = 25, int pictureMode = 0, int blueLight = 1, int input = 17}) => Monitor(
      id: 'DISPLAY4',
      name: 'BenQ GW2490',
      model: 'GW2490',
      supported: true,
      ddcChannel: true,
      features: [
        Feature(
          code: VcpCodes.brightness,
          name: 'Brightness',
          category: 'Picture',
          kind: FeatureKind.continuous,
          writable: true,
          max: 100,
          unit: '%',
          value: brightness,
        ),
        Feature(
          code: VcpCodes.pictureMode,
          name: 'Picture Mode',
          category: 'Picture',
          kind: FeatureKind.discrete,
          writable: true,
          max: 50,
          value: pictureMode,
          options: const [
            VcpOption(value: 0, label: 'Standard'),
            VcpOption(value: 15, label: '0x0F'),
            VcpOption(value: 40, label: 'Game'),
            VcpOption(value: 50, label: 'Cinema'),
          ],
        ),
        Feature(
          code: VcpCodes.lowBlueLight,
          name: 'Low Blue Light',
          category: 'Eye Care',
          kind: FeatureKind.discrete,
          writable: true,
          max: 5,
          value: blueLight,
          options: [for (var i = 0; i <= 5; i++) VcpOption(value: i, label: i == 0 ? 'Off' : 'Level $i')],
        ),
        Feature(
          code: VcpCodes.inputSource,
          name: 'Input Source',
          category: 'Input',
          kind: FeatureKind.discrete,
          writable: true,
          max: 18,
          value: input,
          options: const [
            VcpOption(value: 15, label: 'DisplayPort'),
            VcpOption(value: 17, label: 'HDMI-1'),
            VcpOption(value: 18, label: 'HDMI-2'),
          ],
        ),
        const Feature(
          code: VcpCodes.restoreFactoryDefaults,
          name: 'Restore Factory Defaults',
          category: 'System',
          kind: FeatureKind.action,
          writable: true,
          max: 0,
        ),
      ],
    );

/// The laptop panel: enumerated, but with no DDC/CI to talk to.
const laptopPanel = Monitor(
  id: 'DISPLAY1',
  name: 'Generic PnP Monitor',
  model: 'Generic PnP Monitor',
  supported: false,
  ddcChannel: true,
  features: [],
);
