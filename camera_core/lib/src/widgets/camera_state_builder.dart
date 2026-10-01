import 'package:flutter/material.dart';

import '../contracts/camera_service.dart';
import '../models/camera_error.dart';
import '../models/camera_state.dart';

/// Builder reactivo del ciclo de vida de la cámara.
///
/// Escucha [ICameraService.stateStream] y delega el render de cada estado a un
/// builder. No pinta preview ni controles: es solo la "máquina de estados" de
/// presentación, extraída para que cualquier composición pueda reaccionar a los
/// estados sin reimplementar el `StreamBuilder`.
///
/// Todos los builders son opcionales y tienen un placeholder neutro por
/// defecto (sin texto de negocio): la app inyecta su propia UI de permisos,
/// error, etc.
class CameraStateBuilder extends StatelessWidget {
  final ICameraService controller;

  /// Estado `ready`: típicamente un preview. Obligatorio.
  final WidgetBuilder ready;

  /// Estados `initializing`/`uninitialized`. Por defecto, progreso centrado.
  final WidgetBuilder? loadingBuilder;

  /// Estado `permissionDenied`. Por defecto no pinta nada.
  final WidgetBuilder? permissionDeniedBuilder;

  /// Estado `unavailable` (sin cámara). Por defecto no pinta nada.
  final WidgetBuilder? unavailableBuilder;

  /// Estado `error`. El [CameraException] es `null` porque el estado reactivo
  /// no transporta la excepción; la app que necesite el detalle lo captura en
  /// sus propias llamadas al servicio. Por defecto no pinta nada.
  final Widget Function(BuildContext, CameraException?)? errorBuilder;

  const CameraStateBuilder({
    super.key,
    required this.controller,
    required this.ready,
    this.loadingBuilder,
    this.permissionDeniedBuilder,
    this.unavailableBuilder,
    this.errorBuilder,
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
            return ready(context);
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
