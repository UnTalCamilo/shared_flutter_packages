import 'camera_frame.dart';

/// Configuración inmutable del stream de frames para procesamiento en tiempo
/// real.
///
/// [requestedFormat] es el formato SOLICITADO a la plataforma (vía
/// `imageFormatGroup` en el wrapper). NO garantiza el formato entregado: la
/// plataforma puede ignorarlo (p. ej. iOS puede entregar BGRA aunque se pida
/// YUV). El formato REAL siempre se lee del frame y se refleja en
/// [CameraFrame.format]; nunca se falsea con este valor.
class FrameStreamConfig {
  /// Formato solicitado a la plataforma. Por defecto YUV420 (nativo, sin
  /// conversión de color en CPU).
  final CameraFrameFormat requestedFormat;

  /// Límite de frames por segundo entregados. `null` o <= 0 = sin límite.
  final int? maxFps;

  final bool enableTimestamp;

  const FrameStreamConfig({
    this.requestedFormat = CameraFrameFormat.yuv420,
    this.maxFps,
    this.enableTimestamp = true,
  });

  FrameStreamConfig copyWith({
    CameraFrameFormat? requestedFormat,
    int? maxFps,
    bool? enableTimestamp,
  }) {
    return FrameStreamConfig(
      requestedFormat: requestedFormat ?? this.requestedFormat,
      maxFps: maxFps ?? this.maxFps,
      enableTimestamp: enableTimestamp ?? this.enableTimestamp,
    );
  }
}
