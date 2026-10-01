import 'dart:ui' show Rect, Offset;

import 'qr_format.dart';

/// Resultado de una lectura de código. Modelo propio del paquete.
///
/// No expone tipos de ML Kit (`Barcode`, `BarcodeFormat`). Cada campo existe
/// por una razón de consumo concreta; los campos de ML Kit que no aportan a una
/// capacidad QR genérica (p. ej. `calendarEvent`, `wifi`, `contactInfo`,
/// `displayValue`) se omiten deliberadamente.
class QrScanResult {
  /// Valor crudo decodificado. Es la razón de ser del scanner.
  final String rawValue;

  /// Formato del código, para que la app distinga QR de otros si los habilitó.
  final QrFormat format;

  /// Caja delimitadora en coordenadas del frame analizado (post-rotación), si
  /// ML Kit la provee. `null` cuando no está disponible. Útil para pintar un
  /// recuadro sobre el preview.
  final Rect? boundingBox;

  /// Vértices del polígono del código en coordenadas del frame, si están
  /// disponibles. Más preciso que [boundingBox] para dibujar el contorno real.
  /// `null` cuando no se proveen.
  final List<Offset>? cornerPoints;

  /// Momento de la detección. Permite correlacionar/depurar y es la base de la
  /// política de duplicados por tiempo.
  final DateTime timestamp;

  const QrScanResult({
    required this.rawValue,
    required this.format,
    required this.timestamp,
    this.boundingBox,
    this.cornerPoints,
  });

  @override
  String toString() =>
      'QrScanResult(${format.name}: "$rawValue")';
}
