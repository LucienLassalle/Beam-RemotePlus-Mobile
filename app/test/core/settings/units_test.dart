import 'package:beam_remoteplus/core/settings/app_settings.dart';
import 'package:beam_remoteplus/themes/kit/dash_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('temperatures convert from the telemetry °C', () {
    expect(DashFormat.temperature(90, TemperatureUnit.celsius), '90');
    expect(DashFormat.temperature(90, TemperatureUnit.fahrenheit), '194');
    expect(DashFormat.temperature(null, TemperatureUnit.fahrenheit), DashFormat.missing);
    expect(TemperatureUnit.fahrenheit.symbol, '°F');
  });

  test('tyre pressures convert from the telemetry kPa', () {
    expect(DashFormat.pressure(220, PressureUnit.kpa), '220');
    expect(DashFormat.pressure(220, PressureUnit.bar), '2.20');
    expect(DashFormat.pressure(220, PressureUnit.psi), '32');
    expect(DashFormat.pressure(null, PressureUnit.bar), DashFormat.missing);
  });

  test('units are saved with the settings, °C and bar by default', () {
    const d = AppSettings();
    expect(d.temperatureUnit, TemperatureUnit.celsius);
    expect(d.pressureUnit, PressureUnit.bar);
    final back = AppSettings.fromJson(
      const AppSettings(temperatureUnit: TemperatureUnit.fahrenheit, pressureUnit: PressureUnit.psi).toJson(),
    );
    expect(back.temperatureUnit, TemperatureUnit.fahrenheit);
    expect(back.pressureUnit, PressureUnit.psi);
    expect(AppSettings.fromJson({'pressureUnit': 'atm'}).pressureUnit, PressureUnit.bar);
  });
}
