import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// Drops a word every label repeats, so "Off, Level 1 … Level 5" reads "Off, 1 … 5".
/// The card or sheet title already says what the numbers are.
List<String> compactLabels(List<String> labels) {
  final worded = [
    for (final label in labels)
      if (label.contains(' ')) label,
  ];
  if (worded.length < 2) return labels;

  final firstWord = worded.first.substring(0, worded.first.indexOf(' ') + 1);
  if (!worded.every((label) => label.startsWith(firstWord))) return labels;

  return [
    for (final label in labels)
      label.startsWith(firstWord) && label.length > firstWord.length ? label.substring(firstWord.length) : label,
  ];
}

class StripOption {
  const StripOption(this.value, this.label, {this.icon});

  final int value;
  final String label;
  final IconData? icon;
}

enum StripStyle {
  /// Equal-width tiles with the icon above the label. For a few big choices such as inputs.
  tiles,

  /// Equal-width compact cells. For short labels such as levels 0 to 5.
  segments,

  /// Pills that wrap onto several lines. For longer lists such as picture modes.
  chips,
}

/// A row of mutually exclusive choices.
class OptionStrip extends StatelessWidget {
  const OptionStrip({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.style = StripStyle.chips,
    this.warm = false,
  });

  final List<StripOption> options;
  final int? selected;
  final ValueChanged<int> onSelected;
  final StripStyle style;

  /// Use the amber of the eye-care controls instead of the accent.
  final bool warm;

  static const _labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    final equalWidth = style != StripStyle.chips;
    final labels = equalWidth ? compactLabels([for (final o in options) o.label]) : [for (final o in options) o.label];

    List<Widget> cells(StripStyle cellStyle) => [
      for (var i = 0; i < options.length; i++)
        _Cell(
          option: StripOption(options[i].value, labels[i], icon: options[i].icon),
          selected: options[i].value == selected,
          warm: warm,
          style: cellStyle,
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(options[i].value);
          },
        ),
    ];

    if (!equalWidth) return Wrap(spacing: 8, runSpacing: 8, children: cells(StripStyle.chips));

    final gap = style == StripStyle.tiles ? 8.0 : 4.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Equal cells only when every label fits whole; otherwise wrap, never cut a label short.
        final cellWidth = (constraints.maxWidth - gap * (options.length - 1)) / options.length;
        final scaler = MediaQuery.textScalerOf(context);
        final fits = labels.every((label) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: _labelStyle),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width + 16 <= cellWidth;
        });

        if (!fits) return Wrap(spacing: 8, runSpacing: 8, children: cells(StripStyle.chips));

        final row = cells(style);
        return Row(
          children: [
            for (var i = 0; i < row.length; i++) ...[if (i > 0) SizedBox(width: gap), Expanded(child: row[i])],
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.option,
    required this.selected,
    required this.warm,
    required this.style,
    required this.onTap,
  });

  final StripOption option;
  final bool selected;
  final bool warm;
  final StripStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = warm ? c.lamp : c.accent;
    final soft = warm ? c.lampSoft : c.accentSoft;
    final foreground = selected ? tint : c.muted;

    final label = Text(
      option.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(color: foreground, fontSize: 14, fontWeight: FontWeight.w600),
    );

    final Widget content = switch (style) {
      StripStyle.tiles => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (option.icon != null) ...[Icon(option.icon, color: foreground, size: 24), const SizedBox(height: 4)],
          label,
        ],
      ),
      _ => label,
    };

    final padding = switch (style) {
      StripStyle.tiles => const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      StripStyle.segments => const EdgeInsets.symmetric(vertical: 13),
      StripStyle.chips => const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? soft : c.raised,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: padding,
              // Chips size to their label; a set alignment would stretch them across the Wrap.
              alignment: style == StripStyle.chips ? null : Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? tint : Colors.transparent),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
