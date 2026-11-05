import 'package:benq_bridge/app.dart';
import 'package:benq_bridge/core/theme.dart';
import 'package:benq_bridge/data/bridge_api.dart';
import 'package:benq_bridge/data/models.dart';
import 'package:benq_bridge/state/bridge_controller.dart';
import 'package:benq_bridge/ui/widgets/hold_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/rig.dart';

/// A stand-in for the camera: a button that "scans" a pairing link.
Widget fakeScanner(BuildContext context, ValueChanged<String> onCode) => Center(
      child: FilledButton(
        onPressed: () => onCode('http://192.168.2.220:5080/#t=abc123'),
        child: const Text('Simulate scan'),
      ),
    );

/// A phone-sized screen. The default test surface is 800 by 600, which hides most of the UI.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

Future<Rig> pumpPairedApp(WidgetTester tester, {FakeBridgeApi? api}) async {
  usePhoneScreen(tester);
  final rig = (await tester.runAsync(() async {
    final made = await makeRig(api: api, disposeAtEnd: false);
    await waitFor(() => made.controller.linkState != LinkState.connecting, reason: 'connection result');
    return made;
  }))!;

  await tester.pumpWidget(BenqBridgeApp(controller: rig.controller, scannerBuilder: fakeScanner));
  await tester.pumpAndSettle();

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    rig.controller.dispose();
  });
  return rig;
}

void main() {
  testWidgets('first run asks to pair, and a scanned code connects', (tester) async {
    usePhoneScreen(tester);
    final rig = (await tester.runAsync(() => makeRig(paired: false, disposeAtEnd: false)))!;
    await tester.pumpWidget(BenqBridgeApp(controller: rig.controller, scannerBuilder: fakeScanner));

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
    usePhoneScreen(tester);
    final rig = (await tester.runAsync(() => makeRig(paired: false, disposeAtEnd: false)))!;
    await tester.pumpWidget(BenqBridgeApp(
      controller: rig.controller,
      scannerBuilder: (context, onCode) => Center(
        child: FilledButton(onPressed: () => onCode('https://example.com'), child: const Text('Simulate scan')),
      ),
    ));

    await tester.tap(find.text('Simulate scan'));
    await tester.pump();

    expect(find.textContaining("isn't from BenQ Bridge"), findsOneWidget);
    expect(rig.controller.isPaired, isFalse);

    await tester.pumpWidget(const SizedBox());
    rig.controller.dispose();
  });

  testWidgets('a wrong token on the manual form shows the PC\'s answer', (tester) async {
    usePhoneScreen(tester);
    final api = FakeBridgeApi([sampleMonitor()])
      ..monitorsError = const BridgeException('That token was rejected. Pair again.', unauthorized: true);
    final rig = (await tester.runAsync(() => makeRig(api: api, paired: false, disposeAtEnd: false)))!;
    await tester.pumpWidget(BenqBridgeApp(controller: rig.controller, scannerBuilder: fakeScanner));

    await tester.tap(find.text('Enter the address and token instead'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'PC address'), '192.168.2.220');
    await tester.enterText(find.widgetWithText(TextField, 'Token'), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();

    expect(find.text('That token was rejected. Pair again.'), findsOneWidget);
    expect(rig.controller.isPaired, isFalse);

    await tester.pumpWidget(const SizedBox());
    rig.controller.dispose();
  });

  group('Control screen', () {
    testWidgets('shows the daily controls', (tester) async {
      await pumpPairedApp(tester);

      expect(find.text('Brightness'), findsOneWidget);
      expect(find.text('Input Source'), findsOneWidget);
      expect(find.text('Low Blue Light'), findsOneWidget);
      expect(find.text('Picture Mode'), findsOneWidget);
      expect(find.text('HDMI-1'), findsWidgets);
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('the plus button raises brightness by one and sends it', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('26'), findsOneWidget);
      expect(rig.api.writes.last, (monitorId: 'DISPLAY4', code: VcpCodes.brightness, value: 26));
    });

    testWidgets('tapping an option sets it', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.text('Level 4'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(rig.api.writes.last, (monitorId: 'DISPLAY4', code: VcpCodes.lowBlueLight, value: 4));
    });

    testWidgets('tapping the slider track away from the handle changes nothing', (tester) async {
      final rig = await pumpPairedApp(tester);
      final slider = find.byType(Slider).first;
      final box = tester.getRect(slider);

      // Brightness is 25, so the handle sits near the left. Tap near the right end.
      await tester.tapAt(Offset(box.right - 30, box.center.dy));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('25'), findsOneWidget);
      expect(rig.api.writes, isEmpty);
    });

    testWidgets('dragging the handle changes brightness', (tester) async {
      // At 50 the handle sits exactly in the middle of the slider.
      final rig = await pumpPairedApp(tester, api: FakeBridgeApi([sampleMonitor(brightness: 50)]));
      final centre = tester.getCenter(find.byType(Slider).first);

      final gesture = await tester.startGesture(centre);
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));

      expect(rig.api.writes, isNotEmpty);
      expect(rig.api.writes.last.value, greaterThan(50));
    });

    testWidgets('a named option shows its name', (tester) async {
      final rig = await pumpPairedApp(tester);
      final monitor = rig.controller.monitor!;

      await tester.runAsync(() => rig.controller.setLabel(monitor, VcpCodes.pictureMode, 15, 'Reading'));
      await tester.pump();

      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('0x0F'), findsNothing);
    });

    testWidgets('says so when the PC cannot be reached', (tester) async {
      final api = FakeBridgeApi([sampleMonitor()])..monitorsError = const BridgeException('down');
      await pumpPairedApp(tester, api: api);

      expect(find.text("Can't reach your PC. Retrying…"), findsOneWidget);
    });
  });

  group('Scenes tab', () {
    testWidgets('tapping a scene applies it', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.text('Scenes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Night'));
      await tester.pump(const Duration(milliseconds: 200));

      expect({for (final w in rig.api.writes) w.code: w.value}, {VcpCodes.brightness: 12, VcpCodes.lowBlueLight: 4});
    });

    testWidgets('describes what each scene does', (tester) async {
      await pumpPairedApp(tester);

      await tester.tap(find.text('Scenes'));
      await tester.pumpAndSettle();

      expect(find.text('12% · Blue light Level 4'), findsOneWidget);
    });
  });

  group('Settings tab', () {
    testWidgets('a reset needs a long press, not a tap', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Reset to factory settings'), 300);
      await tester.tap(find.text('Reset to factory settings'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Hold to run'));
      await tester.tap(find.text('Hold to run'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(rig.api.writes, isEmpty);
    });
  });

  group('Settings screens', () {
    testWidgets('a name given in Settings shows up on the Control screen', (tester) async {
      await pumpPairedApp(tester);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name your options'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('0x0F'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Reading');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('The monitor calls it 0x0F'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Control'));
      await tester.pumpAndSettle();

      expect(find.text('Reading'), findsOneWidget);
    });

    testWidgets('a name can be cleared again', (tester) async {
      final rig = await pumpPairedApp(tester);
      final monitor = rig.controller.monitor!;
      await tester.runAsync(() => rig.controller.setLabel(monitor, VcpCodes.pictureMode, 15, 'Reading'));

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name your options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use original'));
      await tester.pumpAndSettle();

      expect(find.text('0x0F'), findsOneWidget);
      expect(rig.controller.customLabel(monitor, VcpCodes.pictureMode, 15), isNull);
    });

    testWidgets('All controls lists every setting under its category', (tester) async {
      await pumpPairedApp(tester);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All controls'));
      await tester.pumpAndSettle();

      expect(find.text('Picture'), findsOneWidget);
      expect(find.text('Eye Care'), findsOneWidget);
      expect(find.text('Brightness'), findsOneWidget);
      expect(find.text('Low Blue Light'), findsOneWidget);
      expect(find.text('Restore Factory Defaults'), findsNothing, reason: 'resets live under Reset, not here');
    });

    testWidgets('the theme can be switched', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(rig.controller.themeMode, ThemeMode.light);
    });
  });

  group('Scene editing', () {
    testWidgets('saving the current settings creates a scene', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.text('Scenes'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Save current settings as a scene'), 200);
      await tester.tap(find.text('Save current settings as a scene'));
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

    testWidgets('a scene needs a name before it can be saved', (tester) async {
      final rig = await pumpPairedApp(tester);
      final before = rig.controller.scenes.length;

      await tester.tap(find.text('Scenes'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Save current settings as a scene'), 200);
      await tester.tap(find.text('Save current settings as a scene'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(rig.controller.scenes.length, before);
    });

    testWidgets('deleting a scene asks first', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.text('Scenes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Work?'), findsOneWidget);
      expect(rig.controller.scenes.map((s) => s.name), contains('Work'), reason: 'not removed until confirmed');

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(rig.controller.scenes.map((s) => s.name), isNot(contains('Work')));
    });

    testWidgets('updating a scene captures the current settings', (tester) async {
      final rig = await pumpPairedApp(tester);

      await tester.tap(find.text('Scenes'));
      await tester.pumpAndSettle();
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
              body: Center(child: HoldToConfirmButton(label: 'Hold to reset', onConfirmed: onConfirmed)),
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
