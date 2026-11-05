import '../data/models.dart';

/// A named set of picture settings that can be applied in one tap.
///
/// Scenes never touch the input source: switching it can leave the screen black if the
/// chosen port has nothing plugged in.
class Scene {
  const Scene({required this.id, required this.name, required this.icon, required this.values});

  factory Scene.fromJson(Map<String, dynamic> json) => Scene(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String? ?? 'sparkles',
    values: (json['values'] as Map<String, dynamic>).map((k, v) => MapEntry(int.parse(k), (v as num).toInt())),
  );

  /// What a scene remembers: the settings people change to suit what they're doing.
  static const capturedCodes = [
    VcpCodes.brightness,
    VcpCodes.contrast,
    VcpCodes.colorPreset,
    VcpCodes.lowBlueLight,
    VcpCodes.pictureMode,
  ];

  /// Icon keys the scene editor offers. The UI maps each to an icon.
  static const iconKeys = ['briefcase', 'moon', 'movie', 'gamepad', 'sun', 'book', 'coffee', 'sparkles'];

  /// Scenes a new install starts with. Values a monitor doesn't support are skipped when applied.
  static List<Scene> starters() => const [
    Scene(
      id: 'starter-work',
      name: 'Work',
      icon: 'briefcase',
      values: {VcpCodes.brightness: 40, VcpCodes.pictureMode: 0, VcpCodes.lowBlueLight: 1},
    ),
    Scene(
      id: 'starter-night',
      name: 'Night',
      icon: 'moon',
      values: {VcpCodes.brightness: 12, VcpCodes.lowBlueLight: 4},
    ),
    Scene(
      id: 'starter-movie',
      name: 'Movie',
      icon: 'movie',
      values: {VcpCodes.brightness: 30, VcpCodes.pictureMode: 50, VcpCodes.lowBlueLight: 2},
    ),
    Scene(
      id: 'starter-game',
      name: 'Game',
      icon: 'gamepad',
      values: {VcpCodes.brightness: 70, VcpCodes.pictureMode: 40, VcpCodes.lowBlueLight: 0},
    ),
  ];

  /// Captures the monitor's current picture settings as a new scene.
  factory Scene.capture(Monitor monitor, {required String id, required String name, required String icon}) {
    final values = <int, int>{};
    for (final code in capturedCodes) {
      final value = monitor.valueOf(code);
      if (value != null) values[code] = value;
    }
    return Scene(id: id, name: name, icon: icon, values: values);
  }

  final String id;
  final String name;
  final String icon;
  final Map<int, int> values;

  Scene copyWith({String? name, String? icon}) =>
      Scene(id: id, name: name ?? this.name, icon: icon ?? this.icon, values: values);

  /// The writes needed to apply this scene to [monitor]: only settings the monitor has,
  /// and only values it accepts.
  Map<int, int> planFor(Monitor monitor) {
    final plan = <int, int>{};
    for (final entry in values.entries) {
      final feature = monitor.feature(entry.key);
      if (feature == null || !feature.writable) continue;

      final acceptable = switch (feature.kind) {
        FeatureKind.continuous => entry.value >= 0 && (feature.max == 0 || entry.value <= feature.max),
        FeatureKind.discrete || FeatureKind.toggle => feature.hasOption(entry.value),
        _ => false,
      };

      if (acceptable) plan[entry.key] = entry.value;
    }
    return plan;
  }

  /// True when everything this scene can set on [monitor] already has the scene's value.
  bool isActiveOn(Monitor monitor) {
    final plan = planFor(monitor);
    if (plan.isEmpty) return false;
    return plan.entries.every((entry) => monitor.valueOf(entry.key) == entry.value);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'values': values.map((k, v) => MapEntry(k.toString(), v)),
  };
}

/// Key for a name the user gave to one option of one setting on one monitor model.
abstract final class LabelKey {
  static String of(Monitor monitor, int code, int value) => '${monitor.model}|$code|$value';
}
