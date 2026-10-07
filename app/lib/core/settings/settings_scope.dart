import 'package:flutter/widgets.dart';

import 'settings_controller.dart';

/// Makes the [SettingsController] available to every screen and rebuilds
/// dependants when a setting changes.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({super.key, required SettingsController controller, required super.child})
      : super(notifier: controller);

  static SettingsController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;

  /// Same without subscribing to changes (usable in initState).
  static SettingsController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
