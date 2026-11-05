import 'package:flutter/material.dart';

import '../core/bridge_scope.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'widgets/feature_controls.dart';
import 'widgets/option_strip.dart';

/// Every setting the monitor reports, grouped by category. The escape hatch for anything
/// the Control screen doesn't surface.
class AllControlsScreen extends StatelessWidget {
  const AllControlsScreen({super.key});

  static const _categoryOrder = ['Picture', 'Color', 'Eye Care', 'Audio', 'Input', 'System', 'Advanced'];

  @override
  Widget build(BuildContext context) {
    final controller = BridgeScope.of(context);
    final monitor = controller.monitor;

    final groups = <String, List<Feature>>{};
    for (final feature in monitor?.features ?? const <Feature>[]) {
      if (feature.isAction) continue;
      groups.putIfAbsent(feature.category, () => []).add(feature);
    }

    final categories = groups.keys.toList()
      ..sort((a, b) {
        int rank(String name) {
          final index = _categoryOrder.indexOf(name);
          return index < 0 ? _categoryOrder.length : index;
        }

        return rank(a).compareTo(rank(b));
      });

    return Scaffold(
      appBar: AppBar(title: const Text('All controls')),
      body: monitor == null
          ? const Center(child: Text('No monitor connected'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                for (final category in categories) ...[
                  SectionTitle(category),
                  for (final feature in groups[category]!) ...[
                    _FeatureTile(monitor: monitor, feature: feature),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.monitor, required this.feature});

  final Monitor monitor;
  final Feature feature;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (feature.kind == FeatureKind.continuous && feature.writable) return SliderCard(feature: feature);

    if (feature.isChoice && feature.writable) {
      final useSegments = feature.options.length > 2 && feature.options.every((o) => o.label.length <= 8);
      return ChoiceCard(
        monitor: monitor,
        feature: feature,
        style: useSegments && feature.options.length <= 6 ? StripStyle.segments : StripStyle.chips,
        warm: feature.code == VcpCodes.lowBlueLight,
      );
    }

    // Read-only values, such as firmware versions.
    return SurfaceCard(
      child: Row(
        children: [
          Expanded(child: Text(feature.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          Text(feature.value?.toString() ?? '—', style: TextStyle(color: c.muted, fontSize: 15)),
        ],
      ),
    );
  }
}
