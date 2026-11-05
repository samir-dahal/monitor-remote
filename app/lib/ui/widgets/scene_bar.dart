import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/bridge_controller.dart';
import '../scenes_screen.dart';
import 'scene_icons.dart';

/// Scenes as one row of pills: tap to apply, long-press to edit, + to save the current settings.
class SceneBar extends StatelessWidget {
  const SceneBar({super.key, required this.controller, required this.monitor});

  final BridgeController controller;
  final Monitor monitor;

  @override
  Widget build(BuildContext context) {
    final enabled = controller.canControl;

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final scene in controller.scenes) ...[
            _Pill(
              icon: SceneIcons.of(scene.icon),
              label: scene.name,
              active: scene.isActiveOn(monitor),
              enabled: enabled,
              onTap: () {
                HapticFeedback.lightImpact();
                controller.applyScene(scene);
              },
              onLongPress: () => showSceneActions(context, controller, scene, monitor),
            ),
            const SizedBox(width: 8),
          ],
          _Pill(
            icon: Icons.add,
            label: controller.scenes.isEmpty ? 'Save a scene' : null,
            tooltip: 'Save current settings as a scene',
            enabled: true,
            onTap: () => saveCurrentAsScene(context, controller, monitor),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.onTap,
    required this.enabled,
    this.label,
    this.tooltip,
    this.active = false,
    this.onLongPress,
  });

  final IconData icon;
  final String? label;
  final String? tooltip;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final foreground = active ? c.accent : c.text;

    final pill = Material(
      color: active ? c.accentSoft : c.surface,
      shape: StadiumBorder(side: BorderSide(color: active ? c.accent : c.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: enabled ? onTap : null,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label == null ? 14 : 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: active ? c.accent : c.muted),
              if (label != null) ...[
                const SizedBox(width: 8),
                Text(
                  label!,
                  style: TextStyle(color: foreground, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final semantic = Semantics(
      button: true,
      selected: active,
      label: label ?? tooltip,
      hint: onLongPress == null ? null : 'Long-press for options',
      child: ExcludeSemantics(
        child: AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: enabled ? 1 : 0.55, child: pill),
      ),
    );

    return tooltip == null ? semantic : Tooltip(message: tooltip!, child: semantic);
  }
}
