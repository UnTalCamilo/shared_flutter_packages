import 'package:flutter/material.dart';

import '../contracts/camera_service.dart';
import '../models/camera_error.dart';
import 'camera_preview.dart';
import 'camera_state_builder.dart';

/// Experiencia de cámara CONVENIENTE y componible (nivel 3).
///
/// Compone, por defecto, un preview a pantalla completa ([CameraPreview])
/// envuelto en la máquina de estados ([CameraStateBuilder]), con slots
/// opcionales para overlay y controles. **No impone diseño ni usa flags de
/// visibilidad** del tipo `showFlashButton: true`: los controles se inyectan
/// como un widget vía [controlsBuilder], que la app compone con los primitivos
/// (`CameraCaptureButton`, `CameraFlashButton`, `CameraZoomControl`, ...).
///
/// Es solo una comodidad: quien necesite composición libre puede ignorar este
/// widget y usar directamente [CameraPreview] + [CameraStateBuilder] + los
/// controles sueltos.
///
/// ```dart
/// CameraView(
///   controller: service,
///   controlsBuilder: (ctx) => Row(children: [
///     CameraFlashButton(controller: service),
///     CameraCaptureButton(controller: service, onCaptured: _save),
///     CameraSwitchButton(controller: service),
///   ]),
/// )
/// ```
class CameraView extends StatelessWidget {
  /// Servicio de cámara. Única dependencia; el widget no toca el plugin.
  final ICameraService controller;

  /// Cómo encajar el preview. Por defecto `cover`.
  final BoxFit fit;

  /// Overlay opcional dibujado encima del preview en estado `ready`
  /// (guías, marcos, indicador de enfoque de la app...).
  final Widget? overlay;

  /// Controles opcionales, posicionados por [controlsAlignment] sobre el
  /// preview. La app los compone con los primitivos de control del paquete.
  final WidgetBuilder? controlsBuilder;

  /// Alineación del bloque de controles dentro del preview.
  final AlignmentGeometry controlsAlignment;

  /// Builders por estado (delegados a [CameraStateBuilder]).
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? permissionDeniedBuilder;
  final WidgetBuilder? unavailableBuilder;
  final Widget Function(BuildContext, CameraException?)? errorBuilder;

  const CameraView({
    super.key,
    required this.controller,
    this.fit = BoxFit.cover,
    this.overlay,
    this.controlsBuilder,
    this.controlsAlignment = Alignment.bottomCenter,
    this.loadingBuilder,
    this.permissionDeniedBuilder,
    this.unavailableBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return CameraStateBuilder(
      controller: controller,
      loadingBuilder: loadingBuilder,
      permissionDeniedBuilder: permissionDeniedBuilder,
      unavailableBuilder: unavailableBuilder,
      errorBuilder: errorBuilder,
      ready: (context) {
        final children = <Widget>[
          CameraPreview(controller: controller, fit: fit),
          if (overlay != null) overlay!,
          if (controlsBuilder != null)
            Align(
              alignment: controlsAlignment,
              child: controlsBuilder!(context),
            ),
        ];
        if (children.length == 1) return children.first;
        return Stack(fit: StackFit.expand, children: children);
      },
    );
  }
}
