import 'package:flutter/material.dart';

import '../core/bridge_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'widgets/feature_controls.dart';

/// Lets the user give the monitor's options names they recognise. Some picture modes only
/// show up as codes such as 0x0F, and an input might be "Laptop" rather than "HDMI-1".
class NamesScreen extends StatelessWidget {
  const NamesScreen({super.key});

  static const _renameable = [VcpCodes.pictureMode, VcpCodes.inputSource];

  @override
  Widget build(BuildContext context) {
    final controller = BridgeScope.of(context);
    final monitor = controller.monitor;
    final c = context.colors;

    final features = [
      for (final code in _renameable)
        if (monitor?.feature(code) != null) monitor!.feature(code)!,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Name your options')),
      body: monitor == null
          ? const Center(child: Text('No monitor connected'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                Text(
                  'Give settings names you recognise. Names are saved on this phone and used everywhere in the app.',
                  style: TextStyle(color: c.muted, fontSize: 14, height: 1.45),
                ),
                for (final feature in features) ...[
                  SectionTitle(feature.name),
                  SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < feature.options.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: c.line),
                          _OptionRow(monitor: monitor, feature: feature, option: feature.options[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.monitor, required this.feature, required this.option});

  final Monitor monitor;
  final Feature feature;
  final VcpOption option;

  @override
  Widget build(BuildContext context) {
    final controller = BridgeScope.of(context);
    final c = context.colors;
    final custom = controller.customLabel(monitor, feature.code, option.value);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(custom ?? option.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: custom == null ? null : Text('The monitor calls it ${option.label}', style: TextStyle(color: c.muted)),
      trailing: Icon(Icons.edit_outlined, color: c.muted),
      onTap: () async {
        final name = await showRenameDialog(context, original: option.label, current: custom ?? '');
        if (name != null) await controller.setLabel(monitor, feature.code, option.value, name);
      },
    );
  }
}

/// Asks for a new name. Returns the name, an empty string for "use the original", or null
/// when cancelled.
Future<String?> showRenameDialog(BuildContext context, {required String original, required String current}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(original: original, current: current),
    );

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.original, required this.current});

  final String original;
  final String current;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Name ${widget.original}'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        maxLength: 20,
        decoration: InputDecoration(labelText: 'Name', hintText: widget.original),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        if (widget.current.isNotEmpty)
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Use original')),
        TextButton(onPressed: () => Navigator.pop(context, _name.text), child: const Text('Save')),
      ],
    );
  }
}
