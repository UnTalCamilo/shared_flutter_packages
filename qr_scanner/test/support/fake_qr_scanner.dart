import 'package:camera_core/camera_core.dart';
import 'package:qr_scanner/qr_scanner.dart';

/// Fake de [IQrScanner] para tests de sesión: devuelve resultados programados
/// sin tocar ML Kit ni hardware. Registra cuántas detecciones recibió.
class FakeQrScanner implements IQrScanner {
  /// Función que decide el resultado para un frame dado.
  final QrScanResult? Function(CameraFrame frame) onDetect;

  /// Retardo artificial para simular trabajo en vuelo (drop-if-busy).
  final Duration delay;

  int detectCalls = 0;
  bool disposed = false;

  FakeQrScanner(this.onDetect, {this.delay = Duration.zero});

  @override
  Future<QrScanResult?> detect(CameraFrame frame) async {
    detectCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return onDetect(frame);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

/// Resultado QR de prueba con un valor dado.
QrScanResult qrResult(String value, {DateTime? ts}) => QrScanResult(
      rawValue: value,
      format: QrFormat.qrCode,
      timestamp: ts ?? DateTime(2024, 1, 1),
    );
