import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// A square control showing one setting and its current value. Tapping it opens the choices.
class QuickTile extends StatelessWidget {
  const QuickTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.active = false,
    this.warm = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  /// Highlighted, like a switched-on toggle (for example low blue light above Off).
  final bool active;

  /// Use the eye-care amber instead of the accent.
  final bool warm;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = warm ? c.lamp : c.accent;
    final soft = warm ? c.lampSoft : c.accentSoft;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title, $value',
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.55,
          child: Material(
            color: active ? soft : c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: active ? tint.withValues(alpha: 0.55) : c.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, size: 26, color: active ? tint : c.muted),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active ? tint : c.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
