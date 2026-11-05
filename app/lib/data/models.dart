/// Standard MCCS VCP codes the app knows by name. Every other code still shows up under
/// "All controls", because the monitor's own capability list decides what exists.
abstract final class VcpCodes {
  static const restoreFactoryDefaults = 0x04;
  static const restoreLuminanceDefaults = 0x05;
  static const restoreColorDefaults = 0x08;
  static const brightness = 0x10;
  static const contrast = 0x12;
  static const colorPreset = 0x14;
  static const lowBlueLight = 0x19;
  static const inputSource = 0x60;
  static const pictureMode = 0xDC;
}

class VcpOption {
  const VcpOption({required this.value, required this.label});

  factory VcpOption.fromJson(Map<String, dynamic> json) =>
      VcpOption(value: (json['value'] as num).toInt(), label: json['label'] as String);

  final int value;
  final String label;
}

/// How a feature is controlled, as reported by the bridge.
enum FeatureKind { continuous, discrete, toggle, action, info }

class Feature {
  const Feature({
    required this.code,
    required this.name,
    required this.category,
    required this.kind,
    required this.writable,
    required this.max,
    this.unit,
    this.value,
    this.options = const [],
  });

  factory Feature.fromJson(Map<String, dynamic> json) => Feature(
        code: (json['code'] as num).toInt(),
        name: json['name'] as String,
        category: json['category'] as String? ?? 'Advanced',
        kind: _kindFrom(json['kind'] as String?),
        writable: json['writable'] as bool? ?? false,
        max: (json['max'] as num?)?.toInt() ?? 0,
        unit: json['unit'] as String?,
        value: (json['value'] as num?)?.toInt(),
        options: [
          for (final option in (json['options'] as List<dynamic>? ?? const []))
            VcpOption.fromJson(option as Map<String, dynamic>),
        ],
      );

  final int code;
  final String name;
  final String category;
  final FeatureKind kind;
  final bool writable;
  final int max;
  final String? unit;
  final int? value;
  final List<VcpOption> options;

  String get hex => code.toRadixString(16).toUpperCase().padLeft(2, '0');

  bool get isAction => kind == FeatureKind.action;

  bool get isChoice => kind == FeatureKind.discrete || kind == FeatureKind.toggle;

  bool hasOption(int candidate) => options.any((o) => o.value == candidate);

  VcpOption? optionFor(int? candidate) {
    for (final option in options) {
      if (option.value == candidate) return option;
    }
    return null;
  }

  Feature withValue(int? newValue) => Feature(
        code: code,
        name: name,
        category: category,
        kind: kind,
        writable: writable,
        max: max,
        unit: unit,
        value: newValue,
        options: options,
      );

  static FeatureKind _kindFrom(String? raw) => switch (raw) {
        'continuous' => FeatureKind.continuous,
        'discrete' => FeatureKind.discrete,
        'toggle' => FeatureKind.toggle,
        'action' => FeatureKind.action,
        _ => FeatureKind.info,
      };
}

class Monitor {
  const Monitor({
    required this.id,
    required this.name,
    required this.model,
    required this.supported,
    required this.ddcChannel,
    required this.features,
  });

  factory Monitor.fromJson(Map<String, dynamic> json) => Monitor(
        id: json['id'] as String,
        name: json['name'] as String? ?? json['id'] as String,
        model: json['model'] as String? ?? '',
        supported: json['supported'] as bool? ?? false,
        ddcChannel: json['ddcChannel'] as bool? ?? false,
        features: [
          for (final feature in (json['features'] as List<dynamic>? ?? const []))
            Feature.fromJson(feature as Map<String, dynamic>),
        ],
      );

  final String id;
  final String name;
  final String model;
  final bool supported;
  final bool ddcChannel;
  final List<Feature> features;

  /// A monitor worth showing: it answered DDC/CI and reported something to control.
  bool get usable => supported && features.isNotEmpty;

  Feature? feature(int code) {
    for (final feature in features) {
      if (feature.code == code) return feature;
    }
    return null;
  }

  int? valueOf(int code) => feature(code)?.value;

  Monitor withFeatureValue(int code, int value) => Monitor(
        id: id,
        name: name,
        model: model,
        supported: supported,
        ddcChannel: ddcChannel,
        features: [
          for (final feature in features) feature.code == code ? feature.withValue(value) : feature,
        ],
      );
}
