import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_remote/app.dart';
import 'package:monitor_remote/core/theme.dart';
import 'package:monitor_remote/data/bridge_api.dart';
import 'package:monitor_remote/data/models.dart';
import 'package:monitor_remote/state/bridge_controller.dart';
import 'package:monitor_remote/ui/widgets/brightness_fader.dart';
import 'package:monitor_remote/ui/widgets/hold_button.dart';

import 'support/fakes.dart';
import 'support/rig.dart';

/// A stand-in for the camera: a button that "scans" a pairing link.
Widget fakeScanner(BuildContext context, ValueChanged<String> onCode) => Center(
  child: FilledButton(
    onPressed: () => onCode('http://192.168.2.220:5080/#t=abc123'),
    child: const Text('Simulate scan'),
  ),
);

/// A small phone: 360 by 640 logical pixels, the size the app has to fit without scrolling.
void useSmallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<Rig> pumpPairedApp(WidgetTester tester, {FakeBridgeApi? api, List<Monitor>? snapshot}) async {
  useSmallPhone(tester);
  final rig = (await tester.runAsync(() async {
    final made = await makeRig(api: api, snapshot: snapshot, disposeAtEnd: false);
    await waitFor(() => made.controller.linkState != LinkState.connecting, reason: 'connection result');
    return made;
  }))!;

  await tester.pumpWidget(MonitorRemoteApp(controller: rig.controller, scannerBuilder: fakeScanner));
  await tester.pumpAndSettle();

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    rig.controller.dispose();
  });
  return rig;
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
}

void main() {
  group('Pairing', () {
    testWidgets('first run asks to pair, and a scanned code connects', (tester) async {
      useSmallPhone(tester);
      final rig = (await tester.runAsync(() => makeRig(paired: false, disposeAtEnd: false)))!;
      await tester.pumpWidget(MonitorRemoteApp(controller: rig.controller, scannerBuilder: fakeScanner));

      expect(find.text('Pair your PC'), findsOneWidget);

      await tester.tap(find.text('Simulate scan'));
      await tester.runAsync(() => waitFor(() => rig.controller.linkState == LinkState.live, reason: 'live'));
      await tester.pumpAndSettle();

      expect(find.text('BenQ GW2490'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      rig.controller.dispose();
    });

    testWidgets('a code that is not from BenQ Bridge is refused', (tester) async {
      useSmallPhone(tester);
      final rig = (await tester.runAsync(() => makeRig(paired: false, disposeAtEnd: false)))!;
      await tester.pumpWidget(
        MonitorRemoteApp(
          controller: rig.controller,
          scannerBuilder: (context, onCode) => Center(
            child: FilledButton(onPressed: () => onCode('https://example.com'), child: const Text('Simulate scan')),
          ),
        ),
      );

      await tester.tap(find.text('Simulate scan'));
      await tester.pump();

      expect(find.textContaining("isn't from BenQ Bridge"), findsOneWidget);
      expect(rig.controller.isPaired, isFalse);

      await tester.pumpWidget(const SizedBox());
      rig.controller.dispose();
    });

    testWidgets('a wrong token on the manual form shows the answer from the PC', (tester) async {
      useSmallPhone(tester);
      final api = FakeBridgeApi([sampleMonitor()])
        ..monitorsError = const BridgeException('That token was rejected. Pair again.', unauthorized: true);
      final rig = (await tester.runAsync(() => makeRig(api: api, paired: false, disposeAtEnd: false)))!;
      await tester.pumpWidget(MonitorRemoteApp(controller: rig.controller, scannerBuilder: fakeScanner));

      await tester.tap(find.text('Enter the address and token instead'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'PC address'), '192.168.2.220');
      await tester.enterText(find.widgetWithText(TextField, 'Token'), 'wrong');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Connect'));
      await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
      await tester.pumpAndSettle();

      expect(find.text('That token was rejected. Pair again.'), findsOneWidget);
      expect(rig.controller.isPaired, isFalse);

      await tester.pumpWidget(const SizedBox());
      rig.controller.dispose();
    });
  });

  group('Remote screen', () {
    testWidgets('fits every daily control on a small phone without scrolling', (tester) async {
      await pumpPairedApp(tester);
      final screen = tester.getRect(find.byType(Scaffold).first);

      for (final text in ['Brightness', 'Blue light', 'Input', 'Picture mode', 'Night']) {
        final rect = tester.getRect(find.text(text).first);
        expect(screen.contains(rect.center), isTrue, reason: '$text is on screen');
      }
      expect(find.byType(SingleChildScrollView), findsNothing, reason: 'no scrolling fallback needed');
    });

    testWidgets('tiles show the current value with the full label', (tester) async {
      await pumpPairedApp(tester);

      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('HDMI-1'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('dragging the fader down lowers brightness', (tester) async {
      final rig = await pumpPairedApp(tester);
      final fader = tester.getCenter(find.byType(BrightnessFader));

      final gesture = await tester.startGesture(fader);
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, 15));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));

      expect(rig.api.writes, isNotEmpty);
      expect(rig.api.writes.last.code, VcpCodes.brightness);
      expect(rig.api.writes.last.value, lessThan(25));
      expect(find.text('${rig.api.writes.last.value}'), findsOneWidget);
    });

    testWidgets('a tap on the fader changes nothing', (tester) async {
      final rig = await pumpPairedApp(tester);
      final box = tester.getRect(find.byType(BrightnessFader));

      await tester.tapAt(Offset(box.center.dx, box.bottom - 20));
      await tester.tapAt(Offset(box.center.dx, box.top + 20));
      await tester.pump(const Duration(milliseconds: 200));

      expect(rig.api.writes, isEmpty);
      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('the minus button lowers brightness by one', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump(const Duration(milliseconds: 100));

      expect(rig.api.writes.single, (monitorId: 'DISPLAY4', code: VcpCodes.brightness, value: 24));
      expect(find.text('24'), findsOneWidget);
    });

    testWidgets('the blue light tile opens the levels and sets one', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.text('Blue light'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      expect(rig.api.writes.single, (monitorId: 'DISPLAY4', code: VcpCodes.lowBlueLight, value: 4));
      expect(find.text('Level 4'), findsOneWidget, reason: 'sheet closed and the tile updated');
    });

    testWidgets('choosing the current option again sends nothing', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.text('Picture mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Standard').last);
      await tester.pumpAndSettle();

      expect(rig.api.writes, isEmpty);
    });

    testWidgets('switching input can be undone', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.text('Input'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HDMI-2'));
      await tester.pumpAndSettle();

      expect(rig.api.writes.last, (monitorId: 'DISPLAY4', code: VcpCodes.inputSource, value: 18));
      expect(find.text('Switched to HDMI-2'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(rig.api.writes.last, (monitorId: 'DISPLAY4', code: VcpCodes.inputSource, value: 17));
    });

    testWidgets('a picture mode can be renamed from its sheet', (tester) async {
      await pumpPairedApp(tester);

      await tester.tap(find.text('Picture mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rename 0x0F'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Reading');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('0x0F'), findsOneWidget, reason: 'the original name stays visible underneath');
    });

    testWidgets('a scene pill applies the scene', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.text('Night'));
      await tester.pump(const Duration(milliseconds: 200));

      expect({for (final w in rig.api.writes) w.code: w.value}, {VcpCodes.brightness: 12, VcpCodes.lowBlueLight: 4});
    });

    testWidgets('long-pressing a scene offers to delete it, and asks first', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.longPress(find.text('Work'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Work?'), findsOneWidget);
      expect(rig.controller.scenes.map((s) => s.name), contains('Work'));

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(rig.controller.scenes.map((s) => s.name), isNot(contains('Work')));
      expect(rig.api.writes, isEmpty, reason: 'editing a scene never touches the monitor');
    });

    testWidgets('the plus pill saves the current settings as a scene', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.dragUntilVisible(
        find.byTooltip('Save current settings as a scene'),
        find.byType(ListView).last,
        const Offset(-200, 0),
      );
      await tester.tap(find.byTooltip('Save current settings as a scene'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Reading');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final created = rig.controller.scenes.last;
      expect(created.name, 'Reading');
      expect(created.values[VcpCodes.brightness], 25);
      expect(created.values.containsKey(VcpCodes.inputSource), isFalse);
    });

    testWidgets('opens on the last known values and waits for the PC before acting', (tester) async {
      final api = FakeBridgeApi([sampleMonitor()])..monitorsError = const BridgeException('down');
      final rig = await pumpPairedApp(tester, api: api, snapshot: [sampleMonitor(brightness: 20)]);

      expect(find.text('20'), findsOneWidget, reason: 'cached value shown at once');
      expect(find.text("Can't reach your PC. Retrying…"), findsOneWidget);

      await tester.drag(find.byType(BrightnessFader), const Offset(0, 80));
      await tester.tap(find.text('Night'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(rig.api.writes, isEmpty, reason: 'nothing is sent while offline');
    });
  });

  group('Settings', () {
    testWidgets('a name given in Settings shows up on the main screen', (tester) async {
      await pumpPairedApp(tester);

      await openSettings(tester);
      await tester.tap(find.text('Name your options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HDMI-1'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Laptop');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('The monitor calls it HDMI-1'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Laptop'), findsOneWidget);
    });

    testWidgets('a name can be cleared again', (tester) async {
      final rig = await pumpPairedApp(tester);
      final monitor = rig.controller.monitor!;
      await tester.runAsync(() => rig.controller.setLabel(monitor, VcpCodes.pictureMode, 15, 'Reading'));

      await openSettings(tester);
      await tester.tap(find.text('Name your options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use original'));
      await tester.pumpAndSettle();

      expect(rig.controller.customLabel(monitor, VcpCodes.pictureMode, 15), isNull);
    });

    testWidgets('All controls lists every setting under its category', (tester) async {
      await pumpPairedApp(tester);

      await tester.tap(find.byTooltip('All controls'));
      await tester.pumpAndSettle();

      expect(find.text('Picture'), findsOneWidget);
      expect(find.text('Eye Care'), findsOneWidget);
      expect(find.text('Brightness'), findsOneWidget);
      expect(find.text('Restore Factory Defaults'), findsNothing, reason: 'resets live in Settings');
    });

    testWidgets('All controls shows blue light levels as short numbers, not cut-off labels', (tester) async {
      await pumpPairedApp(tester);

      await tester.tap(find.byTooltip('All controls'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Low Blue Light'), 200);
      await tester.pumpAndSettle();

      for (final label in ['Off', '1', '2', '3', '4', '5']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Level 1'), findsOneWidget, reason: 'the current value, in full, in the card header');
    });

    testWidgets('the theme can be switched', (tester) async {
      final rig = await pumpPairedApp(tester);

      await openSettings(tester);
      await tester.scrollUntilVisible(find.text('Light'), 200);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(rig.controller.themeMode, ThemeMode.light);
    });

    testWidgets('a reset needs a long press, not a tap', (tester) async {
      final rig = await pumpPairedApp(tester);

      await openSettings(tester);
      await tester.scrollUntilVisible(find.text('Reset to factory settings'), 200);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset to factory settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Hold to run'), 200);
      await tester.tap(find.text('Hold to run'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(rig.api.writes, isEmpty);
    });

    testWidgets('scenes can be managed from Settings', (tester) async {
      final rig = await pumpPairedApp(tester);

      await openSettings(tester);
      await tester.tap(find.text('Scenes'));
      await tester.pumpAndSettle();

      expect(find.text('12% · Blue light Level 4'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update to current settings'));
      await tester.pumpAndSettle();

      final work = rig.controller.scenes.firstWhere((s) => s.id == 'starter-work');
      expect(work.values[VcpCodes.brightness], 25, reason: 'was 40 before');
    });
  });

  group('HoldToConfirmButton', () {
    Future<void> pumpButton(WidgetTester tester, void Function() onConfirmed) => tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: Scaffold(
          body: Center(
            child: HoldToConfirmButton(label: 'Hold to reset', onConfirmed: onConfirmed),
          ),
        ),
      ),
    );

    testWidgets('fires after the full hold', (tester) async {
      var fired = 0;
      await pumpButton(tester, () => fired++);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldToConfirmButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await gesture.up();

      expect(fired, 1);
      expect(find.text('Sent'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('does not fire when let go early', (tester) async {
      var fired = 0;
      await pumpButton(tester, () => fired++);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(HoldToConfirmButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(fired, 0);
      expect(find.text('Hold to reset'), findsOneWidget);
    });
  });
}
