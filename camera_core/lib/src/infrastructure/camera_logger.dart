import 'package:flutter/foundation.dart';

/// Puerto de logging de `camera_core`.
///
/// El paquete NO depende de ninguna librería de logging concreta. Define este
/// puerto y lo recibe por constructor; la aplicación consumidora puede
/// puentearlo a su propio logger (p. ej. `AppLogger`).
///
/// Niveles mínimos necesarios para la infraestructura de cámara: debug,
/// warning y error. No se añaden más por anticipación.
abstract class CameraLogger {
  void d(String message);
  void w(String message);
  void e(String message, [Object? error, StackTrace? stackTrace]);
}

/// Implementación por defecto del puerto [CameraLogger].
///
/// En modo debug imprime por `debugPrint`; en release solo emite errores. Es el
/// fallback cuando la app no inyecta un logger propio. Nunca silencia los
/// errores: `e()` siempre imprime.
class DebugPrintCameraLogger implements CameraLogger {
  const DebugPrintCameraLogger();

  @override
  void d(String message) {
    if (!kReleaseMode) {
      debugPrint('[camera_core][D] $message');
    }
  }

  @override
  void w(String message) {
    if (!kReleaseMode) {
      debugPrint('[camera_core][W] $message');
    }
  }

  @override
  void e(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[camera_core][E] $message'
        '${error != null ? ' | $error' : ''}');
    if (stackTrace != null && !kReleaseMode) {
      debugPrint(stackTrace.toString());
    }
  }
}

/// Implementación no-op para tests o consumidores que no deseen logging.
class SilentCameraLogger implements CameraLogger {
  const SilentCameraLogger();

  @override
  void d(String message) {}

  @override
  void w(String message) {}

  @override
  void e(String message, [Object? error, StackTrace? stackTrace]) {}
}
