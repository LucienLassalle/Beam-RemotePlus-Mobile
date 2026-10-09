import 'units.dart';

export 'units.dart';

/// User preferences, persisted between launches (see [SettingsController]).
/// Immutable: change it with [copyWith].
class AppSettings {
  // Display ---------------------------------------------------------------------

  /// Name of the driving screen theme (also its id), see themes/theme_registry.dart.
  final String themeName;

  /// 'en', 'fr'... or null to follow the phone language.
  final String? localeCode;
  final bool useKmh;
  final TemperatureUnit temperatureUnit;
  final PressureUnit pressureUnit;

  /// Real-car style warning lights popping on screen.
  final bool warningPopups;

  /// Radar + damage panel over the driving screen.
  final bool showVehiclePanel;

  /// Damage schematic of the real vehicle structure (with the mod's
  /// skeleton): engine, radiator and fuel tank / battery pictograms, and
  /// brakes, tyres and axles ones. Hiding the first lets the user hide the
  /// second too, for the bare structure like the game's detailed app.
  /// The 0.0.3 damage schematic (six body zones, four tyres) even when
  /// the real vehicle structure is known.
  final bool simpleDamage;
  final bool damageCarParts;
  final bool damageWheelParts;

  /// Display-only phone: dashboard, radar and damage, no controls.
  final bool secondScreen;

  // Gameplay --------------------------------------------------------------------

  /// Tilt the phone to steer, otherwise slide a finger on a bar.
  final bool tiltSteering;
  final double rotationRangeDeg;
  final bool invertSteering;

  /// Filters the accelerometer jitter ("shake reduction").
  final bool steeringSmoothing;
  final bool pitchGearShift;

  /// Vibrations: wheelspin, locked wheels, impacts, kerbs, rev limiter.
  final bool hapticSpin;
  final bool hapticLock;
  final bool hapticImpacts;
  final bool hapticKerbs;
  final bool hapticLimiter;
  final bool hapticAbs;

  /// Strength of every vibration, [minHapticStrength]..1.
  final double hapticStrength;

  // Controls --------------------------------------------------------------------

  /// Volume up = horn, volume down = headlight flash (while held).
  final bool hornOnVolume;
  final bool flashOnVolume;
  final bool showActionsBar;

  /// Vehicle buttons (VehicleAction names) hidden by the user.
  final Set<String> hiddenActions;

  // Advanced --------------------------------------------------------------------

  final bool debugMode;

  /// Presets offered next to a custom value.
  static const List<double> rotationRanges = [360, 540, 720, 900];
  static const double minRotationRange = 90;
  static const double maxRotationRange = 2520;

  const AppSettings({
    this.themeName = 'Default',
    this.localeCode,
    this.useKmh = true,
    this.temperatureUnit = TemperatureUnit.celsius,
    this.pressureUnit = PressureUnit.bar,
    this.warningPopups = true,
    this.showVehiclePanel = false,
    this.simpleDamage = false,
    this.damageCarParts = false,
    this.damageWheelParts = true,
    this.secondScreen = false,
    this.tiltSteering = true,
    this.rotationRangeDeg = 900,
    this.invertSteering = true,
    this.steeringSmoothing = true,
    this.pitchGearShift = false,
    this.hapticSpin = true,
    this.hapticLock = true,
    this.hapticImpacts = true,
    this.hapticKerbs = true,
    this.hapticLimiter = false,
    this.hapticAbs = true,
    this.hapticStrength = 1,
    this.hornOnVolume = true,
    this.flashOnVolume = true,
    this.showActionsBar = true,
    this.hiddenActions = const {},
    this.debugMode = false,
  });

  /// Some road-feel vibration is enabled.
  bool get anyRoadHaptics => hapticSpin || hapticLock || hapticImpacts || hapticKerbs || hapticAbs;

  /// Brakes, tyres and axles can only be hidden with the engine   bool get anyRoadHaptics => hapticSpin || hapticLock || hapticImpacts || hapticKerbs || hapticAbs; co.
  bool get showsDamageWheelParts => damageCarParts || damageWheelParts;

  static const double minHapticStrength = 0.1;

  // Sentinel so copyWith can set localeCode back to null (system language).
  static const Object _keep = Object();

  AppSettings copyWith({
    String? themeName,
    Object? localeCode = _keep,
    bool? useKmh,
    TemperatureUnit? temperatureUnit,
    PressureUnit? pressureUnit,
    bool? warningPopups,
    bool? showVehiclePanel,
    bool? simpleDamage,
    bool? damageCarParts,
    bool? damageWheelParts,
    bool? secondScreen,
    bool? tiltSteering,
    double? rotationRangeDeg,
    bool? invertSteering,
    bool? steeringSmoothing,
    bool? pitchGearShift,
    bool? hapticSpin,
    bool? hapticLock,
    bool? hapticImpacts,
    bool? hapticKerbs,
    bool? hapticLimiter,
    bool? hapticAbs,
    double? hapticStrength,
    bool? hornOnVolume,
    bool? flashOnVolume,
    bool? showActionsBar,
    Set<String>? hiddenActions,
    bool? debugMode,
  }) {
    return AppSettings(
      themeName: themeName ?? this.themeName,
      localeCode: identical(localeCode, _keep) ? this.localeCode : localeCode as String?,
      useKmh: useKmh ?? this.useKmh,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      pressureUnit: pressureUnit ?? this.pressureUnit,
      warningPopups: warningPopups ?? this.warningPopups,
      showVehiclePanel: showVehiclePanel ?? this.showVehiclePanel,
      simpleDamage: simpleDamage ?? this.simpleDamage,
      damageCarParts: damageCarParts ?? this.damageCarParts,
      damageWheelParts: damageWheelParts ?? this.damageWheelParts,
      secondScreen: secondScreen ?? this.secondScreen,
      tiltSteering: tiltSteering ?? this.tiltSteering,
      rotationRangeDeg: rotationRangeDeg ?? this.rotationRangeDeg,
      invertSteering: invertSteering ?? this.invertSteering,
      steeringSmoothing: steeringSmoothing ?? this.steeringSmoothing,
      pitchGearShift: pitchGearShift ?? this.pitchGearShift,
      hapticSpin: hapticSpin ?? this.hapticSpin,
      hapticLock: hapticLock ?? this.hapticLock,
      hapticImpacts: hapticImpacts ?? this.hapticImpacts,
      hapticKerbs: hapticKerbs ?? this.hapticKerbs,
      hapticLimiter: hapticLimiter ?? this.hapticLimiter,
      hapticAbs: hapticAbs ?? this.hapticAbs,
      hapticStrength: hapticStrength ?? this.hapticStrength,
      hornOnVolume: hornOnVolume ?? this.hornOnVolume,
      flashOnVolume: flashOnVolume ?? this.flashOnVolume,
      showActionsBar: showActionsBar ?? this.showActionsBar,
      hiddenActions: hiddenActions ?? this.hiddenActions,
      debugMode: debugMode ?? this.debugMode,
    );
  }

  Map<String, Object?> toJson() => {
        'themeName': themeName,
        'localeCode': localeCode,
        'useKmh': useKmh,
        'temperatureUnit': temperatureUnit.name,
        'pressureUnit': pressureUnit.name,
        'warningPopups': warningPopups,
        'showVehiclePanel': showVehiclePanel,
        'simpleDamage': simpleDamage,
        'damageCarParts': damageCarParts,
        'damageWheelParts': damageWheelParts,
        'secondScreen': secondScreen,
        'tiltSteering': tiltSteering,
        'rotationRangeDeg': rotationRangeDeg,
        'invertSteering': invertSteering,
        'steeringSmoothing': steeringSmoothing,
        'pitchGearShift': pitchGearShift,
        'hapticSpin': hapticSpin,
        'hapticLock': hapticLock,
        'hapticImpacts': hapticImpacts,
        'hapticKerbs': hapticKerbs,
        'hapticLimiter': hapticLimiter,
        'hapticAbs': hapticAbs,
        'hapticStrength': hapticStrength,
        'hornOnVolume': hornOnVolume,
        'flashOnVolume': flashOnVolume,
        'showActionsBar': showActionsBar,
        'hiddenActions': hiddenActions.toList()..sort(),
        'debugMode': debugMode,
      };

  /// Missing or wrongly typed values fall back to the defaults, so settings
  /// saved by an older app version always load. Settings of version 0.0.3
  /// (one switch for the volume buttons, one for every road vibration, a
  /// shift-point vibration) carry over to their replacements.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    const d = AppSettings();
    T pick<T>(String key, T fallback) {
      final v = json[key];
      return v is T ? v : fallback;
    }

    final range = json['rotationRangeDeg'];
    final rotation = range is num && range >= minRotationRange && range <= maxRotationRange ? range.toDouble() : d.rotationRangeDeg;
    final volumeKeys = pick('volumeKeys', true);
    final roadHaptics = pick('roadHaptics', true);
    final strength = json['hapticStrength'];
    return AppSettings(
      themeName: pick('themeName', d.themeName),
      localeCode: json['localeCode'] is String ? json['localeCode'] as String : null,
      useKmh: pick('useKmh', d.useKmh),
      temperatureUnit: enumByName(TemperatureUnit.values, json['temperatureUnit'], d.temperatureUnit),
      pressureUnit: enumByName(PressureUnit.values, json['pressureUnit'], d.pressureUnit),
      warningPopups: pick('warningPopups', d.warningPopups),
      showVehiclePanel: pick('showVehiclePanel', d.showVehiclePanel),
      simpleDamage: pick('simpleDamage', d.simpleDamage),
      damageCarParts: pick('damageCarParts', d.damageCarParts),
      damageWheelParts: pick('damageWheelParts', d.damageWheelParts),
      secondScreen: pick('secondScreen', d.secondScreen),
      tiltSteering: pick('tiltSteering', d.tiltSteering),
      rotationRangeDeg: rotation,
      invertSteering: pick('invertSteering', d.invertSteering),
      steeringSmoothing: pick('steeringSmoothing', d.steeringSmoothing),
      pitchGearShift: pick('pitchGearShift', d.pitchGearShift),
      hapticSpin: pick('hapticSpin', roadHaptics),
      hapticLock: pick('hapticLock', roadHaptics),
      hapticImpacts: pick('hapticImpacts', roadHaptics),
      hapticKerbs: pick('hapticKerbs', roadHaptics),
      hapticLimiter: pick('hapticLimiter', pick('shiftHaptics', d.hapticLimiter)),
      hapticAbs: pick('hapticAbs', roadHaptics),
      hapticStrength: strength is num && strength >= minHapticStrength && strength <= 1 ? strength.toDouble() : d.hapticStrength,
      hornOnVolume: pick('hornOnVolume', volumeKeys),
      flashOnVolume: pick('flashOnVolume', volumeKeys),
      showActionsBar: pick('showActionsBar', d.showActionsBar),
      hiddenActions: json['hiddenActions'] is List
          ? {for (final a in json['hiddenActions']! as List<Object?>) if (a is String) a}
          : d.hiddenActions,
      debugMode: pick('debugMode', d.debugMode),
    );
  }
}
