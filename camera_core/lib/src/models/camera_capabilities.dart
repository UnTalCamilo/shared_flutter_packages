import 'camera_config.dart';

/// Capacidades soportadas por una cámara física concreta.
///
/// Se calcula tras inicializar el controlador y se expone al consumidor para
/// que ajuste su UI (por ejemplo, deshabilitar un control de zoom si no está
/// soportado).
class CameraCapabilities {
  final double minZoom;
  final double maxZoom;
  final double minExposureOffset;
  final double maxExposureOffset;
  final double exposureStepSize;
  final List<ResolutionPreset> supportedResolutions;
  final List<FlashMode> supportedFlashModes;
  final List<FocusMode> supportedFocusModes;
  final bool supportsExposureControl;
  final bool supportsFocusControl;
  final bool supportsZoom;

  const CameraCapabilities({
    required this.minZoom,
    required this.maxZoom,
    required this.minExposureOffset,
    required this.maxExposureOffset,
    required this.exposureStepSize,
    required this.supportedResolutions,
    required this.supportedFlashModes,
    required this.supportedFocusModes,
    required this.supportsExposureControl,
    required this.supportsFocusControl,
    required this.supportsZoom,
  });
}
