import 'package:camera_core/camera_core.dart';

import '../contracts/face_detector.dart';
import '../infrastructure/face_detection_logger.dart';
import '../infrastructure/mlkit_face_adapter.dart';
import '../models/face_detection_config.dart';
import '../models/face_detection_result.dart';

/// Implementación de [IFaceDetector] que delega en el adaptador de ML Kit.
///
/// No conoce streams ni estado de sesión: analiza un frame y responde. El
/// throttle/drop-if-busy y la presentación viven en el consumidor.
class FaceDetectorImpl implements IFaceDetector {
  final MlkitFaceAdapter _adapter;

  FaceDetectorImpl({
    FaceDetectionConfig config = const FaceDetectionConfig(),
    FaceDetectionLogger logger = const DebugPrintFaceDetectionLogger(),
  }) : _adapter = MlkitFaceAdapter(config: config, logger: logger);

  @override
  Future<FaceDetectionResult?> detect(CameraFrame frame) =>
      _adapter.detect(frame);

  @override
  Future<void> dispose() => _adapter.close();
}
