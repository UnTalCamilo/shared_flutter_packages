import 'package:flutter/material.dart';

import '../../contracts/camera_service.dart';
import '../../models/camera_config.dart';
import '../../models/camera_error.dart';
import '../../models/camera_state.dart';

/// Botón de flash reutilizable y autónomo.
///
/// Mantiene el modo de flash actual como estado local y lo cicla entre los
/// modos indicados en [modes] (por defecto off → auto → on → torch). Aplica el
/// cambio vía [ICameraService.setFlashMode] y notifica por [onChanged]. Se
/// deshabilita si la cámara no está `ready`.
///
/// Pieza suelta: la app la coloca donde quiera. El [iconFor] permite mapear
/// cada modo a un icono propio; por defecto usa iconos de Material.
class CameraFlashButton extends StatefulWidget {
  final ICameraService controller;
  final List<FlashMode> modes;
  final ValueChanged<FlashMode>? onChanged;
  final IconData Function(FlashMode mode)? iconFor;

  const CameraFlashButton({
    super.key,
    required this.controller,
    this.modes = const [
      FlashMode.off,
      FlashMode.auto,
      FlashMode.on,
      FlashMode.torch,
    ],
    this.onChanged,
    this.iconFor,
  });

  @override
  State<CameraFlashButton> createState() => _CameraFlashButtonState();
}

class _CameraFlashButtonState extends State<CameraFlashButton> {
  late FlashMode _mode = widget.modes.first;

  IconData _defaultIcon(FlashMode mode) => switch (mode) {
        FlashMode.off => Icons.flash_off,
        FlashMode.auto => Icons.flash_auto,
        FlashMode.on => Icons.flash_on,
        FlashMode.torch => Icons.highlight,
      };

  Future<void> _cycle() async {
    final modes = widget.modes;
    if (modes.isEmpty) return;
    final next = modes[(modes.indexOf(_mode) + 1) % modes.length];
    try {
      await widget.controller.setFlashMode(next);
      if (!mounted) return;
      setState(() => _mode = next);
      widget.onChanged?.call(next);
    } on CameraException {
      // Degradación silenciosa.
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CameraState>(
      stream: widget.controller.stateStream,
      initialData: widget.controller.state,
      builder: (context, snapshot) {
        final enabled = snapshot.data == CameraState.ready;
        final iconFor = widget.iconFor ?? _defaultIcon;
        return IconButton(
          onPressed: enabled ? _cycle : null,
          icon: Icon(iconFor(_mode)),
          tooltip: 'Flash',
        );
      },
    );
  }
}
