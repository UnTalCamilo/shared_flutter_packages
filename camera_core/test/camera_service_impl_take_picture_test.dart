import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:camera_core/camera_core.dart';
import 'package:camera_core/src/infrastructure/camera_controller_wrapper.dart';
import 'package:camera_core/src/infrastructure/camera_permission_handler.dart';
import 'package:camera_core/src/services/camera_service_impl.dart';

/// Permiso siempre concedido, para llevar el servicio a estado `ready`.
class _GrantedPermissionHandler extends CameraPermissionHandler {
  @override
  Future<CameraPermissionResult> check() async =>
      CameraPermissionResult.granted;

  @override
  Future<CameraPermissionResult> request() async =>
      CameraPermissionResult.granted;
}

/// Wrapper falso que no toca hardware: devuelve una cámara conocida y una
/// captura con resolución real controlada.
class _FakeControllerWrapper extends CameraControllerWrapper {
  _FakeControllerWrapper({
    required this.captureResolution,
    required this.sensorOrientation,
  }) : super(logger: const SilentCameraLogger());

  final Size captureResolution;
  final int sensorOrientation;

  static const _caps = CameraCapabilities(
    minZoom: 1.0,
    maxZoom: 4.0,
    minExposureOffset: -2.0,
    maxExposureOffset: 2.0,
    exposureStepSize: 0.1,
    supportedResolutions: [ResolutionPreset.high],
    supportedFlashModes: [FlashMode.off, FlashMode.auto],
    supportedFocusModes: [FocusMode.auto],
    supportsExposureControl: true,
    supportsFocusControl: true,
    supportsZoom: true,
  );

  late final CameraInfo _info = CameraInfo(
    name: 'fake-back',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: sensorOrientation,
    capabilities: _caps,
  );

  @override
  CameraInfo? get currentInfo => _info;

  @override
  CameraCapabilities? get capabilities => _caps;

  @override
  Future<CameraInfo?> selectCamera(CameraLensDirection direction) async =>
      _info;

  @override
  Future<void> initialize(CameraConfig config) async {}

  @override
  Future<CaptureOutput> takePicture() async => CaptureOutput(
      path: '/tmp/fake_capture.jpg', resolution: captureResolution);

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraServiceImpl.takePicture metadata', () {
    test('usa la resolución real de la captura y el sensorOrientation activo',
        () async {
      final wrapper = _FakeControllerWrapper(
        captureResolution: const Size(4000, 3000),
        sensorOrientation: 90,
      );
      final service = CameraServiceImpl(
        _GrantedPermissionHandler(),
        wrapper,
        logger: const SilentCameraLogger(),
      );

      final init = await service.initialize();
      expect(init.isSuccess, isTrue);

      final result = await service.takePicture();

      expect(result.metadata.resolution, const Size(4000, 3000));
      expect(result.metadata.sensorOrientation, 90);
      expect(result.path, '/tmp/fake_capture.jpg');

      await service.dispose();
    });

    test('propaga metadata de configuración vigente (lente, flash)', () async {
      final wrapper = _FakeControllerWrapper(
        captureResolution: const Size(1920, 1080),
        sensorOrientation: 270,
      );
      final service = CameraServiceImpl(
        _GrantedPermissionHandler(),
        wrapper,
        logger: const SilentCameraLogger(),
      );

      await service.initialize();
      final result = await service.takePicture();

      expect(result.metadata.lensDirection, CameraLensDirection.back);
      expect(result.metadata.flashMode, FlashMode.off);
      expect(result.metadata.resolution, const Size(1920, 1080));
      expect(result.metadata.sensorOrientation, 270);

      await service.dispose();
    });
  });
}
