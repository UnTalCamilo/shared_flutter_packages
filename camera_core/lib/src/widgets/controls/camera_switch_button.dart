import 'package:flutter/material.dart';

import '../../contracts/camera_service.dart';
import '../../models/camera_config.dart';
import '../../models/camera_error.dart';
import '../../models/camera_init_result.dart';
import '../../models/camera_state.dart';

/// Botón de cambio de cámara (frontal ↔ trasera) reutilizable y autónomo.
///
/// Alterna la dirección del lente llamando a [ICameraService.switchCamera] y
/// notifica la nueva dirección por [onSwitched] cuando el cambio tiene éxito.
/// Se deshabilita si la cámara no está `ready`.
class CameraSwitchButton extends StatefulWidget {
  final ICameraService controller;
  final ValueChanged<CameraLensDirection>? onSwitched;

  const CameraSwitchButton({
    super.key,
    required this.controller,
    this.onSwitched,
  });

  @override
  State<CameraSwitchButton> createState() => _CameraSwitchButtonState();
}

class _CameraSwitchButtonState extends State<CameraSwitchButton> {
  CameraLensDirection _current = CameraLensDirection.back;

  Future<void> _switch() async {
    final next = _current == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    try {
      final result = await widget.controller.switchCamera(next);
      if (!mounted) return;
      if (result.type == CameraInitResultType.success) {
        setState(() => _current = next);
        widget.onSwitched?.call(next);
      }
    } on CameraException {
      // Mantener cámara actual ante fallo.
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CameraState>(
      stream: widget.controller.stateStream,
      initialData: widget.controller.state,
      builder: (context, snapshot) {
        final enabled = snapshot.data == CameraState.ready;
        return IconButton(
          onPressed: enabled ? _switch : null,
          icon: const Icon(Icons.cameraswitch),
          tooltip: 'Cambiar cámara',
        );
      },
    );
  }
}
