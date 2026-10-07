import 'package:flutter/material.dart';

import '../core/protocol/telemetry.dart';

/// A driving screen theme. See THEMES.md for a step-by-step guide.
///
/// A theme only DRAWS the dashboard: it receives the latest telemetry and
/// returns a widget filling the screen. Pedals, steering and buttons are
/// placed by the app on top of it, so no theme can ever block the controls
/// (touching the dashboard is touching a pedal).
abstract class ControlTheme {
  const ControlTheme();

  /// Unique name, also shown in the settings (e.g. 'Civetta').
  String get name;

  /// GitHub handle of the author, shown in the settings.
  String get author;

  /// Colors of the controls drawn by the app over this theme.
  ThemeStyle get style => const ThemeStyle();

  /// Draws the dashboard. Called for every telemetry frame (~30 Hz): keep it
  /// cheap (no async work, no heavy allocations).
  Widget buildDashboard(BuildContext context, DashboardData data);
}

/// Everything a dashboard may display. Telemetry values are nullable: null
/// means "not provided by this vehicle", draw a dash or hide the gauge.
class DashboardData {
  final Telemetry telemetry;

  /// False without the Beam-RemotePlus mod: there is no telemetry at all.
  final bool modActive;
  final bool useKmh;
  final bool readOnly;

  /// Set for ~300 ms after a gear change requested from the phone.
  final GearFlash? gearFlash;

  const DashboardData({
    required this.telemetry,
    required this.modActive,
    required this.useKmh,
    this.readOnly = false,
    this.gearFlash,
  });
}

enum GearFlash { up, down }

/// Vehicle buttons a theme may show at the bottom of the screen (the user
/// can still hide each one in the settings). The horn and headlight flash
/// are also on the volume buttons.
enum VehicleAction { signals, hazard, horn, highBeam, lights, parkingBrake, starter, driveMode, cruise }

/// Look of the app-drawn controls over a theme.
class ThemeStyle {
  final Color background;
  final Color brakeColor;
  final Color throttleColor;

  /// Foreground of the buttons (vehicle switch, actions bar...).
  final Color buttonColor;

  /// Visible pedal zones (gradient fill + label) instead of thin edge bars.
  final bool visiblePedals;

  /// Vehicle buttons shown by this theme (none by default: a dashboard
  /// theme stays clean, a "road" theme can offer them all).
  final Set<VehicleAction> actions;

  const ThemeStyle({
    this.background = Colors.black,
    this.brakeColor = Colors.redAccent,
    this.throttleColor = Colors.greenAccent,
    this.buttonColor = Colors.white70,
    this.visiblePedals = false,
    this.actions = const {},
  });
}
