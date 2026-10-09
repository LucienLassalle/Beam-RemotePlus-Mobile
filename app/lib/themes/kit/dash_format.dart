import '../../core/protocol/telemetry.dart';
import '../../core/settings/units.dart';

export '../../core/settings/units.dart' show PressureUnit, TemperatureUnit;

/// Formatting helpers shared by themes, so every theme shows missing values
/// the same way.
class DashFormat {
  DashFormat._();

  static const String missing = '–';

  static String integer(double? value) => value == null ? missing : value.round().toString();

  static String decimal(double? value, [int digits = 1]) => value == null ? missing : value.toStringAsFixed(digits);

  static String speed(Telemetry t, {required bool kmh}) => integer(t.speedIn(kmh: kmh));

  static String speedUnit({required bool kmh}) => kmh ? 'km/h' : 'mph';

  /// Fuel as a percentage (0-100).
  static String fuelPercent(Telemetry t) => integer(t.fuel == null ? null : t.fuel! * 100);

  /// Kilometres or miles from metres.
  static String distance(double? metres, {required bool kmh}) =>
      integer(metres == null ? null : metres / (kmh ? 1000 : 1609.344));

  /// Tyre pressure in bar from kPa.
  static String bar(double? kpa) => decimal(kpa == null ? null : kpa / 100, 1);

  /// Temperature (telemetry in °C) in the unit chosen by the user, without
  /// the symbol: append [TemperatureUnit.symbol] or just "°".
  static String temperature(double? celsius, TemperatureUnit unit) =>
      integer(celsius == null ? null : unit.convert(celsius));

  /// Pressure (telemetry in kPa) in the unit chosen by the user, without
  /// the symbol ([PressureUnit.symbol]).
  static String pressure(double? kpa, PressureUnit unit) =>
      kpa == null ? missing : unit.convert(kpa).toStringAsFixed(unit.decimals);

  /// Clock "HH:MM" of the phone (the game's time of day is not sent).
  static String clock(DateTime now) =>
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}
