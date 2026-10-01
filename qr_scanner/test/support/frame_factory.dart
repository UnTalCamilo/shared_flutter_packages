import 'dart:typed_data';

import 'package:camera_core/camera_core.dart';

/// Construye un [CameraFrame] YUV420 triplanar mínimo para tests.
CameraFrame fakeFrame({
  int id = 0,
  int width = 64,
  int height = 48,
  CameraLensDirection lens = CameraLensDirection.back,
  int sensorOrientation = 90,
  DateTime? timestamp,
}) {
  final chromaW = (width + 1) ~/ 2;
  final chromaH = (height + 1) ~/ 2;
  return CameraFrame(
    planes: [
      PlaneDescriptor(
          bytes: Uint8List(width * height), bytesPerRow: width, bytesPerPixel: 1),
      PlaneDescriptor(
          bytes: Uint8List(chromaW * chromaH),
          bytesPerRow: chromaW,
          bytesPerPixel: 2),
      PlaneDescriptor(
          bytes: Uint8List(chromaW * chromaH),
          bytesPerRow: chromaW,
          bytesPerPixel: 2),
    ],
    width: width,
    height: height,
    format: CameraFrameFormat.yuv420,
    layout: FrameLayout.yuv420Triplanar,
    metadata: CameraFrameMetadata(
      timestamp: timestamp ?? DateTime(2024, 1, 1),
      orientation: FrameOrientation(sensorOrientation: sensorOrientation),
      lensDirection: lens,
    ),
    frameId: id,
  );
}
