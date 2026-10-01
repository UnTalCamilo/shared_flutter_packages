# qr_scanner

Capacidad de lectura de códigos QR/barras para Flutter, construida **sobre `camera_core`**.

`qr_scanner` provee una **capacidad** (detectar códigos en un `CameraFrame`), no una experiencia visual completa. La aplicación decide cómo presentar la cámara.

```text
CameraFrame            (camera_core)
     ↓
IQrScanner.detect      (qr_scanner)
     ↓
QrScanResult           (modelo propio)
```

## Principios

- Depende de `camera_core` en una sola dirección. `camera_core` **no** conoce `qr_scanner`.
- ML Kit vive **confinado** en `src/infrastructure/mlkit_barcode_adapter.dart`. Ningún tipo de ML Kit (`Barcode`, `InputImage`, `BarcodeFormat`) cruza la API pública.
- No expone `package:camera` ni `CameraController`.
- Sin framework de inyección de dependencias.
- UI opcional y componible: `QrScannerOverlay` se coloca sobre cualquier preview; no crea preview, controles, Scaffold ni navegación.

## Uso

```dart
import 'package:camera_core/camera_core.dart';
import 'package:qr_scanner/qr_scanner.dart';

final camera = CameraCore.createService();
await camera.initialize();

final scanner = QrScanner.create();           // solo QR por defecto
await camera.startFrameStream(const FrameStreamConfig(maxFps: 10));

final session = QrScanner.session(
  scanner: scanner,
  frames: camera.frameStream,
  duplicatePolicy: const QrDuplicatePolicy.cooldown(Duration(seconds: 2)),
);

session.results.listen((r) => print('QR: ${r.rawValue}'));

// Composición libre de la UI:
Stack(children: [
  CameraPreview(controller: camera),
  const QrScannerOverlay(),
]);
```

## Procesamiento de frames

La cámara produce frames continuamente. La sesión aplica:
- **drop-if-busy:** un solo frame en vuelo; los demás se descartan (no se encolan).
- **throttle** opcional por intervalo mínimo.
- **política de duplicados** explícita (`cooldown` / `once` / `emitEveryFrame`).

## Qué NO hace

Preview, controles, flash, zoom, captura, permisos, lifecycle (eso es `camera_core`); OCR, caras, documentos; exponer tipos de ML Kit o del plugin `camera`.
