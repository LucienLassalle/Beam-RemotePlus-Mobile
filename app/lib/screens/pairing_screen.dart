import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../debug/app_debug.dart';
import '../localization/app_strings.dart';
import '../protocol/beamng_client.dart';
import '../protocol/pairing_code.dart';
import '../widgets/qr_scan_overlay.dart';
import 'control_screen.dart';

/// Écran d'accueil : scan du QR code affiché par BeamNG.drive dans
/// Options > Contrôles > Matériel > Application de contrôle à distance.
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _permissionGranted = false;
  bool _busy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Contrairement à l'écran de conduite (verrouillé en paysage), le scan
    // du QR code doit rester libre : le portrait est souvent plus pratique
    // pour viser l'écran du PC. Réaffirmé ici au cas où on revienne depuis
    // l'écran de conduite, qui verrouille le paysage.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() => _permissionGranted = status.isGranted);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final pairing = PairingCode.tryParse(raw);
    if (pairing == null) {
      setState(() => _errorMessage = Strings.t('invalid_qr'));
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    await _scannerController.stop();

    final client = BeamngClient();
    try {
      await client.connect(pairing.securityCode);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ControlScreen(client: client)),
      );
    } catch (e) {
      client.dispose();
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _scannerController.start();
      }
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.t('app_title')),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bug_report,
              color: AppDebug.enabled ? Colors.orangeAccent : null,
            ),
            tooltip: Strings.t('debug_mode_tooltip'),
            onPressed: () {
              setState(() => AppDebug.enabled = !AppDebug.enabled);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppDebug.enabled
                        ? Strings.t('debug_mode_on')
                        : Strings.t('debug_mode_off'),
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: !_permissionGranted
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Strings.t('camera_permission_message'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _requestCameraPermission,
                      child: Text(Strings.t('camera_permission_button')),
                    ),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth * 0.7
                    : constraints.maxHeight * 0.5;
                final scanWindow = Rect.fromCenter(
                  center: Offset(
                    constraints.maxWidth / 2,
                    constraints.maxHeight / 2,
                  ),
                  width: side,
                  height: side,
                );
                return Stack(
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      scanWindow: scanWindow,
                      onDetect: _onDetect,
                    ),
                    QrScanOverlay(scanWindow: scanWindow),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 32,
                      child: Column(
                        children: [
                          if (_busy)
                            const CircularProgressIndicator()
                          else
                            Text(
                              Strings.t('scan_hint'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                backgroundColor: Colors.black54,
                              ),
                            ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  backgroundColor: Colors.black54,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
