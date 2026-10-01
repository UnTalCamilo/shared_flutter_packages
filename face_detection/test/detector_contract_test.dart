import 'dart:ui' show Rect, Size;

import 'package:camera_core/camera_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:face_detection/face_detection.dart';

import 'support/frame_factory.dart';

/// Fake de [IFaceDetector] que no toca ML Kit ni hardware. Permite verificar el
/// contrato público (resultado / vacío / null / dispose idempotente) y los
/// comportamientos de los que depende el consumidor (CAPPFRONT), sin un motor
/// real. El `MlkitFaceAdapter` real se cubre por integración (requiere
/// dispositivo).
class FakeFaceDetector implements IFaceDetector {
  final FaceDetectionResult? Function(CameraFrame frame) onDetect;
  int detectCalls = 0;
  int disposeCalls = 0;
  bool _disposed = false;

  FakeFaceDetector(this.onDetect);

  @override
  Future<FaceDetectionResult?> detect(CameraFrame frame) async {
    detectCalls++;
    if (_disposed) return null; // tras dispose: sin actualización
    return onDetect(frame);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    _disposed = true; // idempotente: múltiples llamadas no fallan
  }
}

void main() {
  DetectedFace faceAt(double l, double t, double r, double b) => DetectedFace(
        boundingBox: Rect.fromLTRB(l, t, r, b),
        landmarks: const {},
        frameSize: const Size(640, 480),
        lensDirection: CameraLensDirection.back,
      );

  group('IFaceDetector — contrato', () {
    test('devuelve un resultado con una cara', () async {
      final detector = FakeFaceDetector((f) => FaceDetectionResult(
            faces: [faceAt(0, 0, 10, 10)],
            timestamp: f.metadata.timestamp,
            frameId: f.frameId,
          ));
      final result = await detector.detect(fakeFrame(id: 1));
      expect(result, isNotNull);
      expect(result!.faces, hasLength(1));
      expect(result.isEmpty, isFalse);
      expect(result.frameId, 1);
    });

    test('resultado vacío (sin rostros)', () async {
      final detector = FakeFaceDetector(
        (f) => FaceDetectionResult.empty(
            timestamp: f.metadata.timestamp, frameId: f.frameId),
      );
      final result = await detector.detect(fakeFrame(id: 2));
      expect(result, isNotNull);
      expect(result!.isEmpty, isTrue);
    });

    test('múltiples rostros', () async {
      final detector = FakeFaceDetector((f) => FaceDetectionResult(
            faces: [
              faceAt(0, 0, 10, 10),
              faceAt(20, 20, 30, 30),
              faceAt(40, 40, 50, 50),
            ],
            timestamp: f.metadata.timestamp,
            frameId: f.frameId,
          ));
      final result = await detector.detect(fakeFrame(id: 3));
      expect(result!.faces, hasLength(3));
    });

    test('frame no procesable → null (sin romper el flujo)', () async {
      final detector = FakeFaceDetector((_) => null);
      final result = await detector.detect(fakeFrame(id: 4));
      expect(result, isNull);
      expect(detector.detectCalls, 1);
    });
  });

  group('IFaceDetector — ciclo de vida', () {
    test('dispose es idempotente', () async {
      final detector = FakeFaceDetector((_) => null);
      await detector.dispose();
      await detector.dispose();
      expect(detector.disposeCalls, 2);
    });

    test('detect tras dispose devuelve null', () async {
      final detector = FakeFaceDetector((f) => FaceDetectionResult(
            faces: [faceAt(0, 0, 10, 10)],
            timestamp: f.metadata.timestamp,
            frameId: f.frameId,
          ));
      await detector.dispose();
      final result = await detector.detect(fakeFrame(id: 5));
      expect(result, isNull);
    });
  });

  group('FaceDetection.create', () {
    test('devuelve un IFaceDetector sin inicializar hardware', () {
      final detector = FaceDetection.create(
        config: const FaceDetectionConfig(maxFaces: 3),
        logger: const SilentFaceDetectionLogger(),
      );
      expect(detector, isA<IFaceDetector>());
      // No se llama detect(): requeriría ML Kit/hardware.
    });
  });
}
