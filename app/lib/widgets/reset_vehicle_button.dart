import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';

/// Bouton de réinitialisation/récupération du véhicule (équivalent de la
/// touche Insert en jeu, "recover_vehicle"). Volontairement petit et
/// nécessite un appui maintenu (900ms) avant de déclencher
/// [onRecoverStart] : évite qu'un doigt qui glisse pendant la conduite ne
/// le déclenche par inadvertance. Le remplissage circulaire donne un
/// retour visuel pendant la confirmation, dans le même esprit que le
/// "hold to confirm" déjà utilisé par le menu de récupération natif de
/// BeamNG.drive.
///
/// Une fois la confirmation atteinte, le comportement suit exactement
/// celui de la touche maintenue sur PC : [onRecoverStart] démarre le
/// rembobinage vers l'historique de positions, et [onRecoverStop] (appelé
/// au relâchement) fige le véhicule au point atteint. Relâcher tout de
/// suite après la confirmation ≈ réinitialisation simple sur place ;
/// continuer à maintenir remonte plus loin dans l'historique de
/// récupération.
class ResetVehicleButton extends StatefulWidget {
  final VoidCallback onRecoverStart;
  final VoidCallback onRecoverStop;
  final bool enabled;

  const ResetVehicleButton({
    super.key,
    required this.onRecoverStart,
    required this.onRecoverStop,
    this.enabled = false,
  });

  @override
  State<ResetVehicleButton> createState() => _ResetVehicleButtonState();
}

class _ResetVehicleButtonState extends State<ResetVehicleButton>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(milliseconds: 900);

  bool _recovering = false;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _holdDuration,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _recovering = true;
        widget.onRecoverStart();
        HapticFeedback.mediumImpact();
      }
    });

  @override
  void dispose() {
    // Évite de laisser le véhicule bloqué en récupération si l'écran se
    // ferme (navigation, hot restart...) pendant un appui maintenu.
    if (_recovering) widget.onRecoverStop();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    _controller.forward();
  }

  void _release() {
    if (_recovering) {
      _recovering = false;
      widget.onRecoverStop();
      _controller.reset();
    } else if (_controller.status == AnimationStatus.forward) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;
    return Tooltip(
      message: Strings.t('reset_vehicle_tooltip'),
      child: GestureDetector(
        onLongPressDown: (_) => _start(),
        onLongPressCancel: _release,
        onLongPressUp: _release,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CircularProgressIndicator(
                  value: _controller.value == 0 ? null : _controller.value,
                  strokeWidth: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(
                    _controller.value == 0
                        ? Colors.transparent
                        : Colors.orangeAccent,
                  ),
                ),
              ),
              Icon(
                Icons.restart_alt,
                size: 18,
                color: active ? Colors.white54 : Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
