import 'dart:convert';

import 'package:monitor_remote/data/models.dart';
import 'package:monitor_remote/state/scene.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  final monitor = sampleMonitor();

  group('Scene.planFor', () {
    test('keeps settings the monitor has and accepts', () {
      const scene = Scene(
        id: 's',
        name: 'Movie',
        icon: 'movie',
        values: {VcpCodes.brightness: 30, VcpCodes.pictureMode: 50, VcpCodes.lowBlueLight: 2},
      );

      expect(scene.planFor(monitor), {VcpCodes.brightness: 30, VcpCodes.pictureMode: 50, VcpCodes.lowBlueLight: 2});
    });

    test('skips a value the monitor does not list', () {
      const scene = Scene(
        id: 's',
        name: 'Odd',
        icon: 'sparkles',
        values: {VcpCodes.pictureMode: 99, VcpCodes.lowBlueLight: 4},
      );

      expect(scene.planFor(monitor), {VcpCodes.lowBlueLight: 4});
    });

    test('skips a setting the monitor does not have', () {
      const scene = Scene(id: 's', name: 'Contrast', icon: 'sun', values: {VcpCodes.contrast: 50});

      expect(scene.planFor(monitor), isEmpty);
    });

    test('skips a brightness above the monitor maximum', () {
      const scene = Scene(id: 's', name: 'Bright', icon: 'sun', values: {VcpCodes.brightness: 250});

      expect(scene.planFor(monitor), isEmpty);
    });

    test('never changes the input source', () {
      final fromMonitor = Scene.capture(sampleMonitor(input: 18), id: 'x', name: 'Now', icon: 'sun');

      expect(fromMonitor.values.containsKey(VcpCodes.inputSource), isFalse);
    });
  });

  group('Scene.isActiveOn', () {
    const night = Scene(
      id: 'n',
      name: 'Night',
      icon: 'moon',
      values: {VcpCodes.brightness: 12, VcpCodes.lowBlueLight: 4},
    );

    test('is active when every settable value already matches', () {
      expect(night.isActiveOn(sampleMonitor(brightness: 12, blueLight: 4)), isTrue);
    });

    test('is not active when one value differs', () {
      expect(night.isActiveOn(sampleMonitor(brightness: 12, blueLight: 1)), isFalse);
    });

    test('is never active when nothing in it applies to the monitor', () {
      const unrelated = Scene(id: 'u', name: 'U', icon: 'sun', values: {VcpCodes.contrast: 10});

      expect(unrelated.isActiveOn(monitor), isFalse);
    });
  });

  group('Scene.capture', () {
    test('records the current picture settings', () {
      final scene = Scene.capture(
        sampleMonitor(brightness: 33, pictureMode: 40, blueLight: 3),
        id: 'c',
        name: 'Reading',
        icon: 'book',
      );

      expect(scene.name, 'Reading');
      expect(scene.values, {VcpCodes.brightness: 33, VcpCodes.pictureMode: 40, VcpCodes.lowBlueLight: 3});
    });
  });

  group('persistence', () {
    test('survives a JSON round trip', () {
      const scene = Scene(id: 'a', name: 'Work', icon: 'briefcase', values: {16: 40, 25: 1});

      final restored = Scene.fromJson(jsonDecode(jsonEncode(scene.toJson())) as Map<String, dynamic>);

      expect(restored.id, 'a');
      expect(restored.name, 'Work');
      expect(restored.icon, 'briefcase');
      expect(restored.values, {16: 40, 25: 1});
    });

    test('a new install starts with Work, Night, Movie and Game', () {
      expect([for (final s in Scene.starters()) s.name], ['Work', 'Night', 'Movie', 'Game']);
    });

    test('copyWith renames without touching the settings', () {
      final renamed = Scene.starters().first.copyWith(name: 'Office', icon: 'coffee');

      expect(renamed.name, 'Office');
      expect(renamed.icon, 'coffee');
      expect(renamed.values, Scene.starters().first.values);
    });
  });

  test('option names are keyed by monitor model, code and value', () {
    expect(LabelKey.of(monitor, VcpCodes.pictureMode, 15), 'GW2490|220|15');
  });
}
