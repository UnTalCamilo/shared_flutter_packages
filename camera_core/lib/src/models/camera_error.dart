/// Tipos de error del dominio de cámara. Ninguna excepción del paquete
/// `camera` debe propagarse fuera de [CameraControllerWrapper]; todo se traduce
/// a estos tipos.
enum CameraErrorType {
  permissionDenied,
  permissionDeniedForever,
  noCameraAvailable,
  initializationFailed,
  captureFailed,
  controllerDisposed,
  deviceError,
  unknown,
}

/// Excepción de dominio del módulo de cámara.
class CameraException implements Exception {
  final CameraErrorType type;
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const CameraException({
    required this.type,
    required this.message,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'CameraException(${type.name}): $message';
}

/// Resultado de una verificación/solicitud de permiso de cámara.
///
/// Se aloja aquí (y no en un archivo propio) por decisión de diseño acordada:
/// evita crear un archivo adicional solo para este enum.
enum CameraPermissionResult {
  granted,
  denied,
  deniedForever,
  restricted,
}
