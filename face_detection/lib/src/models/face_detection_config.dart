/// Modo de rendimiento del detector facial.
///
/// Enum propio del paquete: no re-exporta `FaceDetectorMode` de ML Kit. El
/// adaptador mapea estos valores a las opciones del motor.
enum FaceDetectionPerformance { fast, accurate }

/// Configuración técnica mínima de la detección facial.
///
/// Refleja las opciones efectivamente usadas hoy. No se añaden parámetros sin
/// un consumidor real (tracking, contornos y clasificación quedan fuera).
class FaceDetectionConfig {
  /// Tope de caras reportadas por pasada.
  final int maxFaces;

  /// Habilita el cálculo de landmarks (ojos, base de la nariz).
  final bool enableLandmarks;

  /// Tamaño mínimo de cara relativo a la imagen (0..1).
  final double minFaceSize;

  /// Modo de rendimiento del detector.
  final FaceDetectionPerformance performanceMode;

  const FaceDetectionConfig({
    this.maxFaces = 5,
    this.enableLandmarks = true,
    this.minFaceSize = 0.15,
    this.performanceMode = FaceDetectionPerformance.fast,
  });
}
