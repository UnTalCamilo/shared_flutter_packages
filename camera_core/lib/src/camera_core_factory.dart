import 'contracts/camera_service.dart';
import 'infrastructure/camera_controller_wrapper.dart';
import 'infrastructure/camera_logger.dart';
import 'infrastructure/camera_permission_handler.dart';
import 'services/camera_service_impl.dart';

/// Fábrica de conveniencia para construir un [ICameraService] completamente
/// cableado sin exponer las clases internas del paquete.
///
/// El paquete NO depende de ningún framework de DI (A2). Las apps pueden:
/// - usar [CameraCore.createService] para una instancia lista, o
/// - registrar en su propio contenedor pasando sus propios colaboradores.
abstract final class CameraCore {
  const CameraCore._();

  /// Crea un [ICameraService] con los colaboradores por defecto del paquete.
  ///
  /// [logger] permite a la app puentear el logging del paquete a su propio
  /// sistema. Si se omite, se usa [DebugPrintCameraLogger].
  static ICameraService createService({
    CameraLogger logger = const DebugPrintCameraLogger(),
  }) {
    return CameraServiceImpl(
      CameraPermissionHandler(),
      CameraControllerWrapper(logger: logger),
      logger: logger,
    );
  }
}
