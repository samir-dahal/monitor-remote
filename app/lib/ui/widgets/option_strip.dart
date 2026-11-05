import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final cells = [
      for (final option in options)
        _Cell(
          option: option,
          selected: option.value == selected,
          warm: warm,
          style: style,
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(option.value);
          },
        ),
    ];

    if (style == StripStyle.chips) {
      return Wrap(spacing: 8, runSpacing: 8, children: cells);
    }

    return Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) SizedBox(width: style == StripStyle.tiles ? 8 : 4),
          Expanded(child: cells[i]),
        ],
      ],
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
              alignment: Alignment.center,
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
