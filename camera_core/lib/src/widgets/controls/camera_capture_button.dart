import 'package:flutter/material.dart';

import '../../contracts/camera_service.dart';
import '../../models/camera_error.dart';
import '../../models/camera_state.dart';
import '../../models/capture_result.dart';

/// Botón de captura reutilizable y autónomo.
///
/// Lee el estado del servicio: solo está habilitado cuando la cámara está
/// `ready`. Al pulsar, llama a [ICameraService.takePicture] y entrega el
/// resultado por [onCaptured]; los errores se entregan por [onError] (si se
/// provee) sin romper la experiencia.
///
/// No impone estilo de pantalla: es una pieza suelta que la app coloca donde
/// quiera. Acepta un [builder] para personalizar completamente la apariencia
/// manteniendo el comportamiento.
class CameraCaptureButton extends StatelessWidget {
  final ICameraService controller;
  final ValueChanged<CaptureResult> onCaptured;
  final void Function(CameraException error)? onError;

  /// Builder opcional de apariencia. Recibe si está habilitado y el callback de
  /// disparo. Si es `null`, usa un [FloatingActionButton] con icono de cámara.
  final Widget Function(
    BuildContext context,
    bool enabled,
    VoidCallback? onPressed,
  )? builder;

  const CameraCaptureButton({
    super.key,
    required this.controller,
    required this.onCaptured,
    this.onError,
    this.builder,
  });

  Future<void> _capture() async {
    try {
      final result = await controller.takePicture();
      onCaptured(result);
    } on CameraException catch (e) {
      onError?.call(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CameraState>(
      stream: controller.stateStream,
      initialData: controller.state,
      builder: (context, snapshot) {
        final enabled = snapshot.data == CameraState.ready;
        final onPressed = enabled ? _capture : null;
        if (builder != null) return builder!(context, enabled, onPressed);
        return FloatingActionButton(
          onPressed: onPressed,
          child: const Icon(Icons.camera_alt),
        );
      },
    );
  }
}
