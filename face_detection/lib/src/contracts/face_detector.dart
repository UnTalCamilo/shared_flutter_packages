import 'package:camera_core/camera_core.dart';

import '../models/face_detection_result.dart';

/// Detector facial de bajo nivel: analiza UN frame.
///
/// Es intencionalmente mínimo y sin estado de stream: recibe un [CameraFrame]
/// de `camera_core` y devuelve un [FaceDetectionResult] con las caras
/// detectadas (en coordenadas del frame, post-rotación), o `null` si el frame
/// no es procesable (formato/plataforma no soportados, o error del motor).
///
/// La gestión de frames continuos (throttle, drop-if-busy) y la presentación
/// (mapeo frame→vista, overlays) son responsabilidad del consumidor, no de este
/// contrato. Devuelve `Future` porque la detección del motor es asíncrona.
///
/// Alcance: **detección geométrica**. No hace reconocimiento, identificación ni
/// verificación de identidad.
abstract interface class IFaceDetector {
  /// Analiza [frame] y devuelve las caras detectadas, o `null` si el frame no
  /// es procesable. No lanza: ante error del motor devuelve `null` para que el
  /// consumidor conserve el último resultado y no rompa el stream.
  Future<FaceDetectionResult?> detect(CameraFrame frame);

  /// Libera el detector subyacente. Idempotente.
  Future<void> dispose();
}
