import 'package:camera_core/camera_core.dart';

import '../contracts/qr_scanner_service.dart';
import '../infrastructure/mlkit_barcode_adapter.dart';
import '../infrastructure/qr_logger.dart';
import '../models/qr_scan_result.dart';
import '../models/qr_scanner_config.dart';

/// Implementación de [IQrScanner] que delega la detección en el adaptador de
/// ML Kit. No conoce streams ni estado de sesión: analiza un frame y responde.
class QrScannerImpl implements IQrScanner {
  final MlkitBarcodeAdapter _adapter;

  QrScannerImpl({
    QrScannerConfig config = QrScannerConfig.qrOnly,
    QrLogger logger = const DebugPrintQrLogger(),
  }) : _adapter = MlkitBarcodeAdapter(
          formats: config.formats,
          logger: logger,
        );

  @override
  Future<QrScanResult?> detect(CameraFrame frame) => _adapter.detect(frame);

  @override
  Future<void> dispose() => _adapter.close();
}
