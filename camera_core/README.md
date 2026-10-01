# camera_core

Infraestructura de cámara reutilizable para Flutter, independiente de cualquier caso de uso de visión artificial.

`camera_core` encapsula el plugin [`camera`](https://pub.dev/packages/camera) tras un contrato propio (`ICameraService`) y un conjunto de modelos de dominio neutrales. **No conoce** QR, ML Kit, detección facial, OCR ni documentos: expone un `CameraFrame` neutral que las capacidades de visión consumen desde fuera.

```text
camera_core
    │
    └── CameraFrame
           ├── (futuro) QR
           ├── (futuro) Face Detection
           ├── (futuro) OCR
           └── (futuro) Document Scanner
```

## Responsabilidades

- Inicialización, selección de cámara y permisos.
- Ciclo de vida (`initialize` / `pause` / `resume` / `dispose`).
- Preview reutilizable (`CameraView`).
- Controles: zoom, flash, enfoque, exposición, resolución.
- Captura de fotografías.
- Capacidades del dispositivo (`CameraCapabilities`).
- Estado reactivo (`stateStream`).
- Errores tipados (`CameraException`).
- Stream de frames (`frameStream`) con configuración (`FrameStreamConfig`).
- Orientación y metadata necesaria del frame.
- Liberación de recursos.

## Reglas arquitectónicas

- Solo `CameraControllerWrapper` (interno) importa `package:camera`.
- Solo `CameraPermissionHandler` (interno) importa `permission_handler`.
- El contrato público no expone tipos del plugin (`CameraController`, `CameraImage`, `XFile`, ...).
- No depende de ningún framework de inyección de dependencias: la app cablea su propio DI.
- Logging mediante el puerto `CameraLogger`; sin dependencia de una librería de logging concreta.

## Uso

```dart
import 'package:camera_core/camera_core.dart';

// La app construye y cablea la implementación en su propio DI.
final ICameraService camera = CameraCore.createService();

await camera.initialize(preferredDirection: CameraLensDirection.back);

// Widget de preview reutilizable.
CameraView(controller: camera);
```

## Qué NO entra en este paquete

Detección facial, reconocimiento facial, QR/barcode, OCR, escaneo documental, efectos GPU (shaders/looks) y cualquier UI de producto. Esas capacidades viven en paquetes/consumidores separados que dependen de `camera_core`.
