import 'package:flutter/material.dart';

import '../../contracts/camera_service.dart';
import '../../models/camera_state.dart';
import 'latest_wins_runner.dart';

/// Control de zoom reutilizable y autónomo (slider).
///
/// Lee el rango soportado de [ICameraService.capabilities] y aplica el zoom con
/// serialización "latest-wins" interna, de modo que arrastrar el slider no
/// sature el controlador con llamadas concurrentes. El valor visual se
/// actualiza de inmediato; la llamada al servicio se serializa.
///
/// Se oculta si la cámara no soporta zoom o no está `ready`. Para una
/// apariencia distinta a un [Slider], usa [builder].
class CameraZoomControl extends StatefulWidget {
  final ICameraService controller;
  final ValueChanged<double>? onChanged;

  /// Builder opcional: recibe el rango y el valor actual, y debe invocar
  /// `onChanged` del propio builder. Si es `null`, usa un [Slider].
  final Widget Function(
    BuildContext context,
    double min,
    double max,
    double value,
    ValueChanged<double> onChanged,
  )? builder;

  const CameraZoomControl({
    super.key,
    required this.controller,
    this.onChanged,
    this.builder,
  });

  @override
  State<CameraZoomControl> createState() => _CameraZoomControlState();
}

class _CameraZoomControlState extends State<CameraZoomControl> {
  late final LatestWinsRunner _runner =
      LatestWinsRunner(widget.controller.setZoomLevel);
  double? _value;

  @override
  void dispose() {
    _runner.dispose();
    super.dispose();
  }

  void _onChanged(double v) {
    setState(() => _value = v);
    _runner.request(v);
    widget.onChanged?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CameraState>(
      stream: widget.controller.stateStream,
      initialData: widget.controller.state,
      builder: (context, snapshot) {
        final caps = widget.controller.capabilities;
        final ready = snapshot.data == CameraState.ready;
        if (!ready || caps == null || !caps.supportsZoom) {
          return const SizedBox.shrink();
        }
        final value = (_value ?? caps.minZoom).clamp(caps.minZoom, caps.maxZoom);
        if (widget.builder != null) {
          return widget.builder!(
              context, caps.minZoom, caps.maxZoom, value, _onChanged);
        }
        return Slider(
          min: caps.minZoom,
          max: caps.maxZoom,
          value: value,
          onChanged: _onChanged,
        );
      },
    );
  }
}
