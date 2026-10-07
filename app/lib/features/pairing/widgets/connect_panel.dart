import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../pairing_controller.dart';

/// Bottom panel of the pairing screen: status, error, automatic connection
/// and manual code entry.
class ConnectPanel extends StatefulWidget {
  final PairingController controller;
  final VoidCallback onAutoConnect;
  final ValueChanged<String> onSubmitCode;

  const ConnectPanel({super.key, required this.controller, required this.onAutoConnect, required this.onSubmitCode});

  @override
  State<ConnectPanel> createState() => _ConnectPanelState();
}

class _ConnectPanelState extends State<ConnectPanel> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String? _errorText(AppLocalizations l10n, PairingController c) => switch (c.error) {
        PairingError.notFound => l10n.autoConnectFailed,
        PairingError.timeout => l10n.pairingTimeout,
        PairingError.invalidCode => l10n.manualCodeInvalid,
        PairingError.invalidQr => l10n.invalidQr,
        PairingError.failed => c.errorDetail,
        null => null,
      };

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.onSubmitCode(_code.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = widget.controller;
    final status = switch (c.status) {
      PairingStatus.searching => l10n.autoConnectSearching,
      PairingStatus.connecting => l10n.pairingConnecting,
      PairingStatus.idle => null,
    };
    final error = _errorText(l10n, c);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Flexible(child: Text(status)),
              ]),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
            ),
          FilledButton.icon(
            onPressed: c.busy ? null : widget.onAutoConnect,
            icon: const Icon(Icons.wifi_find),
            label: Text(l10n.autoConnectButton),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _code,
                enabled: !c.busy,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  labelText: l10n.manualCodeLabel,
                  hintText: l10n.manualCodeHint,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: c.busy ? null : _submit, child: Text(l10n.manualCodeConnect)),
          ]),
        ],
      ),
    );
  }
}
