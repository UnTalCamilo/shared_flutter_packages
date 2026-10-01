import 'dart:async';

import 'package:camera_core/camera_core.dart';
import 'package:flutter/material.dart';
import 'package:qr_scanner/qr_scanner.dart';

void main() => runApp(const QrScannerExampleApp());

class QrScannerExampleApp extends StatelessWidget {
  const QrScannerExampleApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: QrScanScreen());
}

/// Demuestra la composición: camera_core (preview + frames) + qr_scanner
/// (detección) con la UI decidida por la app. El detector no sabe nada de la
/// presentación.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with WidgetsBindingObserver {
  final ICameraService _camera = CameraCore.createService();
  final IQrScanner _scanner = QrScanner.create();
  IQrScanSession? _session;
  StreamSubscription<QrScanResult>? _sub;
  String? _lastValue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera.stateStream.listen((s) {
      if (s == CameraState.ready) _startScanning();
    });
    _camera.initialize();
  }

  Future<void> _startScanning() async {
    if (_session != null) return;
    await _camera.startFrameStream(const FrameStreamConfig(maxFps: 10));
    _session = QrScanner.session(
      scanner: _scanner,
      frames: _camera.frameStream,
      duplicatePolicy: const QrDuplicatePolicy.cooldown(Duration(seconds: 2)),
    );
    _sub = _session!.results.listen((r) {
      if (mounted) setState(() => _lastValue = r.rawValue);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _session?.dispose();
    _scanner.dispose();
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
    // Composición full-screen: preview + overlay de qr_scanner.
    return Scaffold(
      appBar: AppBar(title: const Text('qr_scanner example')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller: _camera),
          const QrScannerOverlay(),
          if (_lastValue != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(12),
                color: Colors.black54,
                child: Text('QR: $_lastValue',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
