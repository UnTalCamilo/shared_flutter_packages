import 'camera_capabilities.dart';
import 'camera_config.dart';

/// Descripción de dominio de una cámara física disponible en el dispositivo.
///
/// Es el equivalente propio de `CameraDescription` del paquete `camera`,
/// evitando que ese tipo externo atraviese la API pública del módulo.
class CameraInfo {
  final String name;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;
  final CameraCapabilities capabilities;

  const CameraInfo({
    required this.name,
    required this.lensDirection,
    required this.sensorOrientation,
    required this.capabilities,
  });
}
