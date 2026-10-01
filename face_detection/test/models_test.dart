import 'dart:ui';

import 'package:camera_core/camera_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:face_detection/face_detection.dart';

void main() {
  group('DetectedFace', () {
    test('construye con boundingBox, landmarks, frameSize, lens y euler', () {
      const face = DetectedFace(
        boundingBox: Rect.fromLTRB(10, 20, 60, 120),
        landmarks: {
          FaceLandmarkKey.leftEye: Offset(20, 40),
          FaceLandmarkKey.rightEye: Offset(50, 40),
          FaceLandmarkKey.noseBase: Offset(35, 70),
        },
        frameSize: Size(720, 1280),
        lensDirection: CameraLensDirection.front,
        eulerY: 3.0,
      );

      expect(face.boundingBox, const Rect.fromLTRB(10, 20, 60, 120));
      expect(face.landmarks.length, 3);
      expect(face.landmarks[FaceLandmarkKey.leftEye], const Offset(20, 40));
      expect(face.frameSize, const Size(720, 1280));
      expect(face.lensDirection, CameraLensDirection.front);
      expect(face.eulerY, 3.0);
      expect(face.eulerX, isNull);
      expect(face.eulerZ, isNull);
    });

    test('los tres landmarks del modelo están disponibles como claves propias',
        () {
      expect(
        FaceLandmarkKey.values,
        containsAll([
          FaceLandmarkKey.leftEye,
          FaceLandmarkKey.rightEye,
          FaceLandmarkKey.noseBase,
        ]),
      );
      expect(FaceLandmarkKey.values.length, 3);
    });
  });

  group('FaceDetectionResult', () {
    test('construye con lista de caras, timestamp y frameId', () {
      final result = FaceDetectionResult(
        faces: const [
          DetectedFace(
            boundingBox: Rect.fromLTRB(0, 0, 10, 10),
            landmarks: {},
            frameSize: Size(100, 100),
            lensDirection: CameraLensDirection.back,
          ),
        ],
        timestamp: DateTime(2024, 5, 1, 12),
        frameId: 42,
      );

      expect(result.faces.length, 1);
      expect(result.frameId, 42);
      expect(result.timestamp, DateTime(2024, 5, 1, 12));
      expect(result.isEmpty, isFalse);
    });

    test('empty() produce resultado sin caras', () {
      final empty = FaceDetectionResult.empty(
        timestamp: DateTime(2024, 1, 1),
        frameId: 7,
      );
      expect(empty.faces, isEmpty);
      expect(empty.isEmpty, isTrue);
      expect(empty.frameId, 7);
    });

    test('resultado con múltiples rostros preserva el orden y la cantidad', () {
      final result = FaceDetectionResult(
        faces: const [
          DetectedFace(
            boundingBox: Rect.fromLTRB(0, 0, 10, 10),
            landmarks: {},
            frameSize: Size(100, 100),
            lensDirection: CameraLensDirection.back,
          ),
          DetectedFace(
            boundingBox: Rect.fromLTRB(20, 20, 30, 30),
            landmarks: {},
            frameSize: Size(100, 100),
            lensDirection: CameraLensDirection.back,
          ),
        ],
        timestamp: DateTime(2024, 1, 1),
        frameId: 1,
      );
      expect(result.faces.length, 2);
      expect(result.isEmpty, isFalse);
    });
  });

  group('FaceDetectionConfig', () {
    test('valores por defecto reflejan la configuración actual', () {
      const c = FaceDetectionConfig();
      expect(c.maxFaces, 5);
      expect(c.enableLandmarks, isTrue);
      expect(c.minFaceSize, 0.15);
      expect(c.performanceMode, FaceDetectionPerformance.fast);
    });

    test('permite sobrescribir parámetros', () {
      const c = FaceDetectionConfig(
        maxFaces: 1,
        enableLandmarks: false,
        minFaceSize: 0.3,
        performanceMode: FaceDetectionPerformance.accurate,
      );
      expect(c.maxFaces, 1);
      expect(c.enableLandmarks, isFalse);
      expect(c.minFaceSize, 0.3);
      expect(c.performanceMode, FaceDetectionPerformance.accurate);
    });
  });
}
