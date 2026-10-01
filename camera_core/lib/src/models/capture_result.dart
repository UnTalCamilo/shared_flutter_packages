import 'dart:typed_data';
import 'dart:ui';

import 'camera_config.dart';

/// Metadatos básicos asociados a una captura. No incluye EXIF avanzado (fuera
/// de alcance del módulo).
class CaptureMetadata {
  final DateTime timestamp;
  final CameraLensDirection lensDirection;
  final double zoomLevel;
  final FlashMode flashMode;
  final double exposureOffset;

  /// Resolución real (en píxeles) de la fotografía capturada, no la del
  /// preview. Es la dimensión del archivo generado por la captura.
  final Size resolution;

  /// Orientación del sensor de la cámara activa, en grados. Necesaria para que
  /// consumidores post-captura (recorte, rotación) corrijan la orientación.
  final int sensorOrientation;

  const CaptureMetadata({
    required this.timestamp,
    required this.lensDirection,
    required this.zoomLevel,
    required this.flashMode,
    required this.exposureOffset,
    required this.resolution,
    required this.sensorOrientation,
  });
}

/// Resultado de una captura de fotografía.
///
/// El módulo entrega la ruta local del archivo; el consumidor decide qué hacer
/// con ella (guardar, subir, procesar). El módulo no persiste ni procesa.
class CaptureResult {
  /// Ruta local del archivo generado por la captura.
  final String path;

  /// Bytes opcionales para preview inmediato sin releer el archivo.
  final Uint8List? bytes;

  final CaptureMetadata metadata;

  const CaptureResult({
    required this.path,
    required this.metadata,
    this.bytes,
  });
}
