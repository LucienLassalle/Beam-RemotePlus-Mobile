import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_scope.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../themes/theme_registry.dart';
import '../driving/tilt_steering.dart';
import '../driving/widgets/vehicle_actions_bar.dart';

/// Opens the settings bottom sheet of the driving screen. Settings are saved
/// as soon as they change; read-only mode lives only for this session.
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
    final controller = SettingsScope.of(context);
    final s = controller.settings;
    void set(AppSettings Function(AppSettings) change) => unawaited(controller.update(change));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
        children: [
          Center(child: Text(l10n.settingsTitle, style: Theme.of(context).textTheme.titleMedium)),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: Text(l10n.settingsReadOnlyTitle),
            subtitle: Text(l10n.settingsReadOnlySubtitle),
            value: _readOnly,
            onChanged: (v) {
              setState(() => _readOnly = v);
              widget.onReadOnlyChanged(v);
            },
          ),
          _Section(l10n.settingsSectionDisplay),
          _ChoiceTile(
            title: l10n.settingsThemeTitle,
            subtitle: l10n.settingsThemeSubtitle,
            options: {for (final t in availableThemes) t.name: t.name},
            selected: s.themeName,
            onSelected: (name) => set((s) => s.copyWith(themeName: name)),
          ),
          _ChoiceTile(
            title: l10n.settingsLanguageTitle,
            options: {
              '': l10n.settingsLanguageSystem,
              for (final locale in AppLocalizations.supportedLocales) locale.languageCode: _languageName(locale.languageCode),
            },
            selected: s.localeCode ?? '',
            onSelected: (code) => set((s) => s.copyWith(localeCode: code.isEmpty ? null : code)),
          ),
          _switch(l10n.settingsUnitTitle, l10n.settingsUnitSubtitle, s.useKmh, (v) => set((s) => s.copyWith(useKmh: v))),
          _switch(l10n.settingsWarningsTitle, l10n.settingsWarningsSubtitle, s.warningPopups,
              (v) => set((s) => s.copyWith(warningPopups: v))),
          _switch(l10n.settingsVehiclePanelTitle, l10n.settingsVehiclePanelSubtitle, s.showVehiclePanel,
              (v) => set((s) => s.copyWith(showVehiclePanel: v))),
          if (themeByName(s.themeName).style.actions.isNotEmpty) ...[
            _switch(l10n.settingsActionsBarTitle, l10n.settingsActionsBarSubtitle, s.showActionsBar,
                (v) => set((s) => s.copyWith(showActionsBar: v))),
            if (s.showActionsBar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final a in themeByName(s.themeName).style.actions)
                    FilterChip(
                      label: Text(vehicleActionLabel(l10n, a)),
                      selected: !s.hiddenActions.contains(a.name),
                      onSelected: (visible) => set((s) => s.copyWith(
                            hiddenActions: visible ? (s.hiddenActions.toSet()..remove(a.name)) : {...s.hiddenActions, a.name},
                          )),
                    ),
                ]),
              ),
          ],
          _Section(l10n.settingsSectionSteering),
          _switch(l10n.settingsTiltTitle, l10n.settingsTiltSubtitle, s.tiltSteering, (v) => set((s) => s.copyWith(tiltSteering: v))),
          _ChoiceTile(
            title: l10n.settingsRotationRangeTitle,
            subtitle: l10n.settingsRotationRangeSubtitle,
            footer: l10n.settingsRotationRangeHint(TiltSteering.maxTiltDegFor(s.rotationRangeDeg).round()),
            options: {for (final r in AppSettings.rotationRanges) '$r': '${r.round()}°'},
            selected: '${s.rotationRangeDeg}',
            onSelected: (r) => set((s) => s.copyWith(rotationRangeDeg: double.parse(r))),
          ),
          _switch(l10n.settingsInvertTitle, null, s.invertSteering, (v) => set((s) => s.copyWith(invertSteering: v))),
          _switch(l10n.settingsSmoothingTitle, l10n.settingsSmoothingSubtitle, s.steeringSmoothing,
              s.tiltSteering ? (v) => set((s) => s.copyWith(steeringSmoothing: v)) : null),
          ListTile(
            title: Text(l10n.settingsRecalibrateTitle),
            subtitle: Text(l10n.settingsRecalibrateSubtitle),
            trailing: const Icon(Icons.my_location),
            enabled: s.tiltSteering,
            onTap: () {
              widget.onRecalibrate();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsRecalibrateDone)));
            },
          ),
          _Section(l10n.settingsSectionControls),
          _switch(l10n.settingsVolumeKeysTitle, l10n.settingsVolumeKeysSubtitle, s.volumeKeys,
              (v) => set((s) => s.copyWith(volumeKeys: v))),
          _switch(l10n.settingsPitchGearTitle, l10n.settingsPitchGearSubtitle, s.pitchGearShift,
              s.tiltSteering ? (v) => set((s) => s.copyWith(pitchGearShift: v)) : null),
          _switch(l10n.settingsRoadHapticsTitle, l10n.settingsRoadHapticsSubtitle, s.roadHaptics,
              (v) => set((s) => s.copyWith(roadHaptics: v))),
          _switch(l10n.settingsHapticsTitle, l10n.settingsHapticsSubtitle, s.shiftHaptics,
              (v) => set((s) => s.copyWith(shiftHaptics: v))),
          _Section(l10n.settingsSectionAdvanced),
          _switch(l10n.secondScreenTitle, l10n.settingsSecondScreenSubtitle, s.secondScreen,
              (v) => set((s) => s.copyWith(secondScreen: v))),
          _switch(l10n.settingsDebugTitle, l10n.settingsDebugSubtitle, s.debugMode, (v) => set((s) => s.copyWith(debugMode: v))),
        ],
      ),
    );
  }

  static String _languageName(String code) => switch (code) {
        'fr' => 'Français',
        'en' => 'English',
        _ => code,
      };

  Widget _switch(String title, String? subtitle, bool value, ValueChanged<bool>? onChanged) => SwitchListTile(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        value: value,
        onChanged: onChanged,
      );
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white38, letterSpacing: 1.2)),
      );
}

class _ChoiceTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? footer;
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _ChoiceTile({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.subtitle,
    this.footer,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (subtitle != null) Text(subtitle!),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: entry.key == selected,
                onSelected: (_) => onSelected(entry.key),
              ),
          ]),
          if (footer != null) Text(footer!, style: const TextStyle(fontSize: 11, color: Colors.white38)),
        ]),
      );
}
