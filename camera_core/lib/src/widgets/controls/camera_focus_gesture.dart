import 'package:flutter/material.dart';

import '../../contracts/camera_service.dart';
import '../../models/camera_error.dart';

/// Envoltorio de tap-to-focus reutilizable.
///
/// Detecta toques sobre su [child] (típicamente un preview), convierte la
/// posición a coordenadas normalizadas (0,0)–(1,1) relativas al área y llama a
/// [ICameraService.setFocusPoint]. Notifica el punto normalizado por
/// [onFocusRequested] para que la app pinte su propio indicador si lo desea.
///
/// No pinta ningún indicador de enfoque: eso es decisión de presentación de la
/// app. Es una pieza de comportamiento, no de estilo.
class CameraFocusGesture extends StatelessWidget {
  final ICameraService controller;
  final Widget child;

  /// Notifica el punto normalizado (0..1, 0..1) donde se solicitó enfoque.
  final void Function(Offset normalized)? onFocusRequested;

  const CameraFocusGesture({
    super.key,
    required this.controller,
    required this.child,
    this.onFocusRequested,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) async {
            if (size.width == 0 || size.height == 0) return;
            final dx = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
            final dy = (details.localPosition.dy / size.height).clamp(0.0, 1.0);
            final normalized = Offset(dx, dy);
            onFocusRequested?.call(normalized);
            try {
              await controller.setFocusPoint(normalized);
            } on CameraException {
              // Degradación silenciosa (p. ej. metering no soportado).
            }
          },
          child: child,
        );
      },
    );
  }
}
