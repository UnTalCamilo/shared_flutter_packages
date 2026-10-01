import 'qr_format.dart';

/// Configuración del detector de códigos.
///
/// Por defecto, el scanner solo busca [QrFormat.qrCode]: es `qr_scanner`, no un
/// lector de barras genérico. Se pueden habilitar más formatos sin cambiar la
/// arquitectura.
class QrScannerConfig {
  /// Formatos a detectar. Vacío = solo QR (equivalente a `{QrFormat.qrCode}`).
  final Set<QrFormat> formats;

  const QrScannerConfig({
    this.formats = const {QrFormat.qrCode},
  });

  static const QrScannerConfig qrOnly = QrScannerConfig();
}
