import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/bridge_scope.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import 'option_strip.dart';
import 'value_slider.dart';

/// A rounded surface that groups related controls.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(
          text,
          style: TextStyle(color: context.colors.muted, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      );
}

/// Name on the left, current value on the right.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.name, required this.value, this.dot});

  final String name;
  final String value;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (dot != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          Text(value, style: TextStyle(color: c.muted, fontSize: 14)),
        ],
      ),
    );
  }
}

IconData? _inputIcon(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('hdmi')) return Icons.settings_input_hdmi;
  if (lower.contains('display')) return Icons.cable;
  return Icons.input;
}

/// A setting with a fixed list of values: input source, picture mode, low blue light.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.monitor,
    required this.feature,
    this.style = StripStyle.chips,
    this.warm = false,
    this.withInputIcons = false,
  });

  final Monitor monitor;
  final Feature feature;
  final StripStyle style;
  final bool warm;
  final bool withInputIcons;

  @override
  Widget build(BuildContext context) {
    final controller = BridgeScope.of(context);
    final c = context.colors;

    final options = [
      for (final option in feature.options)
        StripOption(
          option.value,
          controller.labelFor(monitor, feature, option),
          icon: withInputIcons ? _inputIcon(option.label) : null,
        ),
    ];

    final current = feature.optionFor(feature.value);
    final currentLabel = current == null ? '' : controller.labelFor(monitor, feature, current);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(name: feature.name, value: currentLabel, dot: warm ? c.lamp : null),
          if (options.isEmpty)
            Text(
              "This setting didn't list its values, so it can't be changed from here.",
              style: TextStyle(color: c.muted, fontSize: 14),
            )
          else
            OptionStrip(
              options: options,
              selected: feature.value,
              style: style,
              warm: warm,
              onSelected: feature.writable ? (value) => controller.setValue(feature.code, value) : (_) {},
            ),
        ],
      ),
    );
  }
}

/// A setting on a scale, as a compact slider row.
class SliderCard extends StatelessWidget {
  const SliderCard({super.key, required this.feature});

  final Feature feature;

  @override
  Widget build(BuildContext context) {
    final controller = BridgeScope.of(context);
    final value = feature.value ?? 0;

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        children: [
          _CardHeader(name: feature.name, value: '$value${feature.unit ?? ''}'),
          ValueSlider(
            value: value,
            max: feature.max,
            label: feature.name,
            onChangeStart: () => controller.beginEdit(feature.code),
            onChanged: (v) => controller.setValue(feature.code, v),
            onChangeEnd: () => controller.endEdit(feature.code),
          ),
        ],
      ),
    );
  }
}

/// Brightness: the control used most, so it gets the room and steppers for fine changes.
class BrightnessCard extends StatelessWidget {
  const BrightnessCard({super.key, required this.feature});

  final Feature feature;

  @override
  Widget build(BuildContext context) {
    final controller = BridgeScope.of(context);
    final c = context.colors;
    final value = feature.value ?? 0;
    final max = feature.max > 0 ? feature.max : 100;

    void step(int delta) {
      final next = (value + delta).clamp(0, max);
      if (next == value) return;
      HapticFeedback.selectionClick();
      controller.setValue(feature.code, next);
    }

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(feature.name, style: TextStyle(color: c.muted, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Semantics(
            label: '${feature.name} $value${feature.unit == '%' ? ' percent' : ''}',
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 68,
                      fontWeight: FontWeight.w300,
                      height: 1.05,
                      letterSpacing: -2,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (feature.unit != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(feature.unit!, style: TextStyle(color: c.muted, fontSize: 22)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              StepButton(icon: Icons.remove, label: 'Decrease ${feature.name.toLowerCase()}', onStep: () => step(-1)),
              Expanded(
                child: ValueSlider(
                  value: value,
                  max: max,
                  label: feature.name,
                  large: true,
                  onChangeStart: () => controller.beginEdit(feature.code),
                  onChanged: (v) => controller.setValue(feature.code, v),
                  onChangeEnd: () => controller.endEdit(feature.code),
                ),
              ),
              StepButton(icon: Icons.add, label: 'Increase ${feature.name.toLowerCase()}', onStep: () => step(1)),
            ],
          ),
        ],
      ),
    );
  }
}
