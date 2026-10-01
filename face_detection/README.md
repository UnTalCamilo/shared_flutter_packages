# face_detection

Capacidad de **detección facial geométrica** para Flutter, construida sobre `camera_core`.

Detecta *que hay un rostro y dónde* (bounding box, landmarks básicos, ángulos de Euler) a partir de un `CameraFrame`. **No** hace reconocimiento biométrico, identificación ni verificación de identidad: eso es una capacidad distinta y una decisión de negocio, fuera de este paquete.

```text
CameraFrame            (camera_core)
     ↓
IFaceDetector.detect   (face_detection)
     ↓
FaceDetectionResult    (modelo propio)
```

## Principios

- Depende de `camera_core` en una sola dirección. `camera_core` **no** conoce `face_detection`.
- ML Kit vive **confinado** en `src/infrastructure/mlkit_face_adapter.dart`. Ningún tipo de ML Kit (`Face`, `InputImage`, `FaceDetector`, `FaceLandmarkType`) cruza la API pública.
- No expone `package:camera` ni `CameraController`.
- Sin framework de inyección de dependencias.
- **Preview-only / sin estado de stream:** `detect(frame)` procesa un frame y responde. La estrategia de frames continuos (throttle, drop-if-busy) y la UI (guías, brackets, mapeo a la vista) son responsabilidad de la app consumidora.

## Uso

```dart
import 'package:camera_core/camera_core.dart';
import 'package:face_detection/face_detection.dart';

final camera = CameraCore.createService();
await camera.initialize();

final detector = FaceDetection.create();
await camera.startFrameStream(const FrameStreamConfig(maxFps: 10));

bool busy = false; // drop-if-busy lo decide la app
camera.frameStream.listen((frame) async {
  if (busy) return;
  busy = true;
  try {
    final result = await detector.detect(frame);
    // La app pinta/consume el resultado (coordenadas en espacio de frame).
  } finally {
    busy = false;
  }
});

// Al terminar:
await detector.dispose();
```

## Qué NO hace

Reconocimiento/identificación/verificación facial; preview, controles, captura, permisos, lifecycle (eso es `camera_core`); mapeo de coordenadas frame→vista (lo hace la app, ligado a cómo renderiza su preview); overlays de producto; exponer tipos de ML Kit o del plugin `camera`.
