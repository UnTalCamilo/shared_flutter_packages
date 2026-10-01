import 'package:flutter/widgets.dart';

import '../contracts/camera_service.dart';

/// Primitivo de preview: SOLO el render del preview de la cámara.
///
/// A diferencia de [CameraView], no observa el ciclo de vida ni decide qué
/// pintar en cada estado: asume que la cámara está lista y delega en
/// [ICameraService.buildPreview]. Si la cámara no está inicializada, el servicio
/// devuelve un placeholder vacío.
///
/// Es la pieza de composición libre: colócalo dentro de un `Stack`, un
/// `SizedBox` pequeño, junto a un overlay de QR, etc. No impone tamaño ni
/// posición.
///
/// Para reaccionar a los estados (loading/permiso/error), compón este widget
/// dentro de un [CameraStateBuilder].
class CameraPreview extends StatelessWidget {
  /// Servicio de cámara. Única dependencia; el widget no toca el plugin.
  final ICameraService controller;

  /// Cómo encajar el preview dentro del espacio disponible. Por defecto `cover`.
  final BoxFit fit;

  const CameraPreview({
    super.key,
    required this.controller,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) => controller.buildPreview(fit: fit);
}
