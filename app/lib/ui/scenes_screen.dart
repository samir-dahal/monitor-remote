import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/bridge_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/bridge_controller.dart';
import '../state/scene.dart';
import 'widgets/scene_icons.dart';

/// Scenes: saved picture settings that apply in one tap.
class ScenesScreen extends StatelessWidget {
  const ScenesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = BridgeScope.of(context);
    final monitor = controller.monitor;
    final c = context.colors;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text('Scenes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'One tap sets brightness, picture mode and blue light. Scenes are saved on this phone.',
            style: TextStyle(color: c.muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final scene in controller.scenes) ...[
            _SceneCard(scene: scene, monitor: monitor, controller: controller),
            const SizedBox(height: 10),
          ],
          _AddSceneButton(enabled: monitor != null, onPressed: () => _create(context, controller, monitor!)),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, BridgeController controller, Monitor monitor) async {
    final result = await showSceneEditor(context, title: 'Save current settings');
    if (result == null) return;

    await controller.saveScene(Scene.capture(
      monitor,
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: result.name,
      icon: result.icon,
    ));
  }
}

/// What a scene will do, in words: "40% · Standard · Blue light Level 1".
String describeScene(Scene scene, Monitor? monitor, BridgeController controller) {
  final parts = <String>[];

  String named(int code, int value, String fallback) {
    final feature = monitor?.feature(code);
    final option = feature?.optionFor(value);
    if (monitor == null || feature == null || option == null) return fallback;
    return controller.labelFor(monitor, feature, option);
  }

  final values = scene.values;
  if (values[VcpCodes.brightness] != null) parts.add('${values[VcpCodes.brightness]}%');
  if (values[VcpCodes.contrast] != null) parts.add('Contrast ${values[VcpCodes.contrast]}');
  if (values[VcpCodes.pictureMode] != null) {
    parts.add(named(VcpCodes.pictureMode, values[VcpCodes.pictureMode]!, 'Mode ${values[VcpCodes.pictureMode]}'));
  }
  if (values[VcpCodes.colorPreset] != null) {
    parts.add(named(VcpCodes.colorPreset, values[VcpCodes.colorPreset]!, 'Colour ${values[VcpCodes.colorPreset]}'));
  }
  if (values[VcpCodes.lowBlueLight] != null) {
    parts.add('Blue light ${named(VcpCodes.lowBlueLight, values[VcpCodes.lowBlueLight]!, '${values[VcpCodes.lowBlueLight]}')}');
  }

  return parts.join(' · ');
}

enum _SceneAction { edit, update, delete }

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.scene, required this.monitor, required this.controller});

  final Scene scene;
  final Monitor? monitor;
  final BridgeController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = monitor != null && scene.isActiveOn(monitor!);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: monitor == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                controller.applyScene(scene);
              },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: active ? c.accent : c.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: active ? c.accentSoft : c.raised, shape: BoxShape.circle),
                child: Icon(SceneIcons.of(scene.icon), color: c.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scene.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(describeScene(scene, monitor, controller), style: TextStyle(color: c.muted, fontSize: 13)),
                  ],
                ),
              ),
              if (active) Text('Active', style: TextStyle(color: c.accent, fontSize: 13, fontWeight: FontWeight.w600)),
              PopupMenuButton<_SceneAction>(
                tooltip: 'More for ${scene.name}',
                icon: Icon(Icons.more_vert, color: c.muted),
                onSelected: (action) => _onAction(context, action),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: _SceneAction.edit, child: Text('Rename or change icon')),
                  if (monitor != null) const PopupMenuItem(value: _SceneAction.update, child: Text('Update to current settings')),
                  const PopupMenuItem(value: _SceneAction.delete, child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, _SceneAction action) async {
    switch (action) {
      case _SceneAction.edit:
        final result = await showSceneEditor(context, title: 'Edit scene', existing: scene);
        if (result != null) await controller.saveScene(scene.copyWith(name: result.name, icon: result.icon));
      case _SceneAction.update:
        await controller.saveScene(Scene.capture(monitor!, id: scene.id, name: scene.name, icon: scene.icon));
      case _SceneAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text('Delete ${scene.name}?'),
            content: const Text("This scene will be removed from this phone. Your monitor isn't changed."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
            ],
          ),
        );
        if (confirmed == true) await controller.deleteScene(scene.id);
    }
  }
}

class _AddSceneButton extends StatelessWidget {
  const _AddSceneButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onPressed : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: c.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Save current settings as a scene',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.accent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef SceneEdit = ({String name, String icon});

/// Asks for a scene's name and icon. Returns null when cancelled.
Future<SceneEdit?> showSceneEditor(BuildContext context, {required String title, Scene? existing}) {
  return showDialog<SceneEdit>(
    context: context,
    builder: (_) => _SceneEditor(title: title, existing: existing),
  );
}

class _SceneEditor extends StatefulWidget {
  const _SceneEditor({required this.title, this.existing});

  final String title;
  final Scene? existing;

  @override
  State<_SceneEditor> createState() => _SceneEditorState();
}

class _SceneEditorState extends State<_SceneEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _icon = widget.existing?.icon ?? Scene.iconKeys.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 24,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'Reading'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in Scene.iconKeys)
                Semantics(
                  button: true,
                  selected: key == _icon,
                  label: 'Icon $key',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _icon = key),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: key == _icon ? c.accentSoft : c.raised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: key == _icon ? c.accent : Colors.transparent),
                      ),
                      child: Icon(SceneIcons.of(key), color: key == _icon ? c.accent : c.muted),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: _name.text.trim().isEmpty ? null : () => Navigator.pop(context, (name: _name.text.trim(), icon: _icon)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
