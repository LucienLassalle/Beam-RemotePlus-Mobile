import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/debug/debug_log.dart';
import '../../core/network/beamng_connection.dart';
import '../../core/settings/settings_scope.dart';
import '../../l10n/generated/app_localizations.dart';
import '../driving/driving_screen.dart';
import 'pairing_controller.dart';
import 'widgets/connect_panel.dart';
import 'widgets/qr_scan_overlay.dart';

/// Home screen: automatic connection (recommended, needs the mod), manual
/// pairing code, or the QR code shown by the game.
class PairingScreen extends StatefulWidget {
  final PairingController? controller;
  const PairingScreen({super.key, this.controller});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  late final PairingController _controller = widget.controller ?? PairingController();
  final MobileScannerController _scanner = MobileScannerController(autoStart: false);
  bool _cameraAllowed = false;

  @override
  void initState() {
    super.initState();
    // Free orientation here: portrait is handier to aim at the PC screen.
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    unawaited(_requestCamera());
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraAllowed = status.isGranted);
    if (_cameraAllowed) await _scanner.start();
  }

  @override
  void dispose() {
    unawaited(_scanner.dispose());
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<BeamngConnection?> Function() attempt) async {
    _controller.secondScreen = SettingsScope.read(context).settings.secondScreen;
    if (_cameraAllowed) await _scanner.stop();
    final connection = await attempt();
    if (connection != null && mounted) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DrivingScreen(connection: connection)));
    }
    if (mounted && _cameraAllowed) await _scanner.start();
  }

  void _toggleDebug() {
    final settings = SettingsScope.read(context);
    final enabled = !settings.settings.debugMode;
    unawaited(settings.update((s) => s.copyWith(debugMode: enabled)));
    DebugLog.enabled = enabled;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(enabled ? l10n.debugModeOn : l10n.debugModeOff),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final debug = SettingsScope.of(context).settings.debugMode;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report, color: debug ? Colors.orangeAccent : null),
            tooltip: l10n.debugModeTooltip,
            onPressed: _toggleDebug,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(child: _scannerView(l10n)),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => ConnectPanel(
              controller: _controller,
              secondScreen: SettingsScope.of(context).settings.secondScreen,
              onSecondScreenChanged: (v) =>
                  unawaited(SettingsScope.read(context).update((s) => s.copyWith(secondScreen: v))),
              onAutoConnect: () => _run(_controller.autoConnect),
              onSubmitCode: (code) => _run(() => _controller.submitCode(code)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _scannerView(AppLocalizations l10n) {
    if (!_cameraAllowed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.cameraPermissionMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _requestCamera, child: Text(l10n.cameraPermissionButton)),
          ]),
        ),
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final side = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth * 0.7 : constraints.maxHeight * 0.6;
      final window = Rect.fromCenter(
        center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
        width: side,
        height: side,
      );
      return Stack(children: [
        MobileScanner(
          controller: _scanner,
          scanWindow: window,
          onDetect: (capture) {
            if (_controller.busy || capture.barcodes.isEmpty) return;
            final b = capture.barcodes.first;
            // ML Kit sometimes only fills the typed URL field of a QR.
            unawaited(_run(() => _controller.onQrScanned(b.rawValue ?? b.displayValue ?? b.url?.url)));
          },
        ),
        QrScanOverlay(scanWindow: window),
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Text(l10n.scanHint,
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, backgroundColor: Colors.black54)),
        ),
      ]);
    });
  }
}
