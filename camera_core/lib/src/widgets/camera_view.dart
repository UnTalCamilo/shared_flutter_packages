import 'package:flutter/material.dart';

import '../contracts/camera_service.dart';
import '../models/camera_error.dart';
import '../models/camera_state.dart';

/// Widget de preview reutilizable y DELGADO.
///
/// Solo pinta el preview de la cámara y reacciona a los estados del ciclo de
/// vida vía [ICameraService.stateStream]. No conoce `package:camera`, no
/// contiene controles, overlays de negocio ni tap-to-focus: todo eso lo inyecta
/// el consumidor mediante los `*Builder` y [overlay].
///
/// Uso típico:
/// ```dart
/// CameraView(controller: cameraService)
/// ```
class CameraView extends StatelessWidget {
  /// Servicio de cámara. Única dependencia; el widget no toca el plugin.
  final ICameraService controller;

  /// Cómo encajar el preview. Por defecto `cover`.
  final BoxFit fit;

  /// Builder para los estados `initializing`/`uninitialized`.
  /// Por defecto, un indicador de progreso centrado.
  final WidgetBuilder? loadingBuilder;

  /// Builder para `permissionDenied`. Por defecto no pinta nada.
  final WidgetBuilder? permissionDeniedBuilder;

  /// Builder para `unavailable` (sin cámara). Por defecto no pinta nada.
  final WidgetBuilder? unavailableBuilder;

  /// Builder para `error`. Por defecto no pinta nada. El [CameraException] es
  /// `null` aquí porque el estado reactivo no transporta la excepción; el
  /// consumidor que necesite el detalle puede capturarlo en sus llamadas.
  final Widget Function(BuildContext, CameraException?)? errorBuilder;

  /// Overlay opcional dibujado encima del preview cuando el estado es `ready`.
  /// `camera_core` no provee overlays de negocio; el consumidor los inyecta.
  final Widget? overlay;

  const CameraView({
    super.key,
    required this.controller,
    this.fit = BoxFit.cover,
    this.loadingBuilder,
    this.permissionDeniedBuilder,
    this.unavailableBuilder,
    this.errorBuilder,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CameraState>(
      stream: controller.stateStream,
      initialData: controller.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? CameraState.uninitialized;
        switch (state) {
          case CameraState.ready:
            final preview = controller.buildPreview(fit: fit);
            if (overlay == null) return preview;
            return Stack(
              fit: StackFit.expand,
              children: [preview, overlay!],
            );
          case CameraState.permissionDenied:
            return permissionDeniedBuilder?.call(context) ??
                const SizedBox.shrink();
          case CameraState.unavailable:
            return unavailableBuilder?.call(context) ?? const SizedBox.shrink();
          case CameraState.error:
            return errorBuilder?.call(context, null) ?? const SizedBox.shrink();
          case CameraState.initializing:
          case CameraState.uninitialized:
            return loadingBuilder?.call(context) ??
                const Center(child: CircularProgressIndicator());
          case CameraState.disposed:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
