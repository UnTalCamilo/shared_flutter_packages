import 'package:flutter/services.dart' show DeviceOrientation;

/// Mapea un [DeviceOrientation] del paquete `camera` a grados (0/90/180/270).
///
/// Retorna `null` cuando la orientación es `null` o no se puede determinar,
/// evitando asumir silenciosamente un valor de retrato cuando la orientación
/// no se conoce.
int? deviceOrientationToDegrees(DeviceOrientation? orientation) {
  switch (orientation) {
    case DeviceOrientation.portraitUp:
      return 0;
    case DeviceOrientation.portraitDown:
      return 180;
    case DeviceOrientation.landscapeLeft:
      return 90;
    case DeviceOrientation.landscapeRight:
      return 270;
    default:
      return null;
  }
}

/// Calcula la rotación efectiva (0/90/180/270) que debe aplicarse al frame
/// para que quede en orientación vertical respecto al observador, según
/// las fórmulas de ML Kit.
///
/// Android:
/// - Cámara trasera: (sensorOrientation - deviceOrientationDegrees + 360) % 360
/// - Cámara frontal: (sensorOrientation + deviceOrientationDegrees + 270) % 360
///
/// iOS: se utiliza deviceOrientationDegrees directamente como rotación,
/// ya que AVFoundation entrega los frames ya orientados según el dispositivo.
///
/// Si [deviceOrientationDegrees] es `null`, devuelve `null` (no se inventa
/// un valor).
int? computeRotationDegrees({
  required int sensorOrientation,
  required int? deviceOrientationDegrees,
  required bool isAndroid,
  required bool isFrontCamera,
}) {
  if (deviceOrientationDegrees == null) return null;

  final normalizedSensor = sensorOrientation % 360;
  final normalizedDevice = deviceOrientationDegrees % 360;

  if (isAndroid) {
    if (isFrontCamera) {
      // Fórmula verificada para ML Kit en Android, cámara frontal.
      return (normalizedSensor + normalizedDevice + 270) % 360;
    }
    // Fórmula verificada para ML Kit en Android, cámara trasera.
    return (normalizedSensor - normalizedDevice + 360) % 360;
  }

  // iOS y otras plataformas: usar deviceOrientationDegrees como rotación
  // directa, ya que AVFoundation entrega frames orientados según el dispositivo.
  return normalizedDevice;
}
