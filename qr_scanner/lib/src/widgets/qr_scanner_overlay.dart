import 'package:flutter/widgets.dart';

/// Overlay visual OPCIONAL del área de escaneo.
///
/// Dibuja un marco guía (ventana de escaneo con esquinas resaltadas) y, si se
/// provee, un oscurecido del área exterior. **No crea ni conoce** cámara,
/// preview, `CameraController`, ML Kit, controles ni navegación: es solo pintura
/// que se coloca sobre cualquier preview.
///
/// ```dart
/// Stack(children: [
///   CameraPreview(controller: cameraService), // de camera_core
///   const QrScannerOverlay(),
/// ]);
/// ```
class QrScannerOverlay extends StatelessWidget {
  /// Tamaño del lado de la ventana cuadrada de escaneo, en píxeles lógicos.
  /// Si es `null`, se usa el 70% del lado menor del área disponible.
  final double? windowSize;

  /// Color del marco/esquinas.
  final Color borderColor;

  /// Grosor del trazo del marco.
  final double strokeWidth;

  /// Radio de las esquinas de la ventana.
  final double cornerRadius;

  /// Opacidad del oscurecido exterior (0 = sin oscurecido).
  final double scrimOpacity;

  const QrScannerOverlay({
    super.key,
    this.windowSize,
    this.borderColor = const Color(0xFFFFFFFF),
    this.strokeWidth = 3.0,
    this.cornerRadius = 16.0,
    this.scrimOpacity = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _QrOverlayPainter(
          windowSize: windowSize,
          borderColor: borderColor,
          strokeWidth: strokeWidth,
          cornerRadius: cornerRadius,
          scrimOpacity: scrimOpacity,
        ),
      ),
    );
  }
}

class _QrOverlayPainter extends CustomPainter {
  final double? windowSize;
  final Color borderColor;
  final double strokeWidth;
  final double cornerRadius;
  final double scrimOpacity;

  _QrOverlayPainter({
    required this.windowSize,
    required this.borderColor,
    required this.strokeWidth,
    required this.cornerRadius,
    required this.scrimOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side =
        windowSize ?? (size.shortestSide * 0.7).clamp(0.0, size.shortestSide);
    final window = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side,
      height: side,
    );
    final rrect = RRect.fromRectAndRadius(
      window,
      Radius.circular(cornerRadius),
    );

    // Oscurecido exterior (opcional).
    if (scrimOpacity > 0) {
      final scrim = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(rrect)
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(
        scrim,
        Paint()..color = const Color(0xFF000000).withValues(alpha: scrimOpacity),
      );
    }

    // Esquinas resaltadas (estilo guía de escaneo).
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final armLength = side * 0.18;

    void corner(Offset o, Offset hDir, Offset vDir) {
      canvas.drawLine(o, o + hDir * armLength, paint);
      canvas.drawLine(o, o + vDir * armLength, paint);
    }

    corner(window.topLeft, const Offset(1, 0), const Offset(0, 1));
    corner(window.topRight, const Offset(-1, 0), const Offset(0, 1));
    corner(window.bottomLeft, const Offset(1, 0), const Offset(0, -1));
    corner(window.bottomRight, const Offset(-1, 0), const Offset(0, -1));
  }

  @override
  bool shouldRepaint(covariant _QrOverlayPainter old) =>
      old.windowSize != windowSize ||
      old.borderColor != borderColor ||
      old.strokeWidth != strokeWidth ||
      old.cornerRadius != cornerRadius ||
      old.scrimOpacity != scrimOpacity;
}
