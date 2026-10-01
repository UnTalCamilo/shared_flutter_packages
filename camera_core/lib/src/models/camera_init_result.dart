import 'camera_info.dart';

/// Clasificación del resultado de una inicialización/cambio de cámara.
enum CameraInitResultType {
  success,
  permissionDenied,
  permissionDeniedForever,
  noCameraAvailable,
  initializationFailed,
}

/// Resultado tipado de `initialize()` / `switchCamera()`.
///
/// Se usa un result type (en vez de excepciones checked) para forzar al
/// consumidor a manejar cada caso de forma exhaustiva.
class CameraInitResult {
  final CameraInitResultType type;
  final String? message;
  final CameraInfo? cameraInfo;

  const CameraInitResult._({
    required this.type,
    this.message,
    this.cameraInfo,
  });

  bool get isSuccess => type == CameraInitResultType.success;

  factory CameraInitResult.success(CameraInfo info) => CameraInitResult._(
        type: CameraInitResultType.success,
        cameraInfo: info,
      );

  factory CameraInitResult.permissionDenied() => const CameraInitResult._(
        type: CameraInitResultType.permissionDenied,
      );

  factory CameraInitResult.permissionDeniedForever() =>
      const CameraInitResult._(
        type: CameraInitResultType.permissionDeniedForever,
      );

  factory CameraInitResult.noCameraAvailable() => const CameraInitResult._(
        type: CameraInitResultType.noCameraAvailable,
      );

  factory CameraInitResult.initializationFailed(String msg) =>
      CameraInitResult._(
        type: CameraInitResultType.initializationFailed,
        message: msg,
      );
}
