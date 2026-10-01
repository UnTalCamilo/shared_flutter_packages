import 'dart:async';

import 'package:camera_core/camera_core.dart';
import 'package:face_detection/face_detection.dart';
import 'package:flutter/material.dart';

void main() => runApp(const FaceDetectionExampleApp());

class FaceDetectionExampleApp extends StatelessWidget {
  const FaceDetectionExampleApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: FaceDetectionScreen());
}

/// Demuestra la composición: camera_core (preview + frames) + face_detection
/// (detección). La estrategia de frames (maxFps + drop-if-busy) y la UI las
/// decide la app; el detector solo entrega datos geométricos.
class FaceDetectionScreen extends StatefulWidget {
  const FaceDetectionScreen({super.key});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen>
    with WidgetsBindingObserver {
  final ICameraService _camera = CameraCore.createService();
  final IFaceDetector _detector = FaceDetection.create();
  StreamSubscription<CameraFrame>? _sub;
  bool _busy = false; // drop-if-busy, propiedad de la app
  int _faceCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera.stateStream.listen((s) {
      if (s == CameraState.ready) _startDetection();
    });
    _camera.initialize();
  }

  Future<void> _startDetection() async {
    if (_sub != null) return;
    await _camera.startFrameStream(const FrameStreamConfig(maxFps: 10));
    _sub = _camera.frameStream.listen(_onFrame);
  }

  Future<void> _onFrame(CameraFrame frame) async {
    if (_busy) return;
    _busy = true;
    try {
      final result = await _detector.detect(frame);
      if (result != null && mounted) {
        setState(() => _faceCount = result.faces.length);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _detector.dispose();
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
    return Scaffold(
      appBar: AppBar(title: const Text('face_detection example')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller: _camera),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(12),
              color: Colors.black54,
              child: Text('Rostros: $_faceCount',
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
