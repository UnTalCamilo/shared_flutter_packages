import 'package:flutter/foundation.dart';

/// Puerto de logging de `face_detection`.
///
/// Igual que `camera_core`/`qr_scanner`, el paquete no depende de ninguna
/// librería de logging: define este puerto y lo recibe por constructor. La app
/// puede puentearlo a su propio logger.
abstract class FaceDetectionLogger {
  void d(String message);
  void w(String message);
  void e(String message, [Object? error, StackTrace? stackTrace]);
}

/// Implementación por defecto: imprime en debug, solo errores en release.
class DebugPrintFaceDetectionLogger implements FaceDetectionLogger {
  const DebugPrintFaceDetectionLogger();

  @override
  void d(String message) {
    if (!kReleaseMode) debugPrint('[face_detection][D] $message');
  }

  @override
  void w(String message) {
    if (!kReleaseMode) debugPrint('[face_detection][W] $message');
  }

  @override
  void e(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint(
        '[face_detection][E] $message${error != null ? ' | $error' : ''}');
  }
}

/// Implementación no-op (tests o consumidores sin logging).
class SilentFaceDetectionLogger implements FaceDetectionLogger {
  const SilentFaceDetectionLogger();

  @override
  void d(String message) {}

  @override
  void w(String message) {}

  @override
  void e(String message, [Object? error, StackTrace? stackTrace]) {}
}
