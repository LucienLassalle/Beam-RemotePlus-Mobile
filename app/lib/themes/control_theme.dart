import 'package:flutter/material.dart';

import '../core/protocol/telemetry.dart';
import '../core/settings/units.dart';
import 'kit/video_hud.dart';

/// A driving screen theme. See THEMES.md for a step-by-step guide.
///
/// A theme DRAWS the dashboard: it receives the latest telemetry and returns
/// a widget filling the screen. Pedals, steering and buttons are placed by
/// the app, and touching the dashboard is touching a pedal, except on the
/// few DashboardButtons a theme may add (kit/dashboard_button.dart).
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

  /// Draws the dashboard over the point of view video, in the same room as
  /// [buildDashboard]. [inside]: a seat camera, the car's own dashboard is
  /// in view. By default nothing then, else the light [VideoHud] on the
  /// sides, so the video stays visible.
  Widget buildVideoDashboard(BuildContext context, DashboardData data, {required bool inside}) =>
      inside ? const SizedBox.shrink() : VideoHud(data: data);
}

/// Everything a dashboard may display. Telemetry values are nullable: null
/// means "not provided by this vehicle", draw a dash or hide the gauge.
class DashboardData {
  final Telemetry telemetry;

  /// False without the Beam-RemotePlus mod: there is no telemetry at all.
  final bool modActive;
  final bool useKmh;

  /// Units chosen by the user for temperatures and tyre pressures (the
  /// telemetry is in °C and kPa): format with DashFormat.temperature and
  /// DashFormat.pressure.
  final TemperatureUnit temperatureUnit;
  final PressureUnit pressureUnit;
  final bool readOnly;

  /// Set for ~300 ms after a gear change requested from the phone.
  final GearFlash? gearFlash;

  /// Sends a command to the game (see ModCommand), for DashboardButtons.
  /// Null when commands cannot be sent (no mod, read-only mode).
  final void Function(String command)? onCommand;

  const DashboardData({
    required this.telemetry,
    required this.modActive,
    required this.useKmh,
    this.temperatureUnit = TemperatureUnit.celsius,
    this.pressureUnit = PressureUnit.bar,
    this.readOnly = false,
    this.gearFlash,
    this.onCommand,
  });
}

enum GearFlash { up, down }

/// Vehicle buttons a theme may show at the bottom of the screen (the user
/// can still hide each one in the settings). The horn and headlight flash
/// are also on the volume buttons. Vehicle-specific ones (flashers, siren,
/// race controls of vehicle mods) only show on vehicles fitted with them.
enum VehicleAction { signals, hazard, horn, highBeam, lights, flashers, siren, parkingBrake, starter, driveMode, cruise, drs, pushToPass, pitLimiter }

/// What a volume button does while driving. A theme picks them (see
/// [ThemeStyle.volumeUp]), so they never change with the vehicle.
enum VolumeKeyAction {
  /// Horn while held.
  horn,

  /// High beams while held.
  headlightFlash,

  /// Opens / closes the DRS of the vehicle mods that have one; nothing on
  /// other vehicles.
  drs,

  /// Starts / stops the Push-to-Pass of the vehicle mods that have one;
  /// nothing on other vehicles.
  pushToPass,
}

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

  /// The volume buttons (each one can be switched off in the settings).
  final VolumeKeyAction volumeUp;
  final VolumeKeyAction volumeDown;

  /// A "More" button opening every other command of the vehicle (fog
  /// lights, 4WD, trailer, vehicle mods...), see more_sheet.dart.
  final bool moreButton;

  /// A big handbrake to hold at the bottom left, above the brake (drifting).
  final bool handbrakeButton;

  const ThemeStyle({
    this.background = Colors.black,
    this.brakeColor = Colors.redAccent,
    this.throttleColor = Colors.greenAccent,
    this.buttonColor = Colors.white70,
    this.visiblePedals = false,
    this.actions = const {},
    this.volumeUp = VolumeKeyAction.horn,
    this.volumeDown = VolumeKeyAction.headlightFlash,
    this.moreButton = false,
    this.handbrakeButton = false,
  });
}
