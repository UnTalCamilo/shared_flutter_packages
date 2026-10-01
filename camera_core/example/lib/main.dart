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

  @override
  Widget build(BuildContext context) {
    // Experiencia conveniente (nivel 3) componiendo los primitivos de control
    // (nivel 2) en el slot controlsBuilder. Sin flags de visibilidad.
    return Scaffold(
      appBar: AppBar(title: const Text('camera_core example')),
      body: CameraView(
        controller: _camera,
        controlsBuilder: (context) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CameraZoomControl(controller: _camera),
              if (_lastCapturePath != null)
                Text('Última captura: $_lastCapturePath',
                    style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CameraFlashButton(controller: _camera),
                  const SizedBox(width: 16),
                  CameraCaptureButton(
                    controller: _camera,
                    onCaptured: (r) {
                      if (mounted) {
                        setState(() => _lastCapturePath = r.path);
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  CameraSwitchButton(controller: _camera),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
