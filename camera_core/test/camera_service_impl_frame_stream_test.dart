import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:camera_core/camera_core.dart';
// Import directo del wrapper interno: los tests del paquete pueden tocar
// `src/` para construir fakes. No forma parte de la API pública.
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

/// Wrapper falso que no toca hardware.
///
/// Emula el comportamiento observable del wrapper real: emite frames YUV420 a
/// ~30 FPS y aplica el mismo throttling por `maxFps` (descartando frames que
/// llegan antes del intervalo mínimo), para poder verificar el contrato sin
/// depender de `CameraImage`/hardware.
class _FakeControllerWrapper extends CameraControllerWrapper {
  _FakeControllerWrapper() : super(logger: const SilentCameraLogger());

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

  CameraLensDirection _lens = CameraLensDirection.back;

  late CameraInfo _info = _makeInfo(_lens);

  static CameraInfo _makeInfo(CameraLensDirection lens) => CameraInfo(
        name: 'fake-${lens.name}',
        lensDirection: lens,
        sensorOrientation: 90,
        capabilities: _caps,
      );

  bool _frameStreamStarted = false;
  StreamController<CameraFrame>? _frameController;
  int _fakeFrameCounter = 0;
  int _lastDeliveredMicros = 0;
  Timer? _timer;
  int switchCount = 0;

  @override
  CameraInfo? get currentInfo => _info;

  @override
  CameraCapabilities? get capabilities => _caps;

  @override
  Future<CameraInfo?> selectCamera(CameraLensDirection direction) async {
    _lens = direction;
    _info = _makeInfo(direction);
    return _info;
  }

  @override
  Future<void> initialize(CameraConfig config) async {}

  @override
  Future<void> switchCamera(
    CameraLensDirection direction,
    CameraConfig config,
  ) async {
    switchCount++;
    // Igual que el wrapper real: detener el stream antes de recrear.
    await stopFrameStream();
    await selectCamera(direction);
  }

  @override
  Future<CaptureOutput> takePicture() async => const CaptureOutput(
      path: '/tmp/fake_capture.jpg', resolution: ui.Size(1920, 1080));

  @override
  Future<void> dispose() async {
    await stopFrameStream();
  }

  @override
  Stream<CameraFrame> get frameStream {
    _frameController ??= StreamController<CameraFrame>.broadcast();
    return _frameController!.stream;
  }

  @override
  Future<void> startFrameStream(FrameStreamConfig config) async {
    if (_frameStreamStarted) {
      throw const CameraException(
        type: CameraErrorType.deviceError,
        message: 'Frame stream already active. Call stopFrameStream() first.',
      );
    }
    _frameStreamStarted = true;
    _fakeFrameCounter = 0;
    _lastDeliveredMicros = 0;
    _frameController ??= StreamController<CameraFrame>.broadcast();

    // Fuente a ~30 FPS (cada 33ms). Aplica throttling maxFps como el wrapper.
    _timer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!_frameStreamStarted ||
          _frameController == null ||
          _frameController!.isClosed) {
        timer.cancel();
        return;
      }
      if (!_shouldDeliver(config)) return;
      _frameController!.add(_makeFrame(config));
    });
  }

  bool _shouldDeliver(FrameStreamConfig config) {
    final maxFps = config.maxFps;
    if (maxFps == null || maxFps <= 0) return true;
    final now = DateTime.now().microsecondsSinceEpoch;
    final minInterval = 1000000 ~/ maxFps;
    if (_lastDeliveredMicros != 0 &&
        (now - _lastDeliveredMicros) < minInterval) {
      return false;
    }
    _lastDeliveredMicros = now;
    return true;
  }

  CameraFrame _makeFrame(FrameStreamConfig config) {
    // Simula un frame YUV420 triplanar (layout Android), preservando planos.
    // Metadata recortada (A1): sin zoom/exposure/width/height duplicados.
    return CameraFrame(
      planes: [
        PlaneDescriptor(
            bytes: Uint8List(640 * 480), bytesPerRow: 640, bytesPerPixel: 1),
        PlaneDescriptor(
            bytes: Uint8List(320 * 240), bytesPerRow: 320, bytesPerPixel: 2),
        PlaneDescriptor(
            bytes: Uint8List(320 * 240), bytesPerRow: 320, bytesPerPixel: 2),
      ],
      width: 640,
      height: 480,
      format: CameraFrameFormat.yuv420,
      layout: FrameLayout.yuv420Triplanar,
      metadata: CameraFrameMetadata(
        timestamp: DateTime.now(),
        orientation: const FrameOrientation(sensorOrientation: 90),
        lensDirection: _lens,
        isMirroredHeuristic: _lens == CameraLensDirection.front,
      ),
      frameId: _fakeFrameCounter++,
    );
  }

  @override
  Future<void> stopFrameStream() async {
    _frameStreamStarted = false;
    _timer?.cancel();
    _timer = null;
    await _frameController?.close();
    _frameController = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CameraServiceImpl makeService(_FakeControllerWrapper wrapper) =>
      CameraServiceImpl(
        _GrantedPermissionHandler(),
        wrapper,
        logger: const SilentCameraLogger(),
      );

  group('CameraServiceImpl Frame Stream', () {
    test('formato por defecto entregado es YUV420', () async {
      final wrapper = _FakeControllerWrapper();
      final service = makeService(wrapper);

      await service.initialize();
      await service.startFrameStream(const FrameStreamConfig());

      final frames = <CameraFrame>[];
      final sub = service.frameStream.listen(frames.add);
      await Future.delayed(const Duration(milliseconds: 100));
      await sub.cancel();
      await service.dispose();

      expect(frames, isNotEmpty);
      expect(frames.first.format, CameraFrameFormat.yuv420);
      expect(frames.first.layout, FrameLayout.yuv420Triplanar);
      expect(frames.first.planes.length, 3);
      expect(frames.first.width, 640);
      expect(frames.first.height, 480);
      expect(frames.first.metadata.sensorOrientation, 90);
    });

    test('maxFps limita realmente la frecuencia de frames entregados',
        () async {
      final wrapperNoLimit = _FakeControllerWrapper();
      final serviceNoLimit = makeService(wrapperNoLimit);
      await serviceNoLimit.initialize();
      await serviceNoLimit.startFrameStream(const FrameStreamConfig());
      final unlimited = <CameraFrame>[];
      final sub1 = serviceNoLimit.frameStream.listen(unlimited.add);
      await Future.delayed(const Duration(milliseconds: 500));
      await sub1.cancel();
      await serviceNoLimit.dispose();

      final wrapperLimited = _FakeControllerWrapper();
      final serviceLimited = makeService(wrapperLimited);
      await serviceLimited.initialize();
      await serviceLimited.startFrameStream(const FrameStreamConfig(maxFps: 5));
      final limited = <CameraFrame>[];
      final sub2 = serviceLimited.frameStream.listen(limited.add);
      await Future.delayed(const Duration(milliseconds: 500));
      await sub2.cancel();
      await serviceLimited.dispose();

      expect(limited.length, lessThan(unlimited.length));
      expect(limited.length, lessThanOrEqualTo(4));
    });

    test('stopFrameStream detiene el stream y tolera frames tardíos', () async {
      final wrapper = _FakeControllerWrapper();
      final service = makeService(wrapper);

      await service.initialize();
      await service.startFrameStream(const FrameStreamConfig());

      final framesBefore = <CameraFrame>[];
      final sub1 = service.frameStream.listen(framesBefore.add);
      await Future.delayed(const Duration(milliseconds: 50));
      await sub1.cancel();

      await service.stopFrameStream();

      final framesAfter = <CameraFrame>[];
      final sub2 = service.frameStream.listen(framesAfter.add);
      await Future.delayed(const Duration(milliseconds: 100));
      await sub2.cancel();
      await service.dispose();

      expect(framesBefore, isNotEmpty);
      expect(framesAfter, isEmpty);
      expect(service.frameStreamConfig, isNull);
    });

    test('no se puede iniciar dos streams simultáneamente', () async {
      final wrapper = _FakeControllerWrapper();
      final service = makeService(wrapper);

      await service.initialize();
      await service.startFrameStream(const FrameStreamConfig());

      expect(
        () => service.startFrameStream(const FrameStreamConfig()),
        throwsA(isA<CameraException>().having(
          (e) => e.type,
          'type',
          CameraErrorType.deviceError,
        )),
      );

      await service.stopFrameStream();
      await service.dispose();
    });

    test('switchCamera detiene y limpia el frame stream', () async {
      final wrapper = _FakeControllerWrapper();
      final service = makeService(wrapper);

      await service.initialize();
      await service.startFrameStream(const FrameStreamConfig());
      expect(service.frameStreamConfig, isNotNull);

      final result = await service.switchCamera(CameraLensDirection.front);
      expect(result.isSuccess, isTrue);

      expect(service.frameStreamConfig, isNull);
      expect(wrapper.switchCount, 1);

      await service.startFrameStream(const FrameStreamConfig());
      expect(service.frameStreamConfig, isNotNull);

      await service.dispose();
    });

    test('dispose detiene y libera el frame stream', () async {
      final wrapper = _FakeControllerWrapper();
      final service = makeService(wrapper);

      await service.initialize();
      await service.startFrameStream(const FrameStreamConfig());
      await service.dispose();

      expect(service.frameStreamConfig, isNull);
      expect(service.state, CameraState.disposed);
    });

    test('lifecycle completo: init→start→pause→resume→start→stop→dispose',
        () async {
      final wrapper = _FakeControllerWrapper();
      final service = makeService(wrapper);

      await service.initialize();
      expect(service.state, CameraState.ready);

      await service.startFrameStream(const FrameStreamConfig());
      expect(service.frameStreamConfig, isNotNull);

      await service.pause();
      expect(service.state, CameraState.uninitialized);
      expect(service.frameStreamConfig, isNull);

      await service.resume();
      expect(service.state, CameraState.ready);
      expect(service.frameStreamConfig, isNull);

      await service.startFrameStream(const FrameStreamConfig());
      expect(service.frameStreamConfig, isNotNull);

      await service.stopFrameStream();
      expect(service.frameStreamConfig, isNull);

      await service.dispose();
      expect(service.state, CameraState.disposed);
    });

    test('resume no reanuda frame stream automáticamente', () async {
      final wrapper = _FakeControllerWrapper();
      final service = makeService(wrapper);

      await service.initialize();
      await service.startFrameStream(const FrameStreamConfig());
      await service.pause();
      await service.resume();

      expect(service.frameStreamConfig, isNull);
      expect(service.state, CameraState.ready);

      await service.dispose();
    });

    test('startFrameStream falla si cámara no está ready', () async {
      final wrapper = _FakeControllerWrapper();
      final service = makeService(wrapper);

      expect(
        () => service.startFrameStream(const FrameStreamConfig()),
        throwsA(isA<CameraException>().having(
          (e) => e.type,
          'type',
          CameraErrorType.controllerDisposed,
        )),
      );

      await service.dispose();
    });
  });

  group('CameraControllerWrapper frame stream', () {
    test('frameStream es Stream<CameraFrame> (modelo propio)', () {
      final wrapper = _FakeControllerWrapper();
      expect(wrapper.frameStream, isA<Stream<CameraFrame>>());
      expect('$CameraFrame', isNot(contains('CameraImage')));
    });
  });
}
