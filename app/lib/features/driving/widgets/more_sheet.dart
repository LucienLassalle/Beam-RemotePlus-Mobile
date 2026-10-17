import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/protocol/vehicle_command.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../driving_controller.dart';

/// "More" sheet of the Road theme: every other command of the vehicle (fog
/// lights, 4WD, nitrous, trailer, tailgate, crane, vehicle mods...), as the
/// mod lists them for the vehicle the phone drives. The buttons of the
/// driving screen are never repeated here.
Future<void> showMoreSheet(BuildContext context, DrivingController controller) {
  controller.requestMoreCommands();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (_) => _MoreSheet(controller: controller),
  );
}

/// Title and icon of a generic command (titles of the vehicle's own actions
/// come from the game).
(String, IconData) genericCommandLabel(AppLocalizations l10n, String id) => switch (id) {
      'fog_lights' => (l10n.moreFogLights, Icons.foggy),
      'four_wd' => (l10n.moreFourWd, Icons.all_inclusive),
      'range' => (l10n.moreRange, Icons.terrain),
      'diff_lock' => (l10n.moreDiffLock, Icons.lock),
      'two_step' => (l10n.moreTwoStep, Icons.rocket_launch),
      'transbrake' => (l10n.moreTransbrake, Icons.pause_circle_outline),
      'line_lock' => (l10n.moreLineLock, Icons.lock_clock),
      'nitrous' => (l10n.moreNitrous, Icons.local_fire_department),
      'lightbar_mode' => (l10n.moreLightbarMode, Icons.emergency),
      'couplers' => (l10n.moreCouplers, Icons.rv_hookup),
      _ => (id, Icons.tune),
    };

class _MoreSheet extends StatefulWidget {
  final DrivingController controller;
  const _MoreSheet({required this.controller});

  /// Without an answer by then, the mod is too old to list the commands.
  static const answerTimeout = Duration(seconds: 3);

  @override
  State<_MoreSheet> createState() => _MoreSheetState();
}

class _MoreSheetState extends State<_MoreSheet> {
  late final Timer _timeout;
  bool _late = false;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(_MoreSheet.answerTimeout, () {
      if (mounted) setState(() => _late = true);
    });
  }

  @override
  void dispose() {
    _timeout.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final answer = widget.controller.moreCommands;
        final Widget body;
        if (answer == null) {
          body = _late
              ? Text(l10n.moreNoAnswer, style: const TextStyle(color: Colors.white54))
              : const Center(child: CircularProgressIndicator());
        } else if (answer.commands.isEmpty) {
          body = Text(l10n.moreNothing, style: const TextStyle(color: Colors.white54));
        } else {
          body = Wrap(spacing: 8, runSpacing: 8, children: [
            for (final command in answer.commands) _CommandButton(controller: widget.controller, command: command),
          ]);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Text(l10n.moreTitle, style: Theme.of(context).textTheme.titleMedium)),
            const SizedBox(height: 12),
            body,
          ]),
        );
      },
    );
  }
}

/// A command: a tap for a single press, held for a held command (crane,
/// winch...), which shows it is down while held.
class _CommandButton extends StatefulWidget {
  final DrivingController controller;
  final VehicleCommand command;
  const _CommandButton({required this.controller, required this.command});

  @override
  State<_CommandButton> createState() => _CommandButtonState();
}

class _CommandButtonState extends State<_CommandButton> {
  bool _down = false;

  void _hold(bool pressed) {
    setState(() => _down = pressed);
    if (pressed) HapticFeedback.selectionClick();
    widget.controller.holdMore(widget.command, pressed: pressed);
  }

  @override
  void dispose() {
    if (_down) widget.controller.holdMore(widget.command, pressed: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final command = widget.command;
    final generic = command.genericId;
    final (label, icon) = generic != null ? genericCommandLabel(l10n, generic) : (command.title ?? command.id, Icons.tune);
    final enabled = widget.controller.commandsEnabled;
    final button = command.hold
        ? Listener(
            onPointerDown: enabled ? (_) => _hold(true) : null,
            onPointerUp: enabled ? (_) => _hold(false) : null,
            onPointerCancel: enabled ? (_) => _hold(false) : null,
            child: FilledButton.tonalIcon(
              onPressed: enabled ? () {} : null,
              icon: Icon(icon),
              label: Text(label),
              style: _down ? FilledButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black) : null,
            ),
          )
        : FilledButton.tonalIcon(
            onPressed: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    widget.controller.pressMore(command);
                  }
                : null,
            icon: Icon(icon),
            label: Text(label),
          );
    return Tooltip(message: command.hold ? l10n.moreHoldHint : label, child: button);
  }
}
