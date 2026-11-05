import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// A tall fader like a phone's control centre. Drag up or down anywhere on it: the value
/// moves with the finger instead of jumping to where it landed, so it can't change by accident,
/// and it ticks every 5%.
class BrightnessFader extends StatefulWidget {
  const BrightnessFader({
    super.key,
    required this.value,
    required this.max,
    required this.enabled,
    required this.onBegin,
    required this.onChanged,
    required this.onEnd,
    this.label = 'Brightness',
    this.unit = '%',
  });

  final int value;
  final int max;
  final bool enabled;
  final VoidCallback onBegin;
  final ValueChanged<int> onChanged;
  final VoidCallback onEnd;
  final String label;
  final String? unit;

  @override
  State<BrightnessFader> createState() => _BrightnessFaderState();
}

class _BrightnessFaderState extends State<BrightnessFader> {
  /// The exact position while a finger is down; null otherwise.
  double? _drag;

  int get _top => widget.max <= 0 ? 100 : widget.max;

  int get _shown => _drag?.round() ?? widget.value.clamp(0, _top);

  void _start(DragStartDetails _) {
    HapticFeedback.lightImpact();
    setState(() => _drag = widget.value.clamp(0, _top).toDouble());
    widget.onBegin();
  }

  void _update(DragUpdateDetails details, double height) {
    final current = _drag;
    if (current == null || height <= 0) return;

    final next = (current - details.delta.dy / height * _top).clamp(0, _top).toDouble();
    final before = current.round();
    final after = next.round();
    setState(() => _drag = next);

    if (after == before) return;
    if (after ~/ 5 != before ~/ 5 || after == 0 || after == _top) HapticFeedback.selectionClick();
    widget.onChanged(after);
  }

  void _finish() {
    if (_drag == null) return;
    setState(() => _drag = null);
    widget.onEnd();
  }

  void _step(int delta) {
    final next = (widget.value + delta).clamp(0, _top);
    if (next != widget.value) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final fraction = (_shown / _top).clamp(0.0, 1.0);
        final filled = fraction * height;
        // Text over the fill switches colour so it stays readable.
        final numberCovered = filled > height - 112;
        final iconCovered = filled > 56;

        return Semantics(
          slider: true,
          enabled: widget.enabled,
          label: widget.label,
          value: '$_shown${widget.unit == '%' ? ' percent' : ''}',
          increasedValue: '${(_shown + 1).clamp(0, _top)}',
          decreasedValue: '${(_shown - 1).clamp(0, _top)}',
          onIncrease: widget.enabled ? () => _step(1) : null,
          onDecrease: widget.enabled ? () => _step(-1) : null,
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: widget.enabled ? _start : null,
              onVerticalDragUpdate: widget.enabled ? (d) => _update(d, height) : null,
              onVerticalDragEnd: widget.enabled ? (_) => _finish() : null,
              onVerticalDragCancel: widget.enabled ? _finish : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: widget.enabled ? 1 : 0.55,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: c.raised),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedFractionallySizedBox(
                          duration: _drag == null ? const Duration(milliseconds: 220) : Duration.zero,
                          curve: Curves.easeOutCubic,
                          widthFactor: 1,
                          heightFactor: fraction,
                          child: ColoredBox(color: c.accent),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        top: 18,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.label,
                              style: TextStyle(
                                color: numberCovered ? c.onAccent : c.muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$_shown',
                                  style: TextStyle(
                                    color: numberCovered ? c.onAccent : c.text,
                                    fontSize: 56,
                                    fontWeight: FontWeight.w300,
                                    height: 1.1,
                                    letterSpacing: -2,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                if (widget.unit != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 3),
                                    child: Text(
                                      widget.unit!,
                                      style: TextStyle(color: numberCovered ? c.onAccent : c.muted, fontSize: 20),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 18,
                        child: Icon(Icons.light_mode_outlined, size: 26, color: iconCovered ? c.onAccent : c.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
