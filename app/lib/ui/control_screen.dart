import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/bridge_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/bridge_controller.dart';
import 'all_controls_screen.dart';
import 'pair_screen.dart';
import 'widgets/feature_controls.dart';
import 'widgets/option_strip.dart';
import 'widgets/scene_icons.dart';
import 'widgets/status_pill.dart';

/// The daily controls: brightness, scenes, input, low blue light and picture mode.
class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key, required this.onOpenScenes});

  final VoidCallback onOpenScenes;

  @override
  Widget build(BuildContext context) {
    final controller = BridgeScope.of(context);
    final monitor = controller.monitor;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: controller.reread,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _Header(controller: controller, monitor: monitor),
            const SizedBox(height: 14),
            if (monitor == null)
              _EmptyState(controller: controller)
            else
              ..._controls(context, controller, monitor),
          ],
        ),
      ),
    );
  }

  List<Widget> _controls(BuildContext context, BridgeController controller, Monitor monitor) {
    final brightness = monitor.feature(VcpCodes.brightness);
    final input = monitor.feature(VcpCodes.inputSource);
    final eyeCare = monitor.feature(VcpCodes.lowBlueLight);
    final picture = monitor.feature(VcpCodes.pictureMode);

    return [
      if (brightness != null) BrightnessCard(feature: brightness),
      if (controller.scenes.isNotEmpty) ...[
        const SizedBox(height: 14),
        _SceneChips(controller: controller, monitor: monitor, onOpenScenes: onOpenScenes),
      ],
      if (input != null) ...[
        const SizedBox(height: 14),
        ChoiceCard(monitor: monitor, feature: input, style: StripStyle.tiles, withInputIcons: true),
      ],
      if (eyeCare != null) ...[
        const SizedBox(height: 14),
        ChoiceCard(monitor: monitor, feature: eyeCare, style: StripStyle.segments, warm: true),
      ],
      if (picture != null) ...[
        const SizedBox(height: 14),
        ChoiceCard(monitor: monitor, feature: picture),
      ],
      const SizedBox(height: 14),
      _MoreRow(count: monitor.features.where((f) => !f.isAction).length),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.monitor});

  final BridgeController controller;
  final Monitor? monitor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final usable = controller.usableMonitors;
    final input = monitor?.feature(VcpCodes.inputSource);
    final inputLabel = input?.optionFor(input.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monitor?.name ?? 'BenQ Bridge',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  if (monitor != null && input != null && inputLabel != null)
                    Text(
                      controller.labelFor(monitor!, input, inputLabel),
                      style: TextStyle(color: c.muted, fontSize: 14),
                    ),
                ],
              ),
            ),
            StatusPill(state: controller.linkState),
          ],
        ),
        if (usable.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in usable)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(m.name),
                      selected: m.id == monitor?.id,
                      onSelected: (_) => controller.selectMonitor(m.id),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SceneChips extends StatelessWidget {
  const _SceneChips({required this.controller, required this.monitor, required this.onOpenScenes});

  final BridgeController controller;
  final Monitor monitor;
  final VoidCallback onOpenScenes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final scene in controller.scenes)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(SceneIcons.of(scene.icon), size: 18, color: scene.isActiveOn(monitor) ? c.accent : c.muted),
                label: Text(scene.name),
                selected: scene.isActiveOn(monitor),
                showCheckmark: false,
                onSelected: (_) {
                  HapticFeedback.lightImpact();
                  controller.applyScene(scene);
                },
              ),
            ),
          ActionChip(
            avatar: Icon(Icons.edit_outlined, size: 18, color: c.muted),
            label: const Text('Edit scenes'),
            onPressed: onOpenScenes,
          ),
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: const Text('All controls', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Contrast, sharpness, colour, volume and more: $count settings', style: TextStyle(color: c.muted)),
        trailing: Icon(Icons.chevron_right, color: c.muted),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AllControlsScreen())),
      ),
    );
  }
}

/// Shown instead of controls when there's no monitor to control yet, or no connection.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.controller});

  final BridgeController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (title, body, action) = switch (controller.linkState) {
      LinkState.connecting => ('Connecting to your PC…', 'This takes a moment.', null),
      LinkState.offline => (
          "Can't reach your PC",
          'Check that BenQ Bridge is running and that your phone is on the same Wi-Fi. The app keeps trying.',
          null,
        ),
      LinkState.unauthorized => (
          'This phone needs pairing again',
          'Your PC no longer accepts the saved token. Scan its QR code to reconnect.',
          'Pair again',
        ),
      _ => (
          'No monitor found',
          'BenQ Bridge is connected, but no monitor answered. Turn on DDC/CI in the monitor menu, then pull down to re-read.',
          null,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 8),
      child: Column(
        children: [
          if (controller.linkState == LinkState.connecting)
            const Padding(padding: EdgeInsets.only(bottom: 16), child: CircularProgressIndicator()),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 15, height: 1.45)),
          if (action != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PairScreen(canClose: true)),
              ),
              child: Text(action),
            ),
          ],
        ],
      ),
    );
  }
}
