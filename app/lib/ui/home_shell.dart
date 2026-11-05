import 'dart:async';

import 'package:flutter/material.dart';

import '../core/bridge_scope.dart';
import '../core/theme.dart';
import '../state/bridge_controller.dart';
import 'control_screen.dart';
import 'pair_screen.dart';
import 'scenes_screen.dart';
import 'settings_screen.dart';

/// The main app: three tabs, a banner when the PC can't be reached, and short notices.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  StreamSubscription<String>? _notices;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Listen once; the controller outlives every screen.
    _notices ??= BridgeScope.read(context).messages.listen((message) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger
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

    return Scaffold(
      body: Column(
        children: [
          _ConnectionBanner(controller: controller),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                ControlScreen(onOpenScenes: () => setState(() => _tab = 1)),
                const ScenesScreen(),
                const SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.tune), label: 'Control'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Scenes'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
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
    final state = controller.linkState;

    final (message, color, soft, canRepair) = switch (state) {
      LinkState.offline => ("Can't reach your PC. Retrying…", c.lamp, c.lampSoft, false),
      LinkState.unauthorized => ('Your PC no longer accepts this phone.', c.bad, c.badSoft, true),
      _ => (null, c.muted, c.raised, false),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Material(
              color: soft,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600))),
                      if (canRepair)
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const PairScreen(canClose: true)),
                          ),
                          child: const Text('Pair again'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
