/// Formato de un código detectado.
///
/// Enum propio del paquete: NO es un espejo 1:1 de `BarcodeFormat` de ML Kit.
/// Transporta el subconjunto estable y útil para una UI; el adaptador mapea
/// desde el tipo de ML Kit y colapsa a [QrFormat.unknown] lo no contemplado.
///
/// Aunque el paquete se llama `qr_scanner` y por defecto solo lee [qrCode], se
/// permite habilitar otros formatos de barras comunes sin generalizar a OCR,
/// caras ni documentos.
enum QrFormat {
  qrCode,
  aztec,
  dataMatrix,
  pdf417,
  ean13,
  ean8,
  code128,
  code39,
  code93,
  codabar,
  itf,
  upca,
  upce,

  /// Formato detectado pero no mapeado a un valor propio conocido.
  unknown,
}
