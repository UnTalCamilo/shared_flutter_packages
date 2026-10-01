// Configuración de dominio para la cámara.
//
// Estos enums son **propios** del módulo y no re-exportan tipos del paquete
// `camera`. El mapeo hacia/desde los tipos del paquete ocurre únicamente en
// CameraControllerWrapper.

/// Dirección del lente de la cámara.
enum CameraLensDirection { front, back, external }

/// Preset de resolución/calidad de captura y preview.
enum ResolutionPreset { low, medium, high, veryHigh, ultraHigh, max }

/// Modo de flash.
enum FlashMode { off, on, auto, torch }

/// Modo de enfoque.
enum FocusMode { auto, locked, macro }

/// Configuración inmutable de una sesión de cámara.
class CameraConfig {
  final CameraLensDirection lensDirection;
  final ResolutionPreset resolutionPreset;
  final FlashMode flashMode;
  final FocusMode focusMode;
  final double zoomLevel;
  final double exposureOffset;
  final bool enableAudio;
  final bool lockPreviewOrientation;

  const CameraConfig({
    this.lensDirection = CameraLensDirection.back,
    this.resolutionPreset = ResolutionPreset.high,
    this.flashMode = FlashMode.off,
    this.focusMode = FocusMode.auto,
    this.zoomLevel = 1.0,
    this.exposureOffset = 0.0,
    this.enableAudio = false,
    this.lockPreviewOrientation = false,
  });

  CameraConfig copyWith({
    CameraLensDirection? lensDirection,
    ResolutionPreset? resolutionPreset,
    FlashMode? flashMode,
    FocusMode? focusMode,
    double? zoomLevel,
    double? exposureOffset,
    bool? enableAudio,
    bool? lockPreviewOrientation,
  }) {
    return CameraConfig(
      lensDirection: lensDirection ?? this.lensDirection,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      flashMode: flashMode ?? this.flashMode,
      focusMode: focusMode ?? this.focusMode,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      exposureOffset: exposureOffset ?? this.exposureOffset,
      enableAudio: enableAudio ?? this.enableAudio,
      lockPreviewOrientation:
          lockPreviewOrientation ?? this.lockPreviewOrientation,
    );
  }
}
