import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scanner/qr_scanner.dart';

void main() {
  group('QrScanResult', () {
    test('construye con campos mínimos y opcionales nulos', () {
      final r = QrScanResult(
        rawValue: 'ABC',
        format: QrFormat.qrCode,
        timestamp: DateTime(2024, 1, 1),
      );
      expect(r.rawValue, 'ABC');
      expect(r.format, QrFormat.qrCode);
      expect(r.boundingBox, isNull);
      expect(r.cornerPoints, isNull);
      expect(r.toString(), contains('ABC'));
    });

    test('transporta boundingBox y cornerPoints cuando se proveen', () {
      final r = QrScanResult(
        rawValue: 'X',
        format: QrFormat.ean13,
        timestamp: DateTime(2024, 1, 1),
        boundingBox: const Rect.fromLTWH(0, 0, 10, 10),
        cornerPoints: const [Offset(0, 0), Offset(10, 0)],
      );
      expect(r.boundingBox, const Rect.fromLTWH(0, 0, 10, 10));
      expect(r.cornerPoints, hasLength(2));
      expect(r.format, QrFormat.ean13);
    });
  });

  group('QrScannerConfig', () {
    test('por defecto es solo QR', () {
      expect(QrScannerConfig.qrOnly.formats, {QrFormat.qrCode});
      expect(const QrScannerConfig().formats, {QrFormat.qrCode});
    });

    test('permite habilitar múltiples formatos', () {
      const c = QrScannerConfig(formats: {QrFormat.qrCode, QrFormat.ean13});
      expect(c.formats, containsAll([QrFormat.qrCode, QrFormat.ean13]));
    });
  });

  group('QrScanThrottle', () {
    test('none no limita', () {
      expect(QrScanThrottle.none.minInterval, Duration.zero);
    });

    test('fps calcula el intervalo mínimo', () {
      expect(QrScanThrottle.fps(10).minInterval,
          const Duration(milliseconds: 100));
      expect(QrScanThrottle.fps(0).minInterval, Duration.zero);
    });
  });
}
