import 'dart:async';

import 'package:camera_core/camera_core.dart';
import 'package:flutter/widgets.dart';

/// Fake de [ICameraService] para tests de widgets de UI.
///
/// No toca hardware ni `package:camera`. Permite empujar estados por
/// [emit], expone capacidades configurables y registra las llamadas de control
/// recibidas para verificarlas en los tests.
class FakeCameraService implements ICameraService {
  FakeCameraService({
    CameraState initialState = CameraState.ready,
    CameraCapabilities? capabilities,
  })  : _state = initialState,
        _capabilities = capabilities ?? _defaultCaps {
    _stateController.add(_state);
  }

  static const _defaultCaps = CameraCapabilities(
    minZoom: 1.0,
    maxZoom: 5.0,
    minExposureOffset: -2.0,
    maxExposureOffset: 2.0,
    exposureStepSize: 0.1,
    supportedResolutions: [ResolutionPreset.high],
    supportedFlashModes: [FlashMode.off, FlashMode.auto, FlashMode.on],
    supportedFocusModes: [FocusMode.auto],
    supportsExposureControl: true,
    supportsFocusControl: true,
    supportsZoom: true,
  );

  final StreamController<CameraState> _stateController =
      StreamController<CameraState>.broadcast();
  final StreamController<CameraFrame> _frameController =
      StreamController<CameraFrame>.broadcast();

  CameraState _state;
  final CameraCapabilities _capabilities;

  // --- Registro de llamadas para aserciones ---
  final List<double> zoomCalls = [];
  final List<FlashMode> flashCalls = [];
  final List<Offset?> focusPointCalls = [];
  int takePictureCalls = 0;
  int switchCalls = 0;
  bool throwOnTakePicture = false;

  void emit(CameraState state) {
    _state = state;
    _stateController.add(state);
  }

  @override
  CameraState get state => _state;

  @override
  Stream<CameraState> get stateStream => _stateController.stream;

  @override
  CameraCapabilities? get capabilities => _capabilities;

  @override
  CameraInfo? get currentCameraInfo => const CameraInfo(
        name: 'fake',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
        capabilities: _defaultCaps,
      );

  @override
  Stream<CameraFrame> get frameStream => _frameController.stream;

  @override
  FrameStreamConfig? get frameStreamConfig => null;

  @override
  Future<CameraInitResult> initialize({
    CameraLensDirection preferredDirection = CameraLensDirection.back,
    ResolutionPreset preset = ResolutionPreset.high,
  }) async {
    emit(CameraState.ready);
    return CameraInitResult.success(currentCameraInfo!);
  }

  @override
  Future<CameraInitResult> switchCamera(CameraLensDirection direction) async {
    switchCalls++;
    return CameraInitResult.success(currentCameraInfo!);
  }

  @override
  Future<CameraPermissionResult> checkPermission() async =>
      CameraPermissionResult.granted;

  @override
  Future<CameraPermissionResult> requestPermission() async =>
      CameraPermissionResult.granted;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> setZoomLevel(double zoom) async => zoomCalls.add(zoom);

  @override
  Future<void> setFlashMode(FlashMode mode) async => flashCalls.add(mode);

  @override
  Future<void> setExposureOffset(double offset) async {}

  @override
  Future<void> setFocusMode(FocusMode mode) async {}

  @override
  Future<void> setFocusPoint(Offset? point) async =>
      focusPointCalls.add(point);

  @override
  Future<void> setResolution(ResolutionPreset preset) async {}

  @override
  Future<void> lockExposure() async {}

  @override
  Future<void> unlockExposure() async {}

  @override
  Future<void> setPreviewOrientationLock(bool locked) async {}

  @override
  Future<CaptureResult> takePicture() async {
    takePictureCalls++;
    if (throwOnTakePicture) {
      throw const CameraException(
        type: CameraErrorType.captureFailed,
        message: 'fake capture failure',
      );
    }
    return CaptureResult(
      path: '/tmp/fake.jpg',
      metadata: CaptureMetadata(
        timestamp: DateTime(2024, 1, 1),
        lensDirection: CameraLensDirection.back,
        zoomLevel: 1.0,
        flashMode: FlashMode.off,
        exposureOffset: 0.0,
        resolution: const Size(1920, 1080),
        sensorOrientation: 90,
      ),
    );
  }

  /// Preview falso: un marcador identificable en los tests de widgets.
  @override
  Widget buildPreview({BoxFit fit = BoxFit.cover}) =>
      const _FakePreview();

  @override
  Future<void> startFrameStream(FrameStreamConfig config) async {}

  @override
  Future<void> stopFrameStream() async {}

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _frameController.close();
  }

  @override
  Future<void> pause() async => emit(CameraState.uninitialized);

  @override
  Future<void> resume() async => emit(CameraState.ready);
}

/// Marcador de preview para localizarlo con `find.byType` en los tests.
class _FakePreview extends StatelessWidget {
  const _FakePreview();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: Key('fake-preview'));
}
