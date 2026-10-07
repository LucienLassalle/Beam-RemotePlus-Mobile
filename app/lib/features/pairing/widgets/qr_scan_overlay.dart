import 'package:flutter/material.dart';

/// Darkens everything around the QR scan window.
class QrScanOverlay extends StatelessWidget {
  final Rect scanWindow;
  const QrScanOverlay({super.key, required this.scanWindow});

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(size: Size.infinite, painter: _OverlayPainter(scanWindow)));
}

class _OverlayPainter extends CustomPainter {
  final Rect window;
  const _OverlayPainter(this.window);

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(window, const Radius.circular(16));
    final overlay = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(hole));
    canvas.drawPath(overlay, Paint()..color = Colors.black.withValues(alpha: 0.65));
    canvas.drawRRect(
      hole,
      Paint()
        ..color = Colors.orangeAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) => oldDelegate.window != window;
}
