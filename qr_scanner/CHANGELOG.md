## 0.1.0

- `google_mlkit_barcode_scanning: ^0.16.1` (depende de `google_mlkit_commons
  ^0.13.0`) para alinearse con apps que usan `google_mlkit_face_detection`
  0.15.x. Requiere Dart `^3.12.0` / Flutter `>=3.44.0`.
- Capacidad inicial de lectura QR/barras sobre `camera_core`.
- `IQrScanner.detect(CameraFrame) → QrScanResult?` y sesión `IQrScanSession`
  sobre un `Stream<CameraFrame>` con drop-if-busy, throttle y política de
  duplicados explícita.
- ML Kit (`google_mlkit_barcode_scanning`) confinado en el adaptador; no cruza
  la API pública.
- Modelos propios: `QrScanResult`, `QrFormat`, `QrScannerConfig`,
  `QrScanThrottle`, `QrDuplicatePolicy`.
- UI componible opcional: `QrScannerOverlay`.
