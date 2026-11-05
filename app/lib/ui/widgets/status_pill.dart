import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../state/bridge_controller.dart';

/// Shows whether the phone is talking to the PC right now.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.state});

  final LinkState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = switch (state) {
      LinkState.live => ('Live', c.ok),
      LinkState.connecting => ('Connecting…', c.muted),
      LinkState.offline => ('Offline', c.lamp),
      LinkState.unauthorized => ('Pair again', c.bad),
      LinkState.unpaired => ('Not paired', c.muted),
    };

    return Semantics(
      label: 'Connection: $label',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
