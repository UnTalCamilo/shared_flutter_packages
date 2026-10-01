/// qr_scanner — capacidad de lectura de códigos QR/barras sobre `camera_core`.
///
/// Punto de entrada público. Solo se exportan la API de capacidad, los modelos
/// propios y la UI componible. ML Kit (`google_mlkit_barcode_scanning`) queda
/// confinado en el adaptador interno y NO se exporta; tampoco se expone
/// `package:camera` ni `CameraController`.
library qr_scanner;

// --- Contratos de capacidad ---
export 'src/contracts/qr_scanner_service.dart'
    show IQrScanner, IQrScanSession;

// --- Fábrica (sin DI, sin exponer internos) ---
export 'src/qr_scanner_factory.dart' show QrScanner;

// --- Modelos propios (frontera pública) ---
export 'src/models/qr_scan_result.dart' show QrScanResult;
export 'src/models/qr_format.dart' show QrFormat;
export 'src/models/qr_scanner_config.dart' show QrScannerConfig;
export 'src/models/qr_scan_throttle.dart' show QrScanThrottle;
export 'src/models/qr_duplicate_policy.dart'
    show QrDuplicatePolicy, QrDuplicateMatcher;

// --- UI componible opcional ---
export 'src/widgets/qr_scanner_overlay.dart' show QrScannerOverlay;

// --- Logging (puerto; la app puede puentearlo) ---
export 'src/infrastructure/qr_logger.dart'
    show QrLogger, DebugPrintQrLogger, SilentQrLogger;
