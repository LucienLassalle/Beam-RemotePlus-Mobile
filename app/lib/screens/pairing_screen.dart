import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../debug/app_debug.dart';
import '../localization/app_strings.dart';
import '../protocol/beamng_client.dart';
import '../protocol/mod_discovery.dart';
import '../protocol/pairing_code.dart';
import '../widgets/qr_scan_overlay.dart';
import 'control_screen.dart';

/// Écran d'accueil : trois façons de se connecter à BeamNG.drive.
///
///  1. **Connexion automatique** (recommandée) : découverte du PC sur le
///     réseau via le mod, sans QR ni caméra. Nécessite le mod actif.
///  2. **Saisie manuelle** du code d'appairage à 5 chiffres (affiché en jeu
///     par le mod, ou lisible dans Options > ... > Remote Control).
///  3. **Scan du QR code** affiché par BeamNG — historique, laissé pour
///     quand BeamNG aura réparé son UI (cassée depuis la 0.39).
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _codeController = TextEditingController();

  bool _permissionGranted = false;
  bool _busy = false;
  String? _status;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Contrairement à l'écran de conduite (verrouillé en paysage), l'écran
    // d'appairage reste libre : le portrait est souvent plus pratique pour
    // viser l'écran du PC. Réaffirmé ici au cas où on revienne depuis
    // l'écran de conduite.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _permissionGranted = status.isGranted);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // --- Connexion : chemin commun aux trois méthodes -------------------------

  Future<void> _connectWithCode(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _status = Strings.t('pairing_connecting');
    });
    await _scannerController.stop();

    final client = BeamngClient();
    try {
      await client.connect(code);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ControlScreen(client: client)),
      );
    } catch (e) {
      client.dispose();
      if (mounted) setState(() => _errorMessage = _humanError(e));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
        await _scannerController.start();
      }
    }
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('Timeout') || s.contains('timeout')) {
      return Strings.t('pairing_timeout');
    }
    return s;
  }

  // --- 1. Connexion automatique -------------------------------------------

  Future<void> _autoConnect() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
      _status = Strings.t('auto_connect_searching');
    });
    await _scannerController.stop();

    try {
      final result = await ModDiscovery.discover();
      if (result == null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _status = null;
            _errorMessage = Strings.t('auto_connect_failed');
          });
          await _scannerController.start();
        }
        return;
      }
      AppDebug.log('autoConnect: ${result.label} @ ${result.hostAddress}');
      // _busy reste true : on enchaîne directement sur la connexion.
      setState(() => _busy = false);
      await _connectWithCode(result.securityCode);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
          _errorMessage = _humanError(e);
        });
        await _scannerController.start();
      }
    }
  }

  // --- 2. Saisie manuelle ------------------------------------------------

  Future<void> _submitManualCode() async {
    final parsed = PairingCode.tryParse(_codeController.text);
    if (parsed == null) {
      setState(() => _errorMessage = Strings.t('manual_code_invalid'));
      return;
    }
    FocusScope.of(context).unfocus();
    await _connectWithCode(parsed.securityCode);
  }

  // --- 3. Scan QR --------------------------------------------------------

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final barcode = capture.barcodes.firstOrNull;
    // ML Kit renvoie parfois rawValue == null pour un QR de type URL
    // (seul le champ typé est rempli) : on tente toutes les sources avant
    // d'abandonner, et si vraiment rien n'est exploitable on le signale
    // plutôt que de rester muet.
    final raw = barcode?.rawValue ??
        barcode?.displayValue ??
        barcode?.url?.url;
    if (raw == null) {
      if (barcode != null) {
        setState(() => _errorMessage = Strings.t('invalid_qr'));
      }
      return;
    }

    final pairing = PairingCode.tryParse(raw);
    if (pairing == null) {
      setState(() => _errorMessage = Strings.t('invalid_qr'));
      return;
    }
    await _connectWithCode(pairing.securityCode);
  }

  // --- UI --------------------------------------------------------------

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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildScanner()),
            _buildConnectPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanner() {
    if (!_permissionGranted) {
      return Center(
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
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth * 0.7
            : constraints.maxHeight * 0.6;
        final scanWindow = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
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
              bottom: 16,
              child: Text(
                Strings.t('scan_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Flexible(child: Text(_status!)),
                ],
              ),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          FilledButton.icon(
            onPressed: _busy ? null : _autoConnect,
            icon: const Icon(Icons.wifi_find),
            label: Text(Strings.t('auto_connect_button')),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    labelText: Strings.t('manual_code_label'),
                    hintText: Strings.t('manual_code_hint'),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submitManualCode(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy ? null : _submitManualCode,
                child: Text(Strings.t('manual_code_connect')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
