import 'dart:typed_data';

import 'package:camera_core/camera_core.dart';

/// Construye un [CameraFrame] YUV420 triplanar mínimo para tests.
CameraFrame fakeFrame({
  int id = 0,
  int width = 64,
  int height = 48,
  CameraLensDirection lens = CameraLensDirection.back,
  int sensorOrientation = 90,
  CameraFrameFormat format = CameraFrameFormat.yuv420,
  DateTime? timestamp,
}) {
  final chromaW = (width + 1) ~/ 2;
  final chromaH = (height + 1) ~/ 2;
  // Croma con pixelStride=2 (layout típico Android YUV_420_888): los planos U/V
  // están físicamente dimensionados para rowStride*height con stride 2, no de
  // forma compacta. Se dimensiona en consecuencia para reflejar el dispositivo
  // real y no desbordar la lectura por pixelStride.
  const chromaPixelStride = 2;
  final chromaRowStride = chromaW * chromaPixelStride;
  final chromaSize = chromaRowStride * chromaH;
  return CameraFrame(
    planes: [
      PlaneDescriptor(
          bytes: Uint8List(width * height), bytesPerRow: width, bytesPerPixel: 1),
      PlaneDescriptor(
          bytes: Uint8List(chromaSize),
          bytesPerRow: chromaRowStride,
          bytesPerPixel: chromaPixelStride),
      PlaneDescriptor(
          bytes: Uint8List(chromaSize),
          bytesPerRow: chromaRowStride,
          bytesPerPixel: chromaPixelStride),
    ],
    width: width,
    height: height,
    format: format,
    layout: FrameLayout.yuv420Triplanar,
    metadata: CameraFrameMetadata(
      timestamp: timestamp ?? DateTime(2024, 1, 1),
      orientation: FrameOrientation(sensorOrientation: sensorOrientation),
      lensDirection: lens,
    ),
    frameId: id,
  );
}
