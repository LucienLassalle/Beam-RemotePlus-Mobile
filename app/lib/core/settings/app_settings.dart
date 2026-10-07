/// User preferences, persisted between launches (see [SettingsController]).
/// Immutable: change it with [copyWith].
class AppSettings {
  /// Name of the driving screen theme (also its id), see themes/theme_registry.dart.
  final String themeName;

  /// 'en', 'fr'... or null to follow the phone language.
  final String? localeCode;

  final bool tiltSteering;
  final double rotationRangeDeg;
  final bool invertSteering;
  final bool steeringSmoothing;
  final bool useKmh;
  final bool shiftHaptics;
  final bool pitchGearShift;

  /// Volume up = horn, volume down = headlight flash.
  final bool volumeKeys;
  final bool showActionsBar;
  final bool debugMode;

  static const List<double> rotationRanges = [360, 540, 720, 900];

  const AppSettings({
    this.themeName = 'Default',
    this.localeCode,
    this.tiltSteering = true,
    this.rotationRangeDeg = 900,
    this.invertSteering = true,
    this.steeringSmoothing = true,
    this.useKmh = true,
    this.shiftHaptics = false,
    this.pitchGearShift = false,
    this.volumeKeys = true,
    this.showActionsBar = true,
    this.debugMode = false,
  });

  // Sentinel so copyWith can set localeCode back to null (system language).
  static const Object _keep = Object();

  AppSettings copyWith({
    String? themeName,
    Object? localeCode = _keep,
    bool? tiltSteering,
    double? rotationRangeDeg,
    bool? invertSteering,
    bool? steeringSmoothing,
    bool? useKmh,
    bool? shiftHaptics,
    bool? pitchGearShift,
    bool? volumeKeys,
    bool? showActionsBar,
    bool? debugMode,
  }) {
    return AppSettings(
      themeName: themeName ?? this.themeName,
      localeCode: identical(localeCode, _keep) ? this.localeCode : localeCode as String?,
      tiltSteering: tiltSteering ?? this.tiltSteering,
      rotationRangeDeg: rotationRangeDeg ?? this.rotationRangeDeg,
      invertSteering: invertSteering ?? this.invertSteering,
      steeringSmoothing: steeringSmoothing ?? this.steeringSmoothing,
      useKmh: useKmh ?? this.useKmh,
      shiftHaptics: shiftHaptics ?? this.shiftHaptics,
      pitchGearShift: pitchGearShift ?? this.pitchGearShift,
      volumeKeys: volumeKeys ?? this.volumeKeys,
      showActionsBar: showActionsBar ?? this.showActionsBar,
      debugMode: debugMode ?? this.debugMode,
    );
  }

  Map<String, Object?> toJson() => {
        'themeName': themeName,
        'localeCode': localeCode,
        'tiltSteering': tiltSteering,
        'rotationRangeDeg': rotationRangeDeg,
        'invertSteering': invertSteering,
        'steeringSmoothing': steeringSmoothing,
        'useKmh': useKmh,
        'shiftHaptics': shiftHaptics,
        'pitchGearShift': pitchGearShift,
        'volumeKeys': volumeKeys,
        'showActionsBar': showActionsBar,
        'debugMode': debugMode,
      };

  /// Missing or wrongly typed values fall back to the defaults, so settings
  /// saved by an older app version always load.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    const d = AppSettings();
    T pick<T>(String key, T fallback) {
      final v = json[key];
      return v is T ? v : fallback;
    }

    final range = json['rotationRangeDeg'];
    final rotation = range is num && rotationRanges.contains(range.toDouble()) ? range.toDouble() : d.rotationRangeDeg;
    return AppSettings(
      themeName: pick('themeName', d.themeName),
      localeCode: json['localeCode'] is String ? json['localeCode'] as String : null,
      tiltSteering: pick('tiltSteering', d.tiltSteering),
      rotationRangeDeg: rotation,
      invertSteering: pick('invertSteering', d.invertSteering),
      steeringSmoothing: pick('steeringSmoothing', d.steeringSmoothing),
      useKmh: pick('useKmh', d.useKmh),
      shiftHaptics: pick('shiftHaptics', d.shiftHaptics),
      pitchGearShift: pick('pitchGearShift', d.pitchGearShift),
      volumeKeys: pick('volumeKeys', d.volumeKeys),
      showActionsBar: pick('showActionsBar', d.showActionsBar),
      debugMode: pick('debugMode', d.debugMode),
    );
  }
}
