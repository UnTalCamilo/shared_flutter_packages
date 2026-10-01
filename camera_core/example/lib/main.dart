import 'package:camera_core/camera_core.dart';
import 'package:flutter/material.dart';

void main() => runApp(const CameraCoreExampleApp());

class CameraCoreExampleApp extends StatelessWidget {
  const CameraCoreExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'camera_core example',
      home: ExampleCameraScreen(),
    );
  }
}

/// Pantalla mínima que demuestra el consumo de `camera_core`:
/// inicializa el servicio, muestra el preview con `CameraView`, aplica zoom y
/// captura una foto. Toda la orquestación (lifecycle) vive en la app, no en el
/// paquete (decisión A6).
class ExampleCameraScreen extends StatefulWidget {
  const ExampleCameraScreen({super.key});

  @override
  State<ExampleCameraScreen> createState() => _ExampleCameraScreenState();
}

class _ExampleCameraScreenState extends State<ExampleCameraScreen>
    with WidgetsBindingObserver {
  late final ICameraService _camera = CameraCore.createService();
  double _zoom = 1.0;
  String? _lastCapturePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _camera.pause();
      case AppLifecycleState.resumed:
        _camera.resume();
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _capture() async {
    try {
      final result = await _camera.takePicture();
      if (mounted) setState(() => _lastCapturePath = result.path);
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    }
  }

  Future<void> _applyZoom(double value) async {
    setState(() => _zoom = value);
    try {
      await _camera.setZoomLevel(value);
    } on CameraException {
      // Ignorar en el ejemplo.
    }
  }

  @override
  Widget build(BuildContext context) {
    final caps = _camera.capabilities;
    return Scaffold(
      appBar: AppBar(title: const Text('camera_core example')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraView(controller: _camera),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (caps != null && caps.supportsZoom)
                  Slider(
                    value: _zoom.clamp(caps.minZoom, caps.maxZoom),
                    min: caps.minZoom,
                    max: caps.maxZoom,
                    onChanged: _applyZoom,
                  ),
                if (_lastCapturePath != null)
                  Text('Última captura: $_lastCapturePath',
                      style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: _capture,
                  child: const Icon(Icons.camera),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
