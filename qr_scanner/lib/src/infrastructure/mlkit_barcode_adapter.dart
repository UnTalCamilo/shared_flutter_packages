import 'dart:io' show Platform;
import 'dart:math' show Point;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:camera_core/camera_core.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../models/qr_format.dart';
import '../models/qr_scan_result.dart';
import 'qr_logger.dart';

/// **Único punto del paquete que importa `google_mlkit_barcode_scanning`.**
///
/// Encapsula ML Kit por completo: construye/configura el `BarcodeScanner`,
/// convierte un [CameraFrame] de `camera_core` al `InputImage` requerido,
/// ejecuta la detección y traduce `Barcode`/`BarcodeFormat` a modelos propios
/// ([QrScanResult]/[QrFormat]). Esos tipos de ML Kit NO cruzan esta frontera.
///
/// La conversión de buffers (YUV420→NV21 respetando strides) y la derivación de
/// rotación replican el patrón ya probado en `camera_core`/CAPPFRONT, sin
/// depender de `package:camera`.
class MlkitBarcodeAdapter {
  final QrLogger _logger;
  final BarcodeScanner _scanner;
  bool _closed = false;

  MlkitBarcodeAdapter({
    required Set<QrFormat> formats,
    this._logger = const DebugPrintQrLogger(),
  }) : _scanner = BarcodeScanner(formats: _toBarcodeFormats(formats));

  /// Analiza un frame y devuelve el primer código, o `null` si no hay o el
  /// frame no es procesable. No lanza: ante error de ML Kit devuelve `null`.
  Future<QrScanResult?> detect(CameraFrame frame) async {
    if (_closed) return null;
    final input = _toInputImage(frame);
    if (input == null) return null;

    try {
      final barcodes = await _scanner.processImage(input);
      if (_closed || barcodes.isEmpty) return null;

      final barcode = barcodes.first;
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) return null;

      return QrScanResult(
        rawValue: value,
        format: _fromBarcodeFormat(barcode.format),
        boundingBox: barcode.boundingBox,
        cornerPoints: _mapCorners(barcode.cornerPoints),
        timestamp: frame.metadata.timestamp,
      );
      // Nota: boundingBox/cornerPoints de ML Kit no son null; se exponen como
      // opcionales en QrScanResult para consumidores que no los usen.
    } catch (e, s) {
      _logger.w('Fallo detectando barcode para frame ${frame.frameId}: $e');
      _logger.d('$s');
      return null;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _scanner.close();
    } catch (e) {
      _logger.w('Error cerrando BarcodeScanner: $e');
    }
  }

  // ========== CameraFrame → InputImage ==========

  InputImage? _toInputImage(CameraFrame frame) {
    if (frame.format == CameraFrameFormat.jpeg ||
        frame.format == CameraFrameFormat.unknown) {
      return null;
    }

    final rotation = _toInputImageRotation(_rotationFor(frame));

    if (Platform.isAndroid) {
      Uint8List? nv21;
      if (frame.format == CameraFrameFormat.nv21) {
        nv21 = frame.planes.first.bytes;
      } else if (frame.format == CameraFrameFormat.yuv420) {
        nv21 = _yuv420ToNv21(frame);
      }
      if (nv21 == null) return null;

      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: frame.width,
        ),
      );
    }

    if (Platform.isIOS) {
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

    // Web/desktop: no soportado. Degradar silenciosamente.
    return null;
  }

  /// YUV_420_888 (triplanar Android, con strides/pixelStride en croma) → NV21
  /// (Y completo + V,U intercalados). Copia mínima, una pasada.
  Uint8List? _yuv420ToNv21(CameraFrame frame) {
    if (frame.planes.length < 3) return null;
    final width = frame.width;
    final height = frame.height;

    final yPlane = frame.planes[0];
    final uPlane = frame.planes[1];
    final vPlane = frame.planes[2];

    final out = Uint8List(
        width * height + 2 * ((width + 1) ~/ 2) * ((height + 1) ~/ 2));

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

  /// Rotación derivada de `sensorOrientation` + `lensDirection` (portrait
  /// asumido; `rotationDegrees` del frame es `null` hoy). Si el frame ya trae
  /// `rotationDegrees`, se respeta.
  int _rotationFor(CameraFrame frame) {
    final provided = frame.metadata.orientation.rotationDegrees;
    if (provided != null) return provided % 360;

    final sensor = frame.metadata.sensorOrientation;
    const deviceOrientationDegrees = 0; // portrait
    if (frame.metadata.lensDirection == CameraLensDirection.front) {
      return (sensor + deviceOrientationDegrees) % 360;
    }
    return (sensor - deviceOrientationDegrees + 360) % 360;
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

  List<Offset>? _mapCorners(List<Point<int>> corners) {
    if (corners.isEmpty) return null;
    return corners
        .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
        .toList(growable: false);
  }

  // ========== Mapeos de formato (ML Kit ⇄ propio) ==========

  static List<BarcodeFormat> _toBarcodeFormats(Set<QrFormat> formats) {
    if (formats.isEmpty) return const [BarcodeFormat.qrCode];
    return formats.map(_toBarcodeFormat).toList(growable: false);
  }

  static BarcodeFormat _toBarcodeFormat(QrFormat f) => switch (f) {
        QrFormat.qrCode => BarcodeFormat.qrCode,
        QrFormat.aztec => BarcodeFormat.aztec,
        QrFormat.dataMatrix => BarcodeFormat.dataMatrix,
        QrFormat.pdf417 => BarcodeFormat.pdf417,
        QrFormat.ean13 => BarcodeFormat.ean13,
        QrFormat.ean8 => BarcodeFormat.ean8,
        QrFormat.code128 => BarcodeFormat.code128,
        QrFormat.code39 => BarcodeFormat.code39,
        QrFormat.code93 => BarcodeFormat.code93,
        QrFormat.codabar => BarcodeFormat.codabar,
        QrFormat.itf => BarcodeFormat.itf,
        QrFormat.upca => BarcodeFormat.upca,
        QrFormat.upce => BarcodeFormat.upce,
        QrFormat.unknown => BarcodeFormat.unknown,
      };

  QrFormat _fromBarcodeFormat(BarcodeFormat f) => switch (f) {
        BarcodeFormat.qrCode => QrFormat.qrCode,
        BarcodeFormat.aztec => QrFormat.aztec,
        BarcodeFormat.dataMatrix => QrFormat.dataMatrix,
        BarcodeFormat.pdf417 => QrFormat.pdf417,
        BarcodeFormat.ean13 => QrFormat.ean13,
        BarcodeFormat.ean8 => QrFormat.ean8,
        BarcodeFormat.code128 => QrFormat.code128,
        BarcodeFormat.code39 => QrFormat.code39,
        BarcodeFormat.code93 => QrFormat.code93,
        BarcodeFormat.codabar => QrFormat.codabar,
        BarcodeFormat.itf => QrFormat.itf,
        BarcodeFormat.upca => QrFormat.upca,
        BarcodeFormat.upce => QrFormat.upce,
        _ => QrFormat.unknown,
      };
}
