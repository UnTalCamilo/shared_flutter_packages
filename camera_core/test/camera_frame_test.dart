import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:camera_core/camera_core.dart';

CameraFrameMetadata _meta({int sensor = 90}) => CameraFrameMetadata(
      timestamp: DateTime(2024, 1, 1),
      orientation: FrameOrientation(sensorOrientation: sensor),
      lensDirection: CameraLensDirection.back,
    );

void main() {
  group('CameraFrame — representación multiplataforma', () {
    test('Android YUV420 triplanar: conserva 3 planos, layout y strides', () {
      final frame = CameraFrame(
        planes: [
          PlaneDescriptor(
              bytes: Uint8List(1280 * 720),
              bytesPerRow: 1280,
              bytesPerPixel: 1),
          PlaneDescriptor(
              bytes: Uint8List(640 * 360), bytesPerRow: 640, bytesPerPixel: 2),
          PlaneDescriptor(
              bytes: Uint8List(640 * 360), bytesPerRow: 640, bytesPerPixel: 2),
        ],
        width: 1280,
        height: 720,
        format: CameraFrameFormat.yuv420,
        layout: FrameLayout.yuv420Triplanar,
        metadata: _meta(),
        frameId: 1,
      );

      expect(frame.planes.length, 3);
      expect(frame.layout, FrameLayout.yuv420Triplanar);
      expect(frame.format, CameraFrameFormat.yuv420);
      expect(frame.planes[0].bytesPerRow, 1280);
      expect(frame.planes[1].bytesPerPixel, 2);
      expect(frame.planes[0].byteSize, 1280 * 720);
    });

    test('iOS YUV420 biplanar: conserva 2 planos (Y, CbCr)', () {
      final frame = CameraFrame(
        planes: [
          PlaneDescriptor(
              bytes: Uint8List(1280 * 720),
              bytesPerRow: 1280,
              width: 1280,
              height: 720),
          PlaneDescriptor(
              bytes: Uint8List(640 * 360 * 2),
              bytesPerRow: 1280,
              width: 640,
              height: 360),
        ],
        width: 1280,
        height: 720,
        format: CameraFrameFormat.yuv420,
        layout: FrameLayout.yuv420Biplanar,
        metadata: _meta(),
        frameId: 2,
      );

      expect(frame.planes.length, 2);
      expect(frame.layout, FrameLayout.yuv420Biplanar);
      expect(frame.planes[0].bytesPerPixel, isNull);
      expect(frame.planes[0].width, 1280);
      expect(frame.planes[0].height, 720);
    });

    test('BGRA8888: un único plano interleaved', () {
      final frame = CameraFrame(
        planes: [
          PlaneDescriptor(
            bytes: Uint8List(1280 * 720 * 4),
            bytesPerRow: 1280 * 4,
            width: 1280,
            height: 720,
          ),
        ],
        width: 1280,
        height: 720,
        format: CameraFrameFormat.bgra8888,
        layout: FrameLayout.bgra8888,
        metadata: _meta(),
        frameId: 3,
      );

      expect(frame.planes.length, 1);
      expect(frame.layout, FrameLayout.bgra8888);
      expect(frame.format, CameraFrameFormat.bgra8888);
      expect(frame.planes.first.bytesPerRow, 1280 * 4);
      expect(frame.primaryPlaneBytes.length, 1280 * 720 * 4);
    });

    test('byteSize suma todos los planos; aspectRatio correcto', () {
      final frame = CameraFrame(
        planes: [
          PlaneDescriptor(bytes: Uint8List(100), bytesPerRow: 10),
          PlaneDescriptor(bytes: Uint8List(50), bytesPerRow: 10),
        ],
        width: 1280,
        height: 720,
        format: CameraFrameFormat.yuv420,
        layout: FrameLayout.yuv420Biplanar,
        metadata: _meta(),
        frameId: 4,
      );
      expect(frame.byteSize, 150);
      expect(frame.aspectRatio, closeTo(1280 / 720, 0.001));
    });

    test('metadata expone orientación y mirroring como heurística', () {
      final metadata = CameraFrameMetadata(
        timestamp: DateTime(2024, 1, 1),
        orientation: const FrameOrientation(
          sensorOrientation: 270,
          deviceOrientation: null,
          rotationDegrees: null,
        ),
        lensDirection: CameraLensDirection.front,
        isMirroredHeuristic: true,
      );

      expect(metadata.sensorOrientation, 270);
      expect(metadata.orientation.deviceOrientation, isNull);
      expect(metadata.orientation.rotationDegrees, isNull);
      expect(metadata.isMirroredHeuristic, true);
    });
  });

  group('CameraFrameMetadata — recorte A1', () {
    test('la metadata del frame solo transporta datos de la imagen', () {
      // El recorte A1 verifica, a nivel de contrato, que CameraFrameMetadata
      // NO contiene estado de control (zoom/exposure) ni dimensiones
      // duplicadas: su única fuente de dimensiones es el propio CameraFrame.
      // Este test documenta la frontera; si alguien reintroduce esos campos,
      // deberá revisar la decisión A1.
      final meta = _meta(sensor: 180);
      expect(meta.sensorOrientation, 180);
      expect(meta.lensDirection, CameraLensDirection.back);
      // Dimensiones viven en el frame, no en la metadata.
      final frame = CameraFrame(
        planes: [PlaneDescriptor(bytes: Uint8List(4), bytesPerRow: 2)],
        width: 2,
        height: 2,
        format: CameraFrameFormat.bgra8888,
        layout: FrameLayout.bgra8888,
        metadata: meta,
        frameId: 0,
      );
      expect(frame.width, 2);
      expect(frame.height, 2);
    });
  });

  group('FrameStreamConfig', () {
    test('formato solicitado por defecto es YUV420', () {
      const config = FrameStreamConfig();
      expect(config.requestedFormat, CameraFrameFormat.yuv420);
      expect(config.maxFps, isNull);
      expect(config.enableTimestamp, true);
    });

    test('copyWith permite modificar campos', () {
      const original = FrameStreamConfig();
      final modified = original.copyWith(
        requestedFormat: CameraFrameFormat.bgra8888,
        maxFps: 30,
        enableTimestamp: false,
      );
      expect(modified.requestedFormat, CameraFrameFormat.bgra8888);
      expect(modified.maxFps, 30);
      expect(modified.enableTimestamp, false);
    });
  });
}
