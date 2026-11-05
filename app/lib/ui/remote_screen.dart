import 'dart:async';

import 'package:flutter/material.dart';

import '../core/bridge_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/bridge_controller.dart';
import 'all_controls_screen.dart';
import 'pair_screen.dart';
import 'settings_screen.dart';
import 'widgets/brightness_fader.dart';
import 'widgets/option_sheet.dart';
import 'widgets/quick_tile.dart';
import 'widgets/scene_bar.dart';
import 'widgets/status_pill.dart';
import 'widgets/value_slider.dart';

/// The app: one screen that fits without scrolling. A tall brightness fader, three tiles for
/// blue light, input and picture mode, and scenes along the bottom where the thumb rests.
class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key});

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  StreamSubscription<String>? _notices;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Listen once; the controller outlives every screen.
    _notices ??= BridgeScope.read(context).messages.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
    });
  }

  @override
  void dispose() {
    unawaited(_notices?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = BridgeScope.of(context);
    final monitor = controller.monitor;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(controller: controller, monitor: monitor),
            _ConnectionBanner(controller: controller),
            Expanded(
              child: monitor == null
                  ? _EmptyState(controller: controller)
                  : _Controls(controller: controller, monitor: monitor),
            ),
          ],
        ),
      ),
    );
  }
}

void _open(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.monitor});

  final BridgeController controller;
  final Monitor? monitor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final usable = controller.usableMonitors;
    final canSwitch = usable.length > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: canSwitch ? () => _pickMonitor(context) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            monitor?.name ?? 'Your monitor',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (canSwitch) Icon(Icons.expand_more, color: c.muted),
                      ],
                    ),
                    const SizedBox(height: 4),
                    StatusPill(state: controller.linkState),
                  ],
                ),
              ),
            ),
          ),
          if (monitor != null)
            IconButton(
              tooltip: 'All controls',
              icon: const Icon(Icons.tune),
              onPressed: () => _open(context, const AllControlsScreen()),
            ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _open(context, const SettingsScreen()),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonitor(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: context.colors.surface,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in controller.usableMonitors)
            ListTile(
              leading: const Icon(Icons.desktop_windows_outlined),
              title: Text(m.name),
              trailing: m.id == monitor?.id ? Icon(Icons.check_circle, color: sheet.colors.accent) : null,
              onTap: () {
                controller.selectMonitor(m.id);
                Navigator.pop(sheet);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.monitor});

  final BridgeController controller;
  final Monitor monitor;

  /// Below this the layout gets cramped, so it scrolls instead of squashing.
  static const _minimumHeight = 460.0;

  @override
  Widget build(BuildContext context) {
    final brightness = monitor.feature(VcpCodes.brightness);
    final eyeCare = monitor.feature(VcpCodes.lowBlueLight);
    final input = monitor.feature(VcpCodes.inputSource);
    final picture = monitor.feature(VcpCodes.pictureMode);
    final enabled = controller.canControl;

    final tiles = <Widget>[
      if (eyeCare != null && eyeCare.options.isNotEmpty)
        QuickTile(
          icon: Icons.visibility_outlined,
          title: 'Blue light',
          value: _currentLabel(eyeCare),
          active: (eyeCare.value ?? 0) > 0,
          warm: true,
          enabled: enabled,
          onTap: () => showOptionSheet(
            context,
            monitor: monitor,
            feature: eyeCare,
            title: 'Blue light',
            warm: true,
            compact: true,
          ),
        ),
      if (input != null && input.options.isNotEmpty)
        QuickTile(
          icon: Icons.settings_input_hdmi,
          title: 'Input',
          value: _currentLabel(input),
          enabled: enabled,
          onTap: () => showOptionSheet(
            context,
            monitor: monitor,
            feature: input,
            title: 'Input',
            renameable: true,
            onChosen: (previous, chosen) => _switchInput(context, input, previous, chosen),
          ),
        ),
      if (picture != null && picture.options.isNotEmpty)
        QuickTile(
          icon: Icons.palette_outlined,
          title: 'Picture mode',
          value: _currentLabel(picture),
          enabled: enabled,
          onTap: () =>
              showOptionSheet(context, monitor: monitor, feature: picture, title: 'Picture mode', renameable: true),
        ),
    ];

    Widget tileColumn() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(height: 12), Expanded(child: tiles[i])],
      ],
    );

    final body = Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (brightness != null)
                  Expanded(
                    flex: 11,
                    child: Column(
                      children: [
                        Expanded(
                          child: BrightnessFader(
                            value: brightness.value ?? 0,
                            max: brightness.max,
                            unit: brightness.unit,
                            enabled: enabled,
                            onBegin: () => controller.beginEdit(brightness.code),
                            onChanged: (v) => controller.setValue(brightness.code, v),
                            onEnd: () => controller.endEdit(brightness.code),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Steppers(controller: controller, feature: brightness, enabled: enabled),
                      ],
                    ),
                  ),
                if (brightness != null && tiles.isNotEmpty) const SizedBox(width: 12),
                if (tiles.isNotEmpty) Expanded(flex: 9, child: tileColumn()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SceneBar(controller: controller, monitor: monitor),
        const SizedBox(height: 12),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxHeight >= _minimumHeight
          ? body
          : SingleChildScrollView(
              child: SizedBox(height: _minimumHeight, child: body),
            ),
    );
  }

  String _currentLabel(Feature feature) {
    final option = feature.optionFor(feature.value);
    return option == null ? '—' : controller.labelFor(monitor, feature, option);
  }

  /// Switching to an empty port blacks out the screen, so the change can be undone from here.
  void _switchInput(BuildContext context, Feature input, int previous, int chosen) {
    controller.setValue(input.code, chosen);

    final name = input.optionFor(chosen);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Switched to ${name == null ? 'input $chosen' : controller.labelFor(monitor, input, name)}'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'Undo', onPressed: () => controller.setValue(input.code, previous)),
        ),
      );
  }
}

class _Steppers extends StatelessWidget {
  const _Steppers({required this.controller, required this.feature, required this.enabled});

  final BridgeController controller;
  final Feature feature;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final value = feature.value ?? 0;
    final max = feature.max > 0 ? feature.max : 100;

    void step(int delta) {
      final next = (value + delta).clamp(0, max);
      if (next != value) controller.setValue(feature.code, next);
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.55,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            StepButton(icon: Icons.remove, label: 'Decrease ${feature.name.toLowerCase()}', onStep: () => step(-1)),
            StepButton(icon: Icons.add, label: 'Increase ${feature.name.toLowerCase()}', onStep: () => step(1)),
          ],
        ),
      ),
    );
  }
}

/// Only appears when something is wrong, so a healthy connection stays quiet.
class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.controller});

  final BridgeController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (message, color, soft, canRepair) = switch (controller.linkState) {
      LinkState.offline => ("Can't reach your PC. Retrying…", c.lamp, c.lampSoft, false),
      LinkState.unauthorized => ('Your PC no longer accepts this phone.', c.bad, c.badSoft, true),
      _ => (null, c.muted, c.raised, false),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
              decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (canRepair)
                    TextButton(
                      onPressed: () => _open(context, const PairScreen(canClose: true)),
                      child: const Text('Pair again'),
                    )
                  else
                    const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}

/// Shown instead of controls when there's no monitor to control yet.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.controller});

  final BridgeController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (title, body) = switch (controller.linkState) {
      LinkState.connecting => ('Connecting to your PC…', 'This takes a moment.'),
      LinkState.offline => (
        "Can't reach your PC",
        'Check that BenQ Bridge is running and that your phone is on the same Wi-Fi. The app keeps trying.',
      ),
      LinkState.unauthorized => (
        'This phone needs pairing again',
        'Your PC no longer accepts the saved token. Scan its QR code to reconnect.',
      ),
      _ => (
        'No monitor found',
        'Your PC is connected, but no monitor answered. Turn on DDC/CI in the monitor menu, then re-read it from Settings.',
      ),
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.linkState == LinkState.connecting)
              const Padding(padding: EdgeInsets.only(bottom: 16), child: CircularProgressIndicator()),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 15, height: 1.45),
            ),
            if (controller.linkState == LinkState.unauthorized) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => _open(context, const PairScreen(canClose: true)),
                child: const Text('Pair again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
