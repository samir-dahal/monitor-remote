import 'package:monitor_remote/data/bridge_api.dart';
import 'package:monitor_remote/data/models.dart';
import 'package:monitor_remote/state/bridge_controller.dart';
import 'package:monitor_remote/state/scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/rig.dart';

void main() {
  group('connecting', () {
    test('a fresh install is unpaired', () async {
      final rig = await makeRig(paired: false);

      expect(rig.controller.isPaired, isFalse);
      expect(rig.controller.linkState, LinkState.unpaired);
    });

    test('a saved PC connects on start and goes live', () async {
      final rig = await makeRig();

      await waitFor(() => rig.controller.linkState == LinkState.live, reason: 'live');

      expect(rig.controller.monitor!.name, 'BenQ GW2490');
    });

    test('the monitor on screen is the first one that answered, not the laptop panel', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);

      expect(rig.controller.usableMonitors.map((m) => m.id), ['DISPLAY4']);
      expect(rig.controller.monitor!.id, 'DISPLAY4');
    });

    test('pairing checks the PC, remembers the link and goes live', () async {
      final rig = await makeRig(paired: false);

      await rig.controller.pair(testLink);
      await waitFor(() => rig.controller.linkState == LinkState.live, reason: 'live after pairing');

      expect(rig.controller.link, testLink);
      expect(await rig.storage.loadLink(), testLink);
    });

    test('the token goes to the secret store, not the preferences', () async {
      final rig = await makeRig(paired: false);

      await rig.controller.pair(testLink);

      expect(rig.secrets.data.values, contains('abc123'));
    });

    test('pairing with a rejected token fails and saves nothing', () async {
      final api = FakeBridgeApi([sampleMonitor()])
        ..monitorsError = const BridgeException('rejected', unauthorized: true);
      final rig = await makeRig(api: api, paired: false);

      await expectLater(rig.controller.pair(testLink), throwsA(isA<BridgeException>()));

      expect(rig.controller.isPaired, isFalse);
      expect(await rig.storage.loadLink(), isNull);
    });

    test('unpairing forgets the PC', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);

      await rig.controller.unpair();

      expect(rig.controller.linkState, LinkState.unpaired);
      expect(rig.controller.monitors, isEmpty);
      expect(await rig.storage.loadLink(), isNull);
    });

    test('a PC that cannot be reached shows offline, then recovers by itself', () async {
      final api = FakeBridgeApi([sampleMonitor()])..monitorsError = const BridgeException('down');
      final rig = await makeRig(api: api);

      await waitFor(() => rig.controller.linkState == LinkState.offline, reason: 'offline');

      api.monitorsError = null;
      await waitFor(() => rig.controller.linkState == LinkState.live, reason: 'recovery');
    });

    test('a dropped connection is noticed and reopened', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);
      final callsBefore = rig.api.monitorsCalls;

      await rig.api.dropConnection();

      await waitFor(() => rig.api.monitorsCalls > callsBefore, reason: 'reconnect attempt');
      await waitFor(() => rig.controller.linkState == LinkState.live, reason: 'live again');
    });

    test('a rejected token stops the retrying and asks to pair again', () async {
      final api = FakeBridgeApi([sampleMonitor()])..monitorsError = const BridgeException('no', unauthorized: true);
      final rig = await makeRig(api: api);

      await waitFor(() => rig.controller.linkState == LinkState.unauthorized, reason: 'unauthorized');
      final calls = api.monitorsCalls;
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(api.monitorsCalls, calls, reason: 'retrying with a bad token cannot help');
    });

    test('updates pushed by the PC reach the screen', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);

      rig.api.push([sampleMonitor(brightness: 77)]);

      await waitFor(() => rig.controller.monitor!.valueOf(VcpCodes.brightness) == 77, reason: 'pushed value');
    });
  });

  group('writing', () {
    test('a change shows immediately and is sent to the monitor', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);

      rig.controller.setValue(VcpCodes.brightness, 60);

      expect(rig.controller.monitor!.valueOf(VcpCodes.brightness), 60, reason: 'optimistic');
      await rig.controller.settle();
      expect(rig.api.writes.single, (monitorId: 'DISPLAY4', code: VcpCodes.brightness, value: 60));
    });

    test('rapid changes collapse to the newest value, in order', () async {
      final rig = await makeRig(writeDelay: const Duration(milliseconds: 30));
      await waitFor(() => rig.controller.linkState == LinkState.live);

      for (var value = 30; value <= 40; value++) {
        rig.controller.setValue(VcpCodes.brightness, value);
      }
      await rig.controller.settle();

      expect(rig.api.writes.last.value, 40);
      expect(rig.api.writes.length, lessThan(5), reason: 'not one request per step');
    });

    test('an update from the PC does not undo a change that is still being sent', () async {
      final rig = await makeRig(writeDelay: const Duration(milliseconds: 40));
      await waitFor(() => rig.controller.linkState == LinkState.live);

      rig.controller.setValue(VcpCodes.brightness, 50);
      rig.api.push([sampleMonitor(brightness: 25)]);
      await settleBriefly();

      expect(rig.controller.monitor!.valueOf(VcpCodes.brightness), 50);

      await rig.controller.settle();
      rig.api.push([sampleMonitor(brightness: 41)]);
      await waitFor(() => rig.controller.monitor!.valueOf(VcpCodes.brightness) == 41, reason: 'PC value after sending');
    });

    test('an update does not move a control that is being dragged', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);

      rig.controller.beginEdit(VcpCodes.brightness);
      rig.controller.setValue(VcpCodes.brightness, 70);
      await rig.controller.settle();
      rig.api.push([sampleMonitor(brightness: 10)]);
      await settleBriefly();

      expect(rig.controller.monitor!.valueOf(VcpCodes.brightness), 70);

      rig.controller.endEdit(VcpCodes.brightness);
      rig.api.push([sampleMonitor(brightness: 10)]);
      await waitFor(
        () => rig.controller.monitor!.valueOf(VcpCodes.brightness) == 10,
        reason: 'released control follows the PC',
      );
    });

    test('a failed write says so and goes back to what the monitor really has', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);
      final notices = <String>[];
      rig.controller.messages.listen(notices.add);

      rig.api.writeError = const BridgeException("Your PC didn't answer.");
      rig.controller.setValue(VcpCodes.brightness, 90);

      await waitFor(() => rig.controller.monitor!.valueOf(VcpCodes.brightness) == 25, reason: 'revert');
      expect(notices, contains("Your PC didn't answer."));
    });

    test('a rejected token during a write asks to pair again', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);

      rig.api.writeError = const BridgeException('no', unauthorized: true);
      rig.controller.setValue(VcpCodes.brightness, 90);

      await waitFor(() => rig.controller.linkState == LinkState.unauthorized, reason: 'unauthorized');
    });

    test('reset commands send 1, then re-read the monitor', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);

      await rig.controller.runAction(VcpCodes.restoreFactoryDefaults);

      expect(rig.api.writes.single, (monitorId: 'DISPLAY4', code: VcpCodes.restoreFactoryDefaults, value: 1));
      expect(rig.api.refreshes, 1);
    });
  });

  group('scenes', () {
    test('applying a scene writes only what the monitor supports', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);
      final notices = <String>[];
      rig.controller.messages.listen(notices.add);

      final night = rig.controller.scenes.firstWhere((s) => s.name == 'Night');
      final changed = rig.controller.applyScene(night);
      await rig.controller.settle();

      expect(changed, 2);
      expect({for (final w in rig.api.writes) w.code: w.value}, {VcpCodes.brightness: 12, VcpCodes.lowBlueLight: 4});
      await settleBriefly();
      expect(notices, contains('Night applied'));
    });

    test('a scene the monitor cannot use changes nothing and says so', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);
      final notices = <String>[];
      rig.controller.messages.listen(notices.add);

      const unusable = Scene(id: 'x', name: 'Contrast only', icon: 'sun', values: {VcpCodes.contrast: 10});

      expect(rig.controller.applyScene(unusable), 0);
      await settleBriefly();
      expect(rig.api.writes, isEmpty);
      expect(notices.single, contains("can't use"));
    });

    test('new, edited and deleted scenes are remembered', () async {
      final rig = await makeRig();
      const reading = Scene(id: 'r', name: 'Reading', icon: 'book', values: {VcpCodes.brightness: 20});

      await rig.controller.saveScene(reading);
      await rig.controller.saveScene(reading.copyWith(name: 'Late reading'));
      await rig.controller.deleteScene('starter-work');

      final reopened = await makeRig(storage: rig.storage, paired: false);
      final names = reopened.controller.scenes.map((s) => s.name);

      expect(names, contains('Late reading'));
      expect(names, isNot(contains('Reading')));
      expect(names, isNot(contains('Work')));
      expect(names, containsAll(['Night', 'Movie', 'Game']));
    });
  });

  group('names and theme', () {
    test('a name you give an option replaces the monitor label everywhere', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);
      final monitor = rig.controller.monitor!;
      final mode = monitor.feature(VcpCodes.pictureMode)!;

      await rig.controller.setLabel(monitor, VcpCodes.pictureMode, 15, '  Reading  ');

      expect(rig.controller.labelFor(monitor, mode, mode.optionFor(15)!), 'Reading');
      expect(rig.controller.labelFor(monitor, mode, mode.optionFor(40)!), 'Game', reason: 'others are untouched');
    });

    test('a blank name goes back to the monitor label', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);
      final monitor = rig.controller.monitor!;
      final mode = monitor.feature(VcpCodes.pictureMode)!;

      await rig.controller.setLabel(monitor, VcpCodes.pictureMode, 15, 'Reading');
      await rig.controller.setLabel(monitor, VcpCodes.pictureMode, 15, '   ');

      expect(rig.controller.labelFor(monitor, mode, mode.optionFor(15)!), '0x0F');
      expect(rig.controller.customLabel(monitor, VcpCodes.pictureMode, 15), isNull);
    });

    test('names and the theme survive a restart', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);
      final monitor = rig.controller.monitor!;

      await rig.controller.setLabel(monitor, VcpCodes.inputSource, 17, 'Laptop');
      await rig.controller.setThemeMode(ThemeMode.light);

      final reopened = await makeRig(storage: rig.storage, paired: false);
      final input = monitor.feature(VcpCodes.inputSource)!;

      expect(reopened.controller.labelFor(monitor, input, input.optionFor(17)!), 'Laptop');
      expect(reopened.controller.themeMode, ThemeMode.light);
    });
  });

  group('instant start', () {
    test('shows the last known monitors at once, but waits for the PC before acting', () async {
      final api = FakeBridgeApi([sampleMonitor()])..monitorsError = const BridgeException('down');
      final rig = await makeRig(api: api, snapshot: [sampleMonitor(brightness: 20)]);

      expect(rig.controller.monitor!.valueOf(VcpCodes.brightness), 20, reason: 'from the snapshot');
      expect(rig.controller.canControl, isFalse);
    });

    test('controls are enabled once the PC answers', () async {
      final rig = await makeRig(snapshot: [sampleMonitor(brightness: 20)]);

      await waitFor(() => rig.controller.canControl, reason: 'live');
      expect(rig.controller.monitor!.valueOf(VcpCodes.brightness), 25, reason: 'the PC wins over the snapshot');
    });

    test('what the PC reports is saved for next time', () async {
      final rig = await makeRig();
      await waitFor(() => rig.controller.linkState == LinkState.live);

      rig.api.push([sampleMonitor(brightness: 18)]);
      await waitFor(() => rig.storage.loadSnapshot().isNotEmpty, reason: 'snapshot saved');
      await waitFor(
        () => rig.storage.loadSnapshot().first.valueOf(VcpCodes.brightness) == 18,
        reason: 'latest values saved',
      );
    });

    test('unpairing forgets the snapshot too', () async {
      final rig = await makeRig(snapshot: [sampleMonitor()]);

      await rig.controller.unpair();

      expect(rig.storage.loadSnapshot(), isEmpty);
    });
  });
}
