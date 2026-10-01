import 'package:camera_core/camera_core.dart';

import 'contracts/qr_scanner_service.dart';
import 'infrastructure/qr_logger.dart';
import 'models/qr_duplicate_policy.dart';
import 'models/qr_scan_result.dart';
import 'models/qr_scan_throttle.dart';
import 'models/qr_scanner_config.dart';
import 'services/qr_scan_session_impl.dart';
import 'services/qr_scanner_impl.dart';

/// Fábrica de conveniencia para construir las piezas de `qr_scanner` sin
/// exponer las clases internas ni depender de un framework de DI.
abstract final class QrScanner {
  const QrScanner._();

  /// Crea un detector de códigos. Por defecto solo QR.
  static IQrScanner create({
    QrScannerConfig config = QrScannerConfig.qrOnly,
    QrLogger logger = const DebugPrintQrLogger(),
  }) {
    return QrScannerImpl(config: config, logger: logger);
  }

  /// Crea una sesión que consume un `Stream<CameraFrame>` (típicamente
  /// `ICameraService.frameStream`) y emite [QrScanResult] ya filtrados por
  /// throttle y política de duplicados.
  static IQrScanSession session({
    required IQrScanner scanner,
    required Stream<CameraFrame> frames,
    QrScanThrottle throttle = QrScanThrottle.none,
    QrDuplicatePolicy duplicatePolicy =
        const QrDuplicatePolicy.cooldown(Duration(seconds: 2)),
  }) {
    return QrScanSessionImpl(
      scanner: scanner,
      frames: frames,
      throttle: throttle,
      duplicatePolicy: duplicatePolicy,
    );
  }
}
