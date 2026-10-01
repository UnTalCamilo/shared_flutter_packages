## 0.2.0

- UI componible en tres niveles explícitos, sin flags de visibilidad:
  - `CameraPreview`: primitivo de render puro para composición libre
    (Stack, preview pequeño, overlays externos como un futuro QR).
  - `CameraStateBuilder`: máquina de estados de presentación reutilizable.
  - Controles sueltos (una pieza por capacidad): `CameraCaptureButton`,
    `CameraFlashButton`, `CameraSwitchButton`, `CameraZoomControl`,
    `CameraFocusGesture`.
  - `CameraView`: ahora es una experiencia CONVENIENTE que compone preview +
    `controlsBuilder` + overlay; deja de ser "preview con estados" y no impone
    diseño.
- `CameraZoomControl` incorpora serialización latest-wins interna.
- Tests de widget añadidos; test de aislamiento ampliado (la UI no se acopla a
  la infraestructura interna).

## 0.1.0

- Extracción inicial de la infraestructura de cámara desde CAPPFRONT.
- `ICameraService` + `CameraServiceImpl` (orquestación).
- `CameraControllerWrapper` como único punto de acoplamiento a `package:camera`.
- `CameraPermissionHandler` sobre `permission_handler`.
- Modelos neutrales: `CameraConfig`, `CameraCapabilities`, `CameraInfo`, `CameraState`,
  `CameraInitResult`, `CameraException`, `CaptureResult`, `CameraFrame`, `FrameStreamConfig`.
- `CameraFrame` recortado (A1): representa solo imagen + metadata para interpretarla;
  el estado de control (zoom/exposición) queda fuera del frame.
- `CameraView` como widget de preview reutilizable y delgado.
- `CameraLogger` como puerto de logging (sin dependencia de una librería concreta).
- Sin dependencia de `injectable`/`get_it`: la app resuelve su DI.
