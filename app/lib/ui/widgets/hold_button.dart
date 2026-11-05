import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// A destructive action that only fires after the finger has stayed down long enough,
/// so a stray tap can never wipe the monitor.
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 1500),
  });

  final String label;
  final VoidCallback onConfirmed;
  final Duration holdDuration;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this, duration: widget.holdDuration)
    ..addStatusListener(_onStatus);

  bool _sent = false;
  Timer? _resetTimer;

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _sent) return;

    HapticFeedback.heavyImpact();
    setState(() => _sent = true);
    widget.onConfirmed();

    _resetTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _progress.value = 0;
      setState(() => _sent = false);
    });
  }

  void _press() {
    if (_sent) return;
    HapticFeedback.selectionClick();
    _progress.forward();
  }

  void _release() {
    if (_sent) return;
    _progress.reverse();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = _sent ? c.ok : c.bad;

    return Semantics(
      button: true,
      label: '${widget.label}. Press and hold to confirm.',
      child: ExcludeSemantics(
        child: Listener(
          onPointerDown: (_) => _press(),
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: Container(
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _sent ? Colors.transparent : c.badSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.6)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (context, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _progress.value,
                        child: ColoredBox(color: c.bad.withValues(alpha: 0.28), child: const SizedBox.expand()),
                      ),
                    ),
                  ),
                ),
                Text(
                  _sent ? 'Sent' : widget.label,
                  style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
