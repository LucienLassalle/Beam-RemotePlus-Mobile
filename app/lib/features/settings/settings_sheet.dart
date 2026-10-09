import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/platform/vibrator.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_scope.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../themes/control_theme.dart';
import '../../themes/kit/sample_telemetry.dart';
import '../../themes/theme_registry.dart';
import '../driving/tilt_steering.dart';
import '../driving/widgets/vehicle_actions_bar.dart';

/// Opens the settings sheet of the driving screen: the two actions used
/// while driving on top (recalibrate, pause the controls), then one tab per
/// group. Settings are saved on the phone as soon as they change; pausing
/// the controls lives only for this session.
Future<void> showSettingsSheet(
  BuildContext context, {
  required bool readOnly,
  required ValueChanged<bool> onReadOnlyChanged,
  required VoidCallback onRecalibrate,
}) {
  final controller = SettingsScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Full width: Material 3 caps sheets at 640 px, too narrow in landscape.
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (_) => SettingsScope(
      controller: controller,
      child: _SettingsSheet(readOnly: readOnly, onReadOnlyChanged: onReadOnlyChanged, onRecalibrate: onRecalibrate),
    ),
  );
}

class _SettingsSheet extends StatefulWidget {
  final bool readOnly;
  final ValueChanged<bool> onReadOnlyChanged;
  final VoidCallback onRecalibrate;
  const _SettingsSheet({required this.readOnly, required this.onReadOnlyChanged, required this.onRecalibrate});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late bool _readOnly = widget.readOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = SettingsScope.of(context).settings;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.95,
      child: DefaultTabController(
        length: 4,
        child: Column(children: [
          // One line, so the tabs keep the height of a phone in landscape.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
            child: Row(children: [
              Text(l10n.settingsTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 16),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Flexible(
                    child: Tooltip(
                      message: l10n.settingsRecalibrateSubtitle,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.my_location, size: 18),
                        label: Text(l10n.settingsRecalibrateTitle, overflow: TextOverflow.ellipsis),
                        onPressed: s.tiltSteering
                            ? () {
                                widget.onRecalibrate();
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsRecalibrateDone)));
                              }
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Tooltip(
                      message: l10n.settingsReadOnlySubtitle,
                      child: FilterChip(
                        avatar: const Icon(Icons.pause_circle_outline, size: 18),
                        label: Text(l10n.settingsReadOnlyTitle, overflow: TextOverflow.ellipsis),
                        selected: _readOnly,
                        onSelected: (v) {
                          setState(() => _readOnly = v);
                          widget.onReadOnlyChanged(v);
                        },
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          TabBar(tabs: [
            Tab(text: l10n.settingsSectionDisplay),
            Tab(text: l10n.settingsSectionGameplay),
            Tab(text: l10n.settingsSectionControls),
            Tab(text: l10n.settingsSectionAdvanced),
          ]),
          const Expanded(
            child: TabBarView(children: [_DisplayTab(), _GameplayTab(), _ControlsTab(), _AdvancedTab()]),
          ),
        ]),
      ),
    );
  }
}

/// Saves a change of the settings (persisted on the phone).
void _set(BuildContext context, AppSettings Function(AppSettings) change) => unawaited(SettingsScope.read(context).update(change));

Widget _switch(String title, String? subtitle, bool value, ValueChanged<bool>? onChanged) => SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: onChanged,
    );

class _Tab extends StatelessWidget {
  final List<Widget> children;
  const _Tab(this.children);

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(8, 4, 8, 24), children: children);
}

class _DisplayTab extends StatelessWidget {
  const _DisplayTab();

  static String _languageName(String code) => switch (code) {
        'fr' => 'Français',
        'en' => 'English',
        _ => code,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = SettingsScope.of(context).settings;
    return _Tab([
      ListTile(
        title: Text(l10n.settingsLanguageTitle),
        trailing: DropdownButton<String>(
          value: s.localeCode ?? '',
          items: [
            DropdownMenuItem(value: '', child: Text(l10n.settingsLanguageSystem)),
            for (final locale in AppLocalizations.supportedLocales)
              DropdownMenuItem(value: locale.languageCode, child: Text(_languageName(locale.languageCode))),
          ],
          onChanged: (code) => _set(context, (s) => s.copyWith(localeCode: code == null || code.isEmpty ? null : code)),
        ),
      ),
      ListTile(
        title: Text(l10n.settingsUnitTitle),
        trailing: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('km/h')),
            ButtonSegment(value: false, label: Text('mph')),
          ],
          selected: {s.useKmh},
          onSelectionChanged: (v) => _set(context, (s) => s.copyWith(useKmh: v.first)),
        ),
      ),
      ListTile(
        title: Text(l10n.settingsTemperatureUnitTitle),
        trailing: SegmentedButton<TemperatureUnit>(
          segments: [for (final u in TemperatureUnit.values) ButtonSegment(value: u, label: Text(u.symbol))],
          selected: {s.temperatureUnit},
          onSelectionChanged: (v) => _set(context, (s) => s.copyWith(temperatureUnit: v.first)),
        ),
      ),
      ListTile(
        title: Text(l10n.settingsPressureUnitTitle),
        trailing: SegmentedButton<PressureUnit>(
          segments: [for (final u in PressureUnit.values) ButtonSegment(value: u, label: Text(u.symbol))],
          selected: {s.pressureUnit},
          onSelectionChanged: (v) => _set(context, (s) => s.copyWith(pressureUnit: v.first)),
        ),
      ),
      ListTile(
        title: Text(l10n.settingsThemeTitle),
        subtitle: DropdownButton<String>(
          isExpanded: true,
          itemHeight: 76,
          value: themeByName(s.themeName).name,
          items: [
            for (final theme in availableThemes) DropdownMenuItem(value: theme.name, child: _ThemeOption(theme: theme)),
          ],
          onChanged: (name) {
            if (name != null) _set(context, (s) => s.copyWith(themeName: name));
          },
        ),
      ),
      _switch(l10n.settingsWarningsTitle, l10n.settingsWarningsSubtitle, s.warningPopups,
          (v) => _set(context, (s) => s.copyWith(warningPopups: v))),
      _switch(l10n.settingsVehiclePanelTitle, l10n.settingsVehiclePanelSubtitle, s.showVehiclePanel,
          (v) => _set(context, (s) => s.copyWith(showVehiclePanel: v))),
      _switch(l10n.settingsSimpleDamageTitle, l10n.settingsSimpleDamageSubtitle, s.simpleDamage,
          (v) => _set(context, (s) => s.copyWith(simpleDamage: v))),
      // The pictograms only exist on the real structure.
      _switch(l10n.settingsDamageCarPartsTitle, l10n.settingsDamageCarPartsSubtitle, s.damageCarParts,
          s.simpleDamage ? null : (v) => _set(context, (s) => s.copyWith(damageCarParts: v))),
      // Only with the engine & co. hidden; shown on (greyed) otherwise.
      _switch(
        l10n.settingsDamageWheelPartsTitle,
        l10n.settingsDamageWheelPartsSubtitle,
        s.showsDamageWheelParts,
        s.damageCarParts || s.simpleDamage ? null : (v) => _set(context, (s) => s.copyWith(damageWheelParts: v)),
      ),
      _switch(l10n.settingsSecondScreenTitle, l10n.settingsSecondScreenSubtitle, s.secondScreen,
          (v) => _set(context, (s) => s.copyWith(secondScreen: v))),
    ]);
  }
}

/// A theme in the theme list: live preview of its dashboard + name.
class _ThemeOption extends StatelessWidget {
  final ControlTheme theme;
  const _ThemeOption({required this.theme});

  @override
  Widget build(BuildContext context) => Row(children: [
        ThemePreview(theme: theme, width: 150),
        const SizedBox(width: 12),
        Flexible(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(theme.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('@${theme.author}', style: const TextStyle(fontSize: 11, color: Colors.white38)),
          ]),
        ),
      ]);
}

/// Miniature of a theme's dashboard with sample telemetry, drawn live (no
/// screenshot to keep up to date).
class ThemePreview extends StatelessWidget {
  final ControlTheme theme;
  final double width;

  /// Size of the dashboard on a typical phone in landscape (logical px).
  static const Size dashboardSize = Size(900, 308);

  const ThemePreview({super.key, required this.theme, required this.width});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: width,
          height: width * dashboardSize.height / dashboardSize.width,
          child: ColoredBox(
            color: theme.style.background,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: FittedBox(
                  child: SizedBox.fromSize(
                    size: dashboardSize,
                    child: theme.buildDashboard(
                      context,
                      const DashboardData(telemetry: sampleTelemetry, modActive: true, useKmh: true),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _GameplayTab extends StatelessWidget {
  const _GameplayTab();

  Future<void> _customRange(BuildContext context, double current) async {
    final value = await showDialog<double>(context: context, builder: (_) => _RotationRangeDialog(current: current));
    if (value != null && context.mounted) _set(context, (s) => s.copyWith(rotationRangeDeg: value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = SettingsScope.of(context).settings;
    final custom = !AppSettings.rotationRanges.contains(s.rotationRangeDeg);
    return _Tab([
      ListTile(
        title: Text(l10n.settingsDrivingModeTitle),
        trailing: SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, icon: const Icon(Icons.screen_rotation), label: Text(l10n.settingsDrivingModeTilt)),
            ButtonSegment(value: false, icon: const Icon(Icons.swipe), label: Text(l10n.settingsDrivingModeSlide)),
          ],
          selected: {s.tiltSteering},
          onSelectionChanged: (v) => _set(context, (s) => s.copyWith(tiltSteering: v.first)),
        ),
      ),
      ListTile(
        title: Text(l10n.settingsRotationRangeTitle),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.settingsRotationRangeSubtitle),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final r in AppSettings.rotationRanges)
              ChoiceChip(
                label: Text('${r.round()}°'),
                selected: s.rotationRangeDeg == r,
                onSelected: (_) => _set(context, (s) => s.copyWith(rotationRangeDeg: r)),
              ),
            ChoiceChip(
              label: Text(custom ? '${s.rotationRangeDeg.round()}°' : l10n.settingsRotationRangeCustom),
              avatar: const Icon(Icons.edit, size: 16),
              selected: custom,
              onSelected: (_) => unawaited(_customRange(context, s.rotationRangeDeg)),
            ),
          ]),
          Text(l10n.settingsRotationRangeHint(TiltSteering.maxTiltDegFor(s.rotationRangeDeg).round()),
              style: const TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
      ),
      _switch(l10n.settingsInvertTitle, null, s.invertSteering, (v) => _set(context, (s) => s.copyWith(invertSteering: v))),
      _switch(l10n.settingsSmoothingTitle, l10n.settingsSmoothingSubtitle, s.steeringSmoothing,
          s.tiltSteering ? (v) => _set(context, (s) => s.copyWith(steeringSmoothing: v)) : null),
      _switch(l10n.settingsPitchGearTitle, l10n.settingsPitchGearSubtitle, s.pitchGearShift,
          s.tiltSteering ? (v) => _set(context, (s) => s.copyWith(pitchGearShift: v)) : null),
      ExpansionTile(
        leading: const Icon(Icons.vibration),
        title: Text(l10n.settingsVibrationsTitle),
        subtitle: Text(l10n.settingsVibrationsSubtitle),
        children: [
          _switch(l10n.settingsHapticSpin, null, s.hapticSpin, (v) => _set(context, (s) => s.copyWith(hapticSpin: v))),
          _switch(l10n.settingsHapticLock, null, s.hapticLock, (v) => _set(context, (s) => s.copyWith(hapticLock: v))),
          _switch(l10n.settingsHapticImpacts, null, s.hapticImpacts, (v) => _set(context, (s) => s.copyWith(hapticImpacts: v))),
          _switch(l10n.settingsHapticKerbs, null, s.hapticKerbs, (v) => _set(context, (s) => s.copyWith(hapticKerbs: v))),
          _switch(l10n.settingsHapticAbs, null, s.hapticAbs, (v) => _set(context, (s) => s.copyWith(hapticAbs: v))),
          _switch(l10n.settingsHapticLimiter, null, s.hapticLimiter, (v) => _set(context, (s) => s.copyWith(hapticLimiter: v))),
          ListTile(
            title: Text(l10n.settingsHapticStrength),
            subtitle: Slider(
              value: s.hapticStrength,
              min: AppSettings.minHapticStrength,
              divisions: 9,
              label: '${(s.hapticStrength * 100).round()} %',
              onChanged: (v) => _set(context, (s) => s.copyWith(hapticStrength: v)),
              // Lets the user feel the new strength.
              onChangeEnd: (v) => unawaited(Vibrator.pulse(80, (255 * v).round())),
            ),
            trailing: Text('${(s.hapticStrength * 100).round()} %'),
          ),
        ],
      ),
    ]);
  }
}

/// Custom wheel rotation range, in degrees.
class _RotationRangeDialog extends StatefulWidget {
  final double current;
  const _RotationRangeDialog({required this.current});

  @override
  State<_RotationRangeDialog> createState() => _RotationRangeDialogState();
}

class _RotationRangeDialogState extends State<_RotationRangeDialog> {
  late final TextEditingController _text = TextEditingController(text: '${widget.current.round()}');
  bool _invalid = false;

  static final int _min = AppSettings.minRotationRange.round();
  static final int _max = AppSettings.maxRotationRange.round();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_text.text.trim());
    if (v == null || v < _min || v > _max) {
      setState(() => _invalid = true);
    } else {
      Navigator.of(context).pop(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hint = l10n.settingsRotationRangeDialogHint(_min, _max);
    return AlertDialog(
      title: Text(l10n.settingsRotationRangeTitle),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(suffixText: '°', helperText: hint, errorText: _invalid ? hint : null),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.settingsCancel)),
        TextButton(onPressed: _submit, child: Text(l10n.settingsOk)),
      ],
    );
  }
}

class _ControlsTab extends StatelessWidget {
  const _ControlsTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = SettingsScope.of(context).settings;
    final actions = themeByName(s.themeName).style.actions;
    return _Tab([
      _switch(l10n.settingsHornVolumeTitle, l10n.settingsHornVolumeSubtitle, !s.hornOnVolume,
          (v) => _set(context, (s) => s.copyWith(hornOnVolume: !v))),
      _switch(l10n.settingsFlashVolumeTitle, l10n.settingsFlashVolumeSubtitle, !s.flashOnVolume,
          (v) => _set(context, (s) => s.copyWith(flashOnVolume: !v))),
      if (actions.isNotEmpty) ...[
        _switch(l10n.settingsActionsBarTitle, l10n.settingsActionsBarSubtitle, s.showActionsBar,
            (v) => _set(context, (s) => s.copyWith(showActionsBar: v))),
        if (s.showActionsBar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              for (final a in actions)
                FilterChip(
                  label: Text(vehicleActionLabel(l10n, a)),
                  selected: !s.hiddenActions.contains(a.name),
                  onSelected: (visible) => _set(
                    context,
                    (s) => s.copyWith(hiddenActions: visible ? (s.hiddenActions.toSet()..remove(a.name)) : {...s.hiddenActions, a.name}),
                  ),
                ),
            ]),
          ),
      ],
    ]);
  }
}

class _AdvancedTab extends StatelessWidget {
  const _AdvancedTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = SettingsScope.of(context).settings;
    return _Tab([
      _switch(l10n.settingsDebugTitle, l10n.settingsDebugSubtitle, s.debugMode, (v) => _set(context, (s) => s.copyWith(debugMode: v))),
    ]);
  }
}
