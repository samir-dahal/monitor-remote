import 'package:flutter/material.dart';

import '../core/app_info.dart';
import '../core/bridge_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/bridge_controller.dart';
import 'all_controls_screen.dart';
import 'names_screen.dart';
import 'pair_screen.dart';
import 'scenes_screen.dart';
import 'widgets/feature_controls.dart';
import 'widgets/hold_button.dart';
import 'widgets/status_pill.dart';

/// Which PC the phone talks to, names for options, theme, and the reset commands.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = BridgeScope.of(context);
    final monitor = controller.monitor;
    final c = context.colors;
    final actions = [
      for (final f in monitor?.features ?? const <Feature>[])
        if (f.isAction) f,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SurfaceCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: c.raised, shape: BoxShape.circle),
                  child: Icon(Icons.desktop_windows_outlined, color: c.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your PC', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(controller.link?.address ?? 'Not paired', style: TextStyle(color: c.muted, fontSize: 14)),
                    ],
                  ),
                ),
                StatusPill(state: controller.linkState),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR to pair a PC'),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PairScreen(canClose: true))),
          ),
          const SectionTitle('Monitor'),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _NavRow(
                  title: 'Scenes',
                  subtitle: '${controller.scenes.length} saved',
                  onTap: () => _open(context, const ScenesScreen()),
                ),
                Divider(height: 1, color: c.line),
                _NavRow(
                  title: 'Name your options',
                  subtitle: 'Your own names for picture modes and inputs',
                  onTap: () => _open(context, const NamesScreen()),
                ),
                Divider(height: 1, color: c.line),
                _NavRow(
                  title: 'All controls',
                  subtitle: monitor == null ? null : '${monitor.features.where((f) => !f.isAction).length} settings',
                  onTap: () => _open(context, const AllControlsScreen()),
                ),
                Divider(height: 1, color: c.line),
                _NavRow(
                  title: 'Re-read monitor',
                  subtitle: 'Fetch every value again',
                  onTap: () async {
                    await controller.reread();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monitor re-read')));
                    }
                  },
                ),
              ],
            ),
          ),
          const SectionTitle('Appearance'),
          SurfaceCard(
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {controller.themeMode},
                onSelectionChanged: (selection) => controller.setThemeMode(selection.first),
              ),
            ),
          ),
          if (actions.isNotEmpty) _ResetSection(actions: actions, controller: controller),
          const SizedBox(height: 28),
          Center(
            child: Text('$appName $appVersion', style: TextStyle(color: c.muted, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.title, required this.onTap, this.subtitle});

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(color: c.muted)),
      trailing: Icon(Icons.chevron_right, color: c.muted),
      onTap: onTap,
    );
  }
}

/// What each reset command does, in plain words.
const _resetCopy = <int, ({String text, String? warning})>{
  VcpCodes.restoreFactoryDefaults: (
    text:
        'Restores every setting to how the monitor left the factory: picture mode, brightness, '
        'contrast, colour, low blue light, audio and menu language.',
    warning:
        "If the factory input isn't the one you use, the picture goes black until you pick "
        "the input with the monitor's own buttons.",
  ),
  VcpCodes.restoreLuminanceDefaults: (text: 'Restores brightness and contrast to the factory values.', warning: null),
  VcpCodes.restoreColorDefaults: (
    text: 'Restores colour temperature and the red, green and blue gains to the factory values.',
    warning: null,
  ),
};

class _ResetSection extends StatelessWidget {
  const _ResetSection({required this.actions, required this.controller});

  final List<Feature> actions;
  final BridgeController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: EdgeInsets.zero,
          title: Text(
            'Reset to factory settings',
            style: TextStyle(color: c.bad, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          iconColor: c.bad,
          collapsedIconColor: c.bad,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
              child: Text(
                "These send a one-shot command to the monitor. Its factory values can't be read back, so a reset can't be undone.",
                style: TextStyle(color: c.muted, fontSize: 14, height: 1.45),
              ),
            ),
            for (final feature in actions) ...[
              _ResetCard(feature: feature, controller: controller),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResetCard extends StatelessWidget {
  const _ResetCard({required this.feature, required this.controller});

  final Feature feature;
  final BridgeController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final copy = _resetCopy[feature.code];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.bad.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feature.name,
            style: TextStyle(color: c.bad, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (copy != null) ...[
            const SizedBox(height: 6),
            Text(copy.text, style: TextStyle(color: c.muted, fontSize: 14, height: 1.45)),
            if (copy.warning != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: c.lamp, width: 3)),
                ),
                child: Text(copy.warning!, style: TextStyle(color: c.lamp, fontSize: 14, height: 1.45)),
              ),
            ],
          ],
          const SizedBox(height: 14),
          HoldToConfirmButton(label: 'Hold to run', onConfirmed: () => controller.runAction(feature.code)),
        ],
      ),
    );
  }
}
