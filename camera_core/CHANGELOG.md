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
