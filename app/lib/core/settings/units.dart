/// Display units chosen in the settings. The telemetry itself always uses
/// °C and kPa (see the mod's PROTOCOL.md); conversion happens at display.
enum TemperatureUnit {
  celsius('°C'),
  fahrenheit('°F');

  final String symbol;
  const TemperatureUnit(this.symbol);

  double convert(double degreesC) => this == TemperatureUnit.celsius ? degreesC : degreesC * 9 / 5 + 32;
}

enum PressureUnit {
  kpa('kPa', 1, 0),
  bar('bar', 0.01, 2),
  psi('psi', 0.1450377, 0);

  final String symbol;
  final double _fromKpa;

  /// Decimals worth showing (2.20 bar, 220 kPa, 32 psi).
  final int decimals;
  const PressureUnit(this.symbol, this._fromKpa, this.decimals);

  double convert(double kpa) => kpa * _fromKpa;
}

/// Enum value by name, or [fallback] for an unknown or missing name.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);
