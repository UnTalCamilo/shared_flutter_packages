import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera_core/camera_core.dart';
import 'package:flutter_test/flutter_test.dart';

// Helpers puros del adaptador (no instancian ML Kit): importables en tests del
// propio paquete.
import 'package:face_detection/src/infrastructure/mlkit_face_adapter.dart';

import 'support/frame_factory.dart';

void main() {
  group('rotationForFrame', () {
    test('trasera: sensor - device(0) → sensor', () {
      final frame = fakeFrame(
        lens: CameraLensDirection.back,
        sensorOrientation: 90,
      );
      expect(rotationForFrame(frame), 90);
    });

    test('frontal: sensor + device(0) → sensor', () {
      final frame = fakeFrame(
        lens: CameraLensDirection.front,
        sensorOrientation: 270,
      );
      expect(rotationForFrame(frame), 270);
    });

    test('respeta rotationDegrees del frame si está presente', () {
      final frame = CameraFrame(
        planes: [
          PlaneDescriptor(bytes: Uint8List(4), bytesPerRow: 2),
        ],
        width: 2,
        height: 2,
        format: CameraFrameFormat.bgra8888,
        layout: FrameLayout.bgra8888,
        metadata: CameraFrameMetadata(
          timestamp: DateTime(2024, 1, 1),
          orientation: const FrameOrientation(
            sensorOrientation: 90,
            rotationDegrees: 180,
          ),
          lensDirection: CameraLensDirection.back,
        ),
        frameId: 0,
      );
      expect(rotationForFrame(frame), 180);
    });
  });

  group('rotatedFrameSize', () {
    test('0/180 conserva ejes', () {
      final frame = fakeFrame(width: 640, height: 480);
      expect(rotatedFrameSize(frame, 0), const Size(640, 480));
      expect(rotatedFrameSize(frame, 180), const Size(640, 480));
    });

    test('90/270 intercambia ejes', () {
      final frame = fakeFrame(width: 640, height: 480);
      expect(rotatedFrameSize(frame, 90), const Size(480, 640));
      expect(rotatedFrameSize(frame, 270), const Size(480, 640));
    });
  });

  group('yuv420ToNv21', () {
    test('produce buffer del tamaño NV21 esperado (Y + VU)', () {
      const w = 64;
      const h = 48;
      final frame = fakeFrame(width: w, height: h);
      final nv21 = yuv420ToNv21(frame);
      expect(nv21, isNotNull);
      // NV21 = Y (w*h) + croma intercalado (2 * ceil(w/2) * ceil(h/2)).
      const expected = w * h + 2 * ((w + 1) ~/ 2) * ((h + 1) ~/ 2);
      expect(nv21!.length, expected);
    });

    test('devuelve null si no hay 3 planos', () {
      final frame = CameraFrame(
        planes: [
          PlaneDescriptor(bytes: Uint8List(10), bytesPerRow: 10),
        ],
        width: 4,
        height: 4,
        format: CameraFrameFormat.yuv420,
        layout: FrameLayout.unknown,
        metadata: CameraFrameMetadata(
          timestamp: DateTime(2024, 1, 1),
          orientation: const FrameOrientation(sensorOrientation: 0),
          lensDirection: CameraLensDirection.back,
        ),
        frameId: 0,
      );
      expect(yuv420ToNv21(frame), isNull);
    });

    test('intercala croma en orden V,U respetando pixelStride', () {
      // Plano U lleno de 0x11, plano V lleno de 0x22, pixelStride 1 (compacto).
      const w = 2;
      const h = 2;
      final y = Uint8List(w * h)..fillRange(0, w * h, 0xAA);
      final u = Uint8List(1)..fillRange(0, 1, 0x11);
      final v = Uint8List(1)..fillRange(0, 1, 0x22);
      final frame = CameraFrame(
        planes: [
          PlaneDescriptor(bytes: y, bytesPerRow: w, bytesPerPixel: 1),
          PlaneDescriptor(bytes: u, bytesPerRow: 1, bytesPerPixel: 1),
          PlaneDescriptor(bytes: v, bytesPerRow: 1, bytesPerPixel: 1),
        ],
        width: w,
        height: h,
        format: CameraFrameFormat.yuv420,
        layout: FrameLayout.yuv420Triplanar,
        metadata: CameraFrameMetadata(
          timestamp: DateTime(2024, 1, 1),
          orientation: const FrameOrientation(sensorOrientation: 0),
          lensDirection: CameraLensDirection.back,
        ),
        frameId: 0,
      );
      final nv21 = yuv420ToNv21(frame)!;
      // Primeros 4 bytes = Y; luego V,U (NV21 = Y + VU).
      expect(nv21.sublist(0, 4), [0xAA, 0xAA, 0xAA, 0xAA]);
      expect(nv21[4], 0x22); // V primero
      expect(nv21[5], 0x11); // U después
    });
  });
}
