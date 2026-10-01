import 'package:camera_core/camera_core.dart';

import '../models/qr_scan_result.dart';

/// Detector de códigos de bajo nivel: analiza UN frame.
///
/// Es intencionalmente mínimo y sin estado de stream: recibe un [CameraFrame]
/// de `camera_core` y devuelve un [QrScanResult] o `null` si no hay código (o
/// el frame no es procesable). La gestión de frames continuos (throttling,
/// duplicados) es responsabilidad de [IQrScanSession], no de este contrato.
///
/// Devuelve `Future` porque la detección de ML Kit es asíncrona.
abstract interface class IQrScanner {
  /// Analiza [frame] y devuelve el primer código detectado, o `null`.
  Future<QrScanResult?> detect(CameraFrame frame);

  /// Libera el detector subyacente. Idempotente.
  Future<void> dispose();
}

/// Sesión de escaneo sobre un stream continuo de frames.
///
/// Encapsula la estrategia de procesamiento (drop-if-busy + throttle) y la
/// política de duplicados, y expone un stream de resultados ya filtrado. La app
/// solo escucha [results]; no reimplementa throttling ni dedup.
abstract interface class IQrScanSession {
  /// Resultados emitidos según la política de duplicados y el throttle.
  Stream<QrScanResult> get results;

  /// Reinicia el estado de duplicados (p. ej. al reanudar tras pausar).
  void resetDuplicates();

  /// Detiene la sesión y libera sus suscripciones. No cierra el [IQrScanner]
  /// subyacente (su ciclo de vida lo gestiona quien lo creó).
  void dispose();
}
