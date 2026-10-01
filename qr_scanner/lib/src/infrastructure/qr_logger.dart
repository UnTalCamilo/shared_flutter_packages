import 'package:flutter/foundation.dart';

/// Puerto de logging de `qr_scanner`.
///
/// Igual que `camera_core`, el paquete no depende de ninguna librería de
/// logging: define este puerto y lo recibe por constructor. La app puede
/// puentearlo a su propio logger.
abstract class QrLogger {
  void d(String message);
  void w(String message);
  void e(String message, [Object? error, StackTrace? stackTrace]);
}

/// Implementación por defecto: imprime en debug, solo errores en release.
class DebugPrintQrLogger implements QrLogger {
  const DebugPrintQrLogger();

  @override
  void d(String message) {
    if (!kReleaseMode) debugPrint('[qr_scanner][D] $message');
  }

  @override
  void w(String message) {
    if (!kReleaseMode) debugPrint('[qr_scanner][W] $message');
  }

  @override
  void e(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[qr_scanner][E] $message${error != null ? ' | $error' : ''}');
  }
}

/// Implementación no-op (tests o consumidores sin logging).
class SilentQrLogger implements QrLogger {
  const SilentQrLogger();

  @override
  void d(String message) {}

  @override
  void w(String message) {}

  @override
  void e(String message, [Object? error, StackTrace? stackTrace]) {}
}
