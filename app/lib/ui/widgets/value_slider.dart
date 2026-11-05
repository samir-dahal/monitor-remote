import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// A slider that only moves when the thumb itself is dragged. Tapping elsewhere on the
/// track, or a scroll gesture that happens to start on it, changes nothing.
class ValueSlider extends StatelessWidget {
  const ValueSlider({
    super.key,
    required this.value,
    required this.max,
    required this.label,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
    this.large = false,
  });

  final int value;
  final int max;
  final String label;
  final VoidCallback onChangeStart;
  final ValueChanged<int> onChanged;
  final VoidCallback onChangeEnd;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final top = max <= 0 ? 1 : max;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: large ? 14 : 10,
        activeTrackColor: c.accent,
        inactiveTrackColor: c.track,
        thumbColor: c.thumb,
        overlayColor: c.accent.withValues(alpha: 0.12),
        thumbShape: _RingThumbShape(radius: large ? 17 : 13),
        trackShape: const RoundedRectSliderTrackShape(),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: value.clamp(0, top).toDouble(),
        min: 0,
        max: top.toDouble(),
        divisions: top,
        semanticFormatterCallback: (v) => '$label ${v.round()}',
        allowedInteraction: SliderInteraction.slideThumb,
        onChangeStart: (_) => onChangeStart(),
        onChanged: (v) => onChanged(v.round()),
        onChangeEnd: (_) => onChangeEnd(),
      ),
    );
  }
}

class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape({required this.radius});

  final double radius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, radius, Paint()..color = sliderTheme.thumbColor ?? Colors.white);
    canvas.drawCircle(
      center,
      radius - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = sliderTheme.activeTrackColor ?? Colors.purple,
    );
  }
}

/// A round − or + button for fine adjustment. Holding it keeps stepping.
class StepButton extends StatefulWidget {
  const StepButton({super.key, required this.icon, required this.label, required this.onStep});

  final IconData icon;
  final String label;
  final VoidCallback onStep;

  @override
  State<StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<StepButton> {
  Timer? _repeat;

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onStep,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onStep,
          onLongPressStart: (_) {
            widget.onStep();
            _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) => widget.onStep());
          },
          onLongPressEnd: (_) => _stop(),
          onLongPressCancel: _stop,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: c.raised, shape: BoxShape.circle),
            child: Icon(widget.icon, color: c.text, size: 22),
          ),
        ),
      ),
    );
  }
}
