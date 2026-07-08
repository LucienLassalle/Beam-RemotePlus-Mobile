import 'package:flutter/material.dart';

/// Pédale verticale analogique : la position du doigt dans la zone définit
/// directement la valeur 0.0-1.0 envoyée au jeu (pas juste appuyé/relâché
/// comme l'ancienne app). Relâcher ramène la valeur à 0.
///
/// Implémenté avec [Listener] (événements pointeur bruts) plutôt qu'un
/// GestureDetector : évite la compétition de gestes qui déclenchait un
/// onTapCancel après ~500ms de maintien, réinitialisant la pédale à 0 et
/// faisant disparaître l'interface si le geste système interceptait le touch.
class PedalControl extends StatefulWidget {
  final String label;
  final Color color;
  final ValueChanged<double> onChanged;

  const PedalControl({
    super.key,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  State<PedalControl> createState() => _PedalControlState();
}

class _PedalControlState extends State<PedalControl> {
  double _value = 0;

  void _setValue(double dy, BoxConstraints constraints) {
    final clamped = (1 - dy / constraints.maxHeight).clamp(0.0, 1.0);
    setState(() => _value = clamped);
    widget.onChanged(clamped);
  }

  void _release() {
    setState(() => _value = 0);
    widget.onChanged(0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerDown: (e) => _setValue(e.localPosition.dy, constraints),
          onPointerMove: (e) => _setValue(e.localPosition.dy, constraints),
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: Container(
            width: 84,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                FractionallySizedBox(
                  heightFactor: _value,
                  widthFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(_value * 100).round()}%',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
