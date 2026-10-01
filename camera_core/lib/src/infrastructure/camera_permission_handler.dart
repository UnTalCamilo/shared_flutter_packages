import 'package:permission_handler/permission_handler.dart';

import '../models/camera_error.dart';

/// Adaptador de permisos de cámara sobre `permission_handler`.
///
/// Responsabilidad única: consultar/solicitar `Permission.camera` y mapear
/// `PermissionStatus` a [CameraPermissionResult] (modelo propio). No duplica el
/// mecanismo de permisos del proyecto: delega íntegramente en
/// `permission_handler`.
class CameraPermissionHandler {
  Future<CameraPermissionResult> check() async {
    final status = await Permission.camera.status;
    return _map(status);
  }

  Future<CameraPermissionResult> request() async {
    final status = await Permission.camera.request();
    return _map(status);
  }

  /// Abre la configuración del sistema. Útil cuando el permiso quedó como
  /// `deniedForever` y el usuario debe habilitarlo manualmente.
  Future<void> openSettings() async {
    await openAppSettings();
  }

  CameraPermissionResult _map(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return CameraPermissionResult.granted;
      case PermissionStatus.denied:
        return CameraPermissionResult.denied;
      case PermissionStatus.permanentlyDenied:
        return CameraPermissionResult.deniedForever;
      case PermissionStatus.restricted:
        return CameraPermissionResult.restricted;
    }
  }
}
