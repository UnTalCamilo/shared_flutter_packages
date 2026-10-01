import 'camera_info.dart';

/// Estado del ciclo de vida de la cámara. Es la fuente de verdad principal
/// expuesta por `ICameraService` a través de `stateStream`.
enum CameraState {
  uninitialized,
  initializing,
  ready,
  error,
  permissionDenied,
  unavailable,
  disposed,
}

/// Snapshot completo del estado de la cámara para consumidores que necesiten
/// más contexto que el [CameraState] simple.
class CameraStateModel {
  final CameraState state;
  final String? errorMessage;
  final CameraInfo? currentCamera;

  const CameraStateModel({
    required this.state,
    this.errorMessage,
    this.currentCamera,
  });
}
