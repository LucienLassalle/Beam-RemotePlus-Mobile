import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/settings/settings_scope.dart';
import '../../l10n/generated/app_localizations.dart';

const appRepositoryUrl = 'https://github.com/LucienLassalle/Beam-RemotePlus-Mobile';
const modRepositoryUrl = 'https://github.com/LucienLassalle/Beam-RemotePlus-Mod';

Future<void> showHelpSheet(BuildContext context) {
  final settings = SettingsScope.read(context).settings;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Text(l10n.helpTitle, style: Theme.of(context).textTheme.titleMedium)),
            const SizedBox(height: 12),
            _HelpRow(Icons.swipe_up, Colors.redAccent, l10n.helpBrake, l10n.helpBrakeDesc),
            _HelpRow(Icons.swipe_up, Colors.greenAccent, l10n.helpThrottle, l10n.helpThrottleDesc),
            if (settings.tiltSteering)
              _HelpRow(Icons.screen_rotation, Colors.blueAccent, l10n.helpSteeringTilt, l10n.helpSteeringTiltDesc)
            else
              _HelpRow(Icons.drag_handle, Colors.blueAccent, l10n.helpSteeringTouch, l10n.helpSteeringTouchDesc),
            if (settings.tiltSteering && settings.pitchGearShift)
              _HelpRow(Icons.swap_vert, Colors.cyanAccent, l10n.helpGearPitch, l10n.helpGearPitchDesc, modRequired: true),
            if (settings.hornOnVolume || settings.flashOnVolume)
              _HelpRow(Icons.volume_up, Colors.amberAccent, l10n.helpVolumeKeys, l10n.helpVolumeKeysDesc, modRequired: true),
            _HelpRow(Icons.skip_next, Colors.white54, l10n.helpVehicle, l10n.helpVehicleDesc, modRequired: true),
            _HelpRow(Icons.flip_camera_android, Colors.white54, l10n.helpCamera, l10n.helpCameraDesc, modRequired: true),
            _HelpRow(Icons.restart_alt, Colors.orangeAccent, l10n.helpResetVehicle, l10n.helpResetVehicleDesc, modRequired: true),
            const Divider(height: 24),
            Text(l10n.helpOpenSourceTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Text(l10n.helpContributions, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              _LinkChip(label: l10n.helpAppRepo, url: appRepositoryUrl),
              _LinkChip(label: l10n.helpModRepo, url: modRepositoryUrl),
            ]),
          ]),
        ),
      );
    },
  );
}

/// Opens a GitHub repository in the browser; copies the link when no
/// browser can open it.
class _LinkChip extends StatelessWidget {
  final String label;
  final String url;
  const _LinkChip({required this.label, required this.url});

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = AppLocalizations.of(context).helpLinkCopied;
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on PlatformException {
      opened = false;
    }
    if (opened) return;
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: const Icon(Icons.open_in_new, size: 16),
        label: Text(label),
        tooltip: url,
        onPressed: () => unawaited(_open(context)),
      );
}

class _HelpRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final bool modRequired;

  const _HelpRow(this.icon, this.color, this.title, this.description, {this.modRequired = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (modRequired)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4)),
                    child: Text(AppLocalizations.of(context).helpModRequired,
                        style: const TextStyle(fontSize: 9, color: Colors.white38)),
                  ),
              ]),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ]),
          ),
        ]),
      );
}
