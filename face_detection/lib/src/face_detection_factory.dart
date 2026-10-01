import 'contracts/face_detector.dart';
import 'infrastructure/face_detection_logger.dart';
import 'models/face_detection_config.dart';
import 'services/face_detector_impl.dart';

/// Fábrica de conveniencia para construir el detector facial sin exponer las
/// clases internas ni depender de un framework de DI.
abstract final class FaceDetection {
  const FaceDetection._();

  /// Crea un [IFaceDetector] con la configuración dada.
  ///
  /// [logger] permite a la app puentear el logging del paquete a su propio
  /// sistema. Si se omite, se usa [DebugPrintFaceDetectionLogger].
  static IFaceDetector create({
    FaceDetectionConfig config = const FaceDetectionConfig(),
    FaceDetectionLogger logger = const DebugPrintFaceDetectionLogger(),
  }) {
    return FaceDetectorImpl(config: config, logger: logger);
  }
}
