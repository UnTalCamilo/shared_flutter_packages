/// face_detection — capacidad de detección facial geométrica sobre
/// `camera_core`.
///
/// Punto de entrada público. Solo se exportan el contrato de capacidad, la
/// configuración, los modelos propios y el puerto de logging. ML Kit
/// (`google_mlkit_face_detection`) queda confinado en el adaptador interno y
/// NO se exporta; tampoco se expone `package:camera` ni `CameraController`.
///
/// Alcance: detección geométrica (bounding box, landmarks, ángulos). **No**
/// hace reconocimiento, identificación ni verificación de identidad.
library face_detection;

// --- Contrato de capacidad ---
export 'src/contracts/face_detector.dart' show IFaceDetector;

// --- Fábrica (sin DI, sin exponer internos) ---
export 'src/face_detection_factory.dart' show FaceDetection;

// --- Modelos propios (frontera pública) ---
export 'src/models/face_detection_result.dart'
    show FaceDetectionResult, DetectedFace, FaceLandmarkKey;
export 'src/models/face_detection_config.dart'
    show FaceDetectionConfig, FaceDetectionPerformance;

// --- Logging (puerto; la app puede puentearlo) ---
export 'src/infrastructure/face_detection_logger.dart'
    show
        FaceDetectionLogger,
        DebugPrintFaceDetectionLogger,
        SilentFaceDetectionLogger;
