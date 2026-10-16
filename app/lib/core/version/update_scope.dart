import 'package:flutter/widgets.dart';

import 'update_controller.dart';

/// Makes the [UpdateController] available to every screen. Optional: tests
/// and previews run without it, and nothing is said about updates then.
class UpdateScope extends InheritedNotifier<UpdateController> {
  const UpdateScope({super.key, required UpdateController controller, required super.child})
      : super(notifier: controller);

  static UpdateController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UpdateScope>()?.notifier;

  /// Same without subscribing to changes (usable in initState).
  static UpdateController? maybeRead(BuildContext context) =>
      context.getInheritedWidgetOfExactType<UpdateScope>()?.notifier;
}
