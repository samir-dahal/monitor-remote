import 'package:flutter/widgets.dart';

import '../state/bridge_controller.dart';

/// Makes the [BridgeController] available to every screen. Widgets that call [of] rebuild
/// whenever the controller changes; [read] gets it without subscribing.
class BridgeScope extends InheritedNotifier<BridgeController> {
  const BridgeScope({super.key, required BridgeController controller, required super.child})
      : super(notifier: controller);

  static BridgeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BridgeScope>();
    assert(scope != null, 'BridgeScope is missing above this widget.');
    return scope!.notifier!;
  }

  static BridgeController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<BridgeScope>();
    assert(scope != null, 'BridgeScope is missing above this widget.');
    return scope!.notifier!;
  }
}
