## 0.1.0

- Extracción inicial de la capacidad de detección facial desde CAPPFRONT.
- `IFaceDetector.detect(CameraFrame) → FaceDetectionResult?` + `dispose()`.
- `FaceDetection.create()` como fábrica (sin DI).
- ML Kit (`google_mlkit_face_detection ^0.15.1`) confinado en el adaptador; no
  cruza la API pública. Depende de `google_mlkit_commons ^0.13.0` (misma línea
  que `qr_scanner`).
- Modelos propios: `FaceDetectionResult`, `DetectedFace`, `FaceLandmarkKey`
  (bounding box, landmarks básicos y ángulos de Euler), trasladados tal cual.
- `FaceDetectionConfig` mínima: `maxFaces`, `enableLandmarks`, `minFaceSize`,
  `performanceMode`.
- Puerto de logging `FaceDetectionLogger`.
- Preview-only: sin estado de stream; throttle/drop-if-busy y UI quedan en la
  app. Solo detección geométrica; sin reconocimiento ni verificación.
