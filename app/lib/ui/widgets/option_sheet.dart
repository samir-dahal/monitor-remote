import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/bridge_scope.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../names_screen.dart';
import 'option_strip.dart';

/// Called when the user picks an option. The default just sets it.
typedef OptionChosen = void Function(int previous, int chosen);

/// The choices for one setting, as a bottom sheet. Picking one applies it and closes the sheet.
Future<void> showOptionSheet(
  BuildContext context, {
  required Monitor monitor,
  required Feature feature,
  bool warm = false,
  bool compact = false,
  bool renameable = false,
  String? title,
  OptionChosen? onChosen,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    builder: (_) => _OptionSheet(
      monitorId: monitor.id,
      code: feature.code,
      warm: warm,
      compact: compact,
      renameable: renameable,
      title: title,
      onChosen: onChosen,
    ),
  );
}

class _OptionSheet extends StatelessWidget {
  const _OptionSheet({
    required this.monitorId,
    required this.code,
    required this.warm,
    required this.compact,
    required this.renameable,
    required this.title,
    required this.onChosen,
  });

  final String monitorId;
  final int code;
  final bool warm;
  final bool compact;
  final bool renameable;

  /// Same words as the tile that opened the sheet; the monitor's own name otherwise.
  final String? title;
  final OptionChosen? onChosen;

  @override
  Widget build(BuildContext context) {
    // Rebuilds with live updates, so a value changed elsewhere shows here too.
    final controller = BridgeScope.of(context);
    final monitor = controller.monitors.where((m) => m.id == monitorId).firstOrNull;
    final feature = monitor?.feature(code);
    final c = context.colors;

    if (monitor == null || feature == null) return const SizedBox(height: 120);

    void choose(int value) {
      HapticFeedback.selectionClick();
      final previous = feature.value;
      Navigator.of(context).pop();
      if (value == previous) return;
      if (onChosen != null && previous != null) {
        onChosen!(previous, value);
      } else {
        controller.setValue(feature.code, value);
      }
    }

    final tint = warm ? c.lamp : c.accent;
    final soft = warm ? c.lampSoft : c.accentSoft;
    final cellLabels = compactLabels([for (final o in feature.options) controller.labelFor(monitor, feature, o)]);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title ?? feature.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (compact)
              Row(
                children: [
                  for (var i = 0; i < feature.options.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _Cell(
                        label: cellLabels[i],
                        selected: feature.options[i].value == feature.value,
                        tint: tint,
                        soft: soft,
                        onTap: () => choose(feature.options[i].value),
                      ),
                    ),
                  ],
                ],
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final option in feature.options)
                      _Row(
                        monitor: monitor,
                        feature: feature,
                        option: option,
                        selected: option.value == feature.value,
                        tint: tint,
                        soft: soft,
                        renameable: renameable,
                        onTap: () => choose(option.value),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.selected,
    required this.tint,
    required this.soft,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color tint;
  final Color soft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? soft : c.raised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? tint : Colors.transparent, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 64,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(color: selected ? tint : c.text, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.monitor,
    required this.feature,
    required this.option,
    required this.selected,
    required this.tint,
    required this.soft,
    required this.renameable,
    required this.onTap,
  });

  final Monitor monitor;
  final Feature feature;
  final VcpOption option;
  final bool selected;
  final Color tint;
  final Color soft;
  final bool renameable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = BridgeScope.of(context);
    final c = context.colors;
    final custom = controller.customLabel(monitor, feature.code, option.value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? soft : c.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? tint : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        custom ?? option.label,
                        style: TextStyle(color: selected ? tint : c.text, fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      if (custom != null) Text(option.label, style: TextStyle(color: c.muted, fontSize: 13)),
                    ],
                  ),
                ),
                if (renameable)
                  IconButton(
                    tooltip: 'Rename ${custom ?? option.label}',
                    icon: Icon(Icons.edit_outlined, color: c.muted, size: 20),
                    onPressed: () async {
                      final name = await showRenameDialog(context, original: option.label, current: custom ?? '');
                      if (name != null) await controller.setLabel(monitor, feature.code, option.value, name);
                    },
                  )
                else
                  const SizedBox(height: 48),
                SizedBox(width: 40, child: selected ? Icon(Icons.check_circle, color: tint) : null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
