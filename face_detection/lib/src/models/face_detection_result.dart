import 'dart:ui' show Rect, Offset, Size;

import 'package:camera_core/camera_core.dart';

/// Landmarks faciales expuestos por el paquete.
///
/// Modelo propio de frontera: la UI y los tests NUNCA conocen
/// `FaceLandmarkType` de ML Kit. Se transportan ojos + base de la nariz; el
/// resto queda deliberadamente fuera hasta tener un consumidor que lo requiera.
enum FaceLandmarkKey {
  leftEye,
  rightEye,
  noseBase,
}

/// Una cara detectada, en coordenadas del **espacio del frame** entregado al
/// detector (con la rotación ya aplicada), no del preview en pantalla.
///
/// El mapeo frame → vista (cover + crop + mirror frontal) es responsabilidad de
/// la aplicación (depende de cómo renderice su preview); por eso [DetectedFace]
/// transporta [frameSize] y [lensDirection].
///
/// Los ángulos de Euler se conservan como `double?`: están disponibles para
/// consumidores que los necesiten; el paquete no los interpreta.
class DetectedFace {
  /// Caja delimitadora en coordenadas del frame (post-rotación).
  final Rect boundingBox;

  /// Landmarks disponibles (subconjunto), en coordenadas del frame.
  final Map<FaceLandmarkKey, Offset> landmarks;

  /// Tamaño del frame usado por el detector (post-rotación). Necesario para el
  /// mapeo a la vista; se transporta por cara para que el consumidor no dependa
  /// de estado externo.
  final Size frameSize;

  /// Lente activo cuando se detectó la cara. Determina el mirror frontal en el
  /// consumidor.
  final CameraLensDirection lensDirection;

  /// Ángulos de Euler. `null` si no aplican.
  final double? eulerX;
  final double? eulerY;
  final double? eulerZ;

  const DetectedFace({
    required this.boundingBox,
    required this.landmarks,
    required this.frameSize,
    required this.lensDirection,
    this.eulerX,
    this.eulerY,
    this.eulerZ,
  });
}

/// Resultado inmutable de una pasada de detección sobre un frame.
///
/// Envuelve la lista de caras + `timestamp` + `frameId` para permitir comparar
/// resultados (repaint) y depurar. Sin lógica.
class FaceDetectionResult {
  final List<DetectedFace> faces;
  final DateTime timestamp;
  final int frameId;

  const FaceDetectionResult({
    required this.faces,
    required this.timestamp,
    required this.frameId,
  });

  /// Resultado vacío (sin caras) para un frame dado.
  factory FaceDetectionResult.empty({
    required DateTime timestamp,
    required int frameId,
  }) =>
      FaceDetectionResult(
        faces: const [],
        timestamp: timestamp,
        frameId: frameId,
      );

  bool get isEmpty => faces.isEmpty;
}
