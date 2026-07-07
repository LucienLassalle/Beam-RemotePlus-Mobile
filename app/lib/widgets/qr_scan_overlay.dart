import 'package:flutter/material.dart';

/// Cadre de visée dessiné par-dessus l'aperçu caméra : assombrit tout sauf
/// la zone carrée où le QR code doit être positionné, avec une bordure.
class QrScanOverlay extends StatelessWidget {
  final Rect scanWindow;

  const QrScanOverlay({super.key, required this.scanWindow});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _QrScanOverlayPainter(scanWindow),
      ),
    );
  }
}

class _QrScanOverlayPainter extends CustomPainter {
  final Rect scanWindow;

  const _QrScanOverlayPainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, const Radius.circular(16)));
    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, Paint()..color = Colors.black.withValues(alpha: 0.65));
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindow, const Radius.circular(16)),
      Paint()
        ..color = Colors.orangeAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _QrScanOverlayPainter oldDelegate) =>
      oldDelegate.scanWindow != scanWindow;
}
