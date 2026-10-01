import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:camera_core/camera_core.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/face_detection_config.dart';
import '../models/face_detection_result.dart';
import 'face_detection_logger.dart';

/// **Único punto del paquete que importa `google_mlkit_face_detection`.**
///
/// Encapsula ML Kit por completo: construye/configura el `FaceDetector`,
/// convierte un [CameraFrame] de `camera_core` al `InputImage` requerido,
/// ejecuta la detección y traduce `Face`/`FaceLandmarkType` a modelos propios
/// ([FaceDetectionResult]/[DetectedFace]). Esos tipos de ML Kit NO cruzan esta
/// frontera.
///
/// Preserva el comportamiento previo de CAPPFRONT: resultados en coordenadas de
/// frame (post-rotación), degradación a `null` ante formato/plataforma no
/// soportados o error del motor, y cierre idempotente.
class MlkitFaceAdapter {
  final FaceDetectionConfig _config;

  /// Logger inyectado (puerto). Interno al paquete; no cruza el barrel.
  final FaceDetectionLogger logger;

  final FaceDetector _detector;
  bool _closed = false;

  MlkitFaceAdapter({
    FaceDetectionConfig config = const FaceDetectionConfig(),
    this.logger = const DebugPrintFaceDetectionLogger(),
  })  : _config = config,
        _detector = FaceDetector(
          options: FaceDetectorOptions(
            enableClassification: false,
            enableLandmarks: config.enableLandmarks,
            enableContours: false,
            enableTracking: false,
            minFaceSize: config.minFaceSize,
            performanceMode: _toMode(config.performanceMode),
          ),
        );

  static FaceDetectorMode _toMode(FaceDetectionPerformance p) => switch (p) {
        FaceDetectionPerformance.fast => FaceDetectorMode.fast,
        FaceDetectionPerformance.accurate => FaceDetectorMode.accurate,
      };

  /// Procesa un frame y devuelve las caras en coordenadas del frame
  /// (post-rotación). Devuelve `null` si el frame no es procesable (formato no
  /// soportado, plataforma no soportada, o error de ML Kit).
  Future<FaceDetectionResult?> detect(CameraFrame frame) async {
    if (_closed) return null;

    final InputImage? input = _toInputImage(frame);
    if (input == null) return null;

    try {
      final faces = await _detector.processImage(input);
      if (_closed) return null;

      final rotation = rotationForFrame(frame);
      final frameSize = rotatedFrameSize(frame, rotation);

      final mapped = <DetectedFace>[];
      for (final face in faces.take(_config.maxFaces)) {
        mapped.add(
            _toDetectedFace(face, frameSize, frame.metadata.lensDirection));
      }

      return FaceDetectionResult(
        faces: mapped,
        timestamp: frame.metadata.timestamp,
        frameId: frame.frameId,
      );
    } catch (e, s) {
      logger.w('Face detection falló para frame ${frame.frameId}: $e');
      logger.d('$s');
      return null; // Descartar frame; no romper el stream.
    }
  }

  /// Cierra el detector y libera recursos. Idempotente.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _detector.close();
    } catch (e) {
      logger.w('Error cerrando FaceDetector: $e');
    }
  }

  // ========== CONVERSIÓN CameraFrame → InputImage ==========

  /// Construye el `InputImage` para ML Kit según la plataforma y el formato
  /// REAL del frame. Devuelve `null` para formatos no soportados
  /// (`jpeg`/`unknown`) o plataformas sin ML Kit.
  InputImage? _toInputImage(CameraFrame frame) {
    if (frame.format == CameraFrameFormat.jpeg ||
        frame.format == CameraFrameFormat.unknown) {
      return null;
    }

    final rotation = _toInputImageRotation(rotationForFrame(frame));

    if (Platform.isAndroid) {
      // ML Kit en Android acepta con fiabilidad NV21. Si el frame ya llega NV21
      // usar sus bytes; si llega YUV420 triplanar, convertir a NV21 en Dart.
      Uint8List? nv21;
      if (frame.format == CameraFrameFormat.nv21) {
        nv21 = frame.planes.first.bytes;
      } else if (frame.format == CameraFrameFormat.yuv420) {
        nv21 = yuv420ToNv21(frame);
      }
      if (nv21 == null) return null;

      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          // En Android ML Kit ignora bytesPerRow; para NV21 el ancho basta.
          bytesPerRow: frame.width,
        ),
      );
    }

    if (Platform.isIOS) {
      // iOS entrega/espera BGRA de un solo plano.
      if (frame.format != CameraFrameFormat.bgra8888) return null;
      final plane = frame.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    // Web/desktop: plugin no soportado. Degradar silenciosamente.
    return null;
  }

  InputImageRotation _toInputImageRotation(int degrees) {
    switch (degrees % 360) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  // ========== ML Kit → modelos propios ==========

  DetectedFace _toDetectedFace(
    Face face,
    Size frameSize,
    CameraLensDirection lensDirection,
  ) {
    final landmarks = <FaceLandmarkKey, Offset>{};
    _addLandmark(
        landmarks, face, FaceLandmarkType.leftEye, FaceLandmarkKey.leftEye);
    _addLandmark(
        landmarks, face, FaceLandmarkType.rightEye, FaceLandmarkKey.rightEye);
    _addLandmark(
        landmarks, face, FaceLandmarkType.noseBase, FaceLandmarkKey.noseBase);

    return DetectedFace(
      boundingBox: face.boundingBox,
      landmarks: landmarks,
      frameSize: frameSize,
      lensDirection: lensDirection,
      eulerX: face.headEulerAngleX,
      eulerY: face.headEulerAngleY,
      eulerZ: face.headEulerAngleZ,
    );
  }

  void _addLandmark(
    Map<FaceLandmarkKey, Offset> target,
    Face face,
    FaceLandmarkType mlKitType,
    FaceLandmarkKey key,
  ) {
    final landmark = face.landmarks[mlKitType];
    if (landmark == null) return;
    target[key] = Offset(
      landmark.position.x.toDouble(),
      landmark.position.y.toDouble(),
    );
  }
}

// ============================================================================
// Helpers puros de conversión/orientación, extraídos para poder testearlos
// unitariamente sin hardware ni ML Kit. No dependen del detector.
// ============================================================================

/// Rotación a aplicar, derivada de `sensorOrientation` + `lensDirection`,
/// asumiendo dispositivo en portrait (la experiencia de cámara usa preview
/// vertical). `CameraFrame.metadata.orientation.rotationDegrees` es hoy `null`
/// (Camera Core no captura la orientación de display por frame); si en el
/// futuro lo provee, se respeta.
///
/// VERIFICACIÓN FÍSICA PENDIENTE: fórmula estándar ML Kit + package:camera para
/// portrait. En landscape o con `sensorOrientation` atípico puede requerir
/// ajuste; se marca para calibrar en dispositivo.
int rotationForFrame(CameraFrame frame) {
  final provided = frame.metadata.orientation.rotationDegrees;
  if (provided != null) return provided % 360;

  final sensor = frame.metadata.sensorOrientation;
  const deviceOrientationDegrees = 0; // portrait
  if (frame.metadata.lensDirection == CameraLensDirection.front) {
    // Frontal: se compensa el espejo del sensor.
    return (sensor + deviceOrientationDegrees) % 360;
  }
  // Trasera.
  return (sensor - deviceOrientationDegrees + 360) % 360;
}

/// Tamaño del frame tal como lo ve ML Kit tras aplicar la rotación: para 90/270
/// los ejes se intercambian respecto a `frame.width/height`.
Size rotatedFrameSize(CameraFrame frame, int rotationDegrees) {
  final swap = rotationDegrees % 180 == 90;
  final w = frame.width.toDouble();
  final h = frame.height.toDouble();
  return swap ? Size(h, w) : Size(w, h);
}

/// Convierte un frame YUV_420_888 (triplanar Android, con posibles strides y
/// pixelStride en el plano de croma) al layout NV21 (Y completo seguido de
/// V,U intercalados). Copia mínima, una pasada. Devuelve `null` si no hay 3
/// planos.
Uint8List? yuv420ToNv21(CameraFrame frame) {
  if (frame.planes.length < 3) return null;
  final width = frame.width;
  final height = frame.height;

  final yPlane = frame.planes[0];
  final uPlane = frame.planes[1];
  final vPlane = frame.planes[2];

  final out = Uint8List(
      width * height + 2 * ((width + 1) ~/ 2) * ((height + 1) ~/ 2));

  // --- Copia del plano Y respetando el row stride ---
  var outPos = 0;
  final yBytes = yPlane.bytes;
  final yRowStride = yPlane.bytesPerRow;
  if (yRowStride == width) {
    out.setRange(0, width * height, yBytes);
    outPos = width * height;
  } else {
    for (var row = 0; row < height; row++) {
      final srcStart = row * yRowStride;
      out.setRange(outPos, outPos + width, yBytes, srcStart);
      outPos += width;
    }
  }

  // --- Croma intercalado en orden V,U (NV21) ---
  final uBytes = uPlane.bytes;
  final vBytes = vPlane.bytes;
  final uRowStride = uPlane.bytesPerRow;
  final vRowStride = vPlane.bytesPerRow;
  final uPixelStride = uPlane.bytesPerPixel ?? 1;
  final vPixelStride = vPlane.bytesPerPixel ?? 1;

  final chromaHeight = (height + 1) ~/ 2;
  final chromaWidth = (width + 1) ~/ 2;

  for (var row = 0; row < chromaHeight; row++) {
    var uCol = row * uRowStride;
    var vCol = row * vRowStride;
    for (var col = 0; col < chromaWidth; col++) {
      if (outPos + 1 >= out.length) break;
      out[outPos++] = vBytes[vCol];
      out[outPos++] = uBytes[uCol];
      uCol += uPixelStride;
      vCol += vPixelStride;
    }
  }

  return out;
}
