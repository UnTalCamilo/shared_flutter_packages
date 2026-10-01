import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../contracts/camera_service.dart';
import '../infrastructure/camera_controller_wrapper.dart';
import '../infrastructure/camera_logger.dart';
import '../infrastructure/camera_permission_handler.dart';
import '../models/camera_capabilities.dart';
import '../models/camera_config.dart';
import '../models/camera_error.dart';
import '../models/camera_frame.dart';
import '../models/camera_info.dart';
import '../models/camera_init_result.dart';
import '../models/camera_state.dart';
import '../models/capture_result.dart';
import '../models/frame_stream_config.dart';

/// Implementación principal del módulo de cámara.
///
/// Orquesta: permisos -> descubrimiento -> inicialización -> control -> captura.
/// Mantiene el único [CameraControllerWrapper] activo y expone el estado de
/// forma reactiva. Traduce los errores del wrapper a tipos de resultado del
/// dominio; nunca deja escapar tipos ni excepciones del paquete `camera`.
///
/// No depende de ningún framework de inyección de dependencias: la aplicación
/// construye y cablea esta clase en su propio DI, pasando sus colaboradores y
/// un [CameraLogger] opcional.
class CameraServiceImpl implements ICameraService {
  final CameraPermissionHandler _permissionHandler;
  final CameraControllerWrapper _controllerWrapper;
  final CameraLogger _logger;

  CameraServiceImpl(
    this._permissionHandler,
    this._controllerWrapper, {
    CameraLogger logger = const DebugPrintCameraLogger(),
  }) : _logger = logger;

  final StreamController<CameraState> _stateController =
      StreamController<CameraState>.broadcast();
  final StreamController<CameraFrame> _frameController =
      StreamController<CameraFrame>.broadcast();
  StreamSubscription<CameraFrame>? _wrapperFrameSubscription;

  CameraState _state = CameraState.uninitialized;
  CameraConfig _config = const CameraConfig();
  bool _disposed = false;
  FrameStreamConfig? _frameStreamConfig;

  @override
  CameraState get state => _state;

  @override
  Stream<CameraState> get stateStream => _stateController.stream;

  @override
  CameraCapabilities? get capabilities => _controllerWrapper.capabilities;

  @override
  CameraInfo? get currentCameraInfo => _controllerWrapper.currentInfo;

  @override
  Stream<CameraFrame> get frameStream => _frameController.stream;

  @override
  FrameStreamConfig? get frameStreamConfig => _frameStreamConfig;

  void _emit(CameraState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  // ========== INICIALIZACIÓN ==========

  @override
  Future<CameraInitResult> initialize({
    CameraLensDirection preferredDirection = CameraLensDirection.back,
    ResolutionPreset preset = ResolutionPreset.high,
  }) async {
    _emit(CameraState.initializing);

    // 1. Permisos
    final permissionResult = await _ensurePermission();
    switch (permissionResult) {
      case CameraPermissionResult.granted:
        break;
      case CameraPermissionResult.denied:
        _emit(CameraState.permissionDenied);
        return CameraInitResult.permissionDenied();
      case CameraPermissionResult.deniedForever:
        _emit(CameraState.permissionDenied);
        return CameraInitResult.permissionDeniedForever();
      case CameraPermissionResult.restricted:
        _emit(CameraState.permissionDenied);
        return CameraInitResult.permissionDeniedForever();
    }

    _config = _config.copyWith(
      lensDirection: preferredDirection,
      resolutionPreset: preset,
    );

    try {
      // 2. Descubrimiento + selección
      final selected =
          await _controllerWrapper.selectCamera(preferredDirection);
      if (selected == null) {
        _emit(CameraState.unavailable);
        return CameraInitResult.noCameraAvailable();
      }

      // 3. Inicialización del controlador
      await _controllerWrapper.initialize(_config);
      _emit(CameraState.ready);
      return CameraInitResult.success(
        _controllerWrapper.currentInfo ?? selected,
      );
    } on CameraException catch (e) {
      _logger.e('CameraServiceImpl.initialize falló: ${e.message}',
          e.originalError, e.stackTrace);
      if (e.type == CameraErrorType.permissionDeniedForever) {
        _emit(CameraState.permissionDenied);
        return CameraInitResult.permissionDeniedForever();
      }
      if (e.type == CameraErrorType.permissionDenied) {
        _emit(CameraState.permissionDenied);
        return CameraInitResult.permissionDenied();
      }
      if (e.type == CameraErrorType.noCameraAvailable) {
        _emit(CameraState.unavailable);
        return CameraInitResult.noCameraAvailable();
      }
      _emit(CameraState.error);
      return CameraInitResult.initializationFailed(e.message);
    }
  }

  @override
  Future<CameraInitResult> switchCamera(CameraLensDirection direction) async {
    if (_state != CameraState.ready && _state != CameraState.error) {
      return CameraInitResult.initializationFailed(
        'La cámara no está lista para cambiarse.',
      );
    }
    // Si hay un frame stream activo, detenerlo y limpiar su estado antes de
    // recrear el controller. Tras el switch el consumidor debe reiniciarlo.
    if (_frameStreamConfig != null) {
      await stopFrameStream();
    }
    _emit(CameraState.initializing);
    final targetConfig = _config.copyWith(lensDirection: direction);
    try {
      await _controllerWrapper.switchCamera(direction, targetConfig);
      _config = targetConfig;
      _emit(CameraState.ready);
      return CameraInitResult.success(
        _controllerWrapper.currentInfo!,
      );
    } on CameraException catch (e) {
      _logger.w(
          'switchCamera falló, se mantiene cámara actual: ${e.message}');
      // Intento restaurar la cámara previa; si falla, quedamos en error.
      try {
        await _controllerWrapper.initialize(_config);
        _emit(CameraState.ready);
      } on CameraException {
        _emit(CameraState.error);
      }
      if (e.type == CameraErrorType.noCameraAvailable) {
        return CameraInitResult.noCameraAvailable();
      }
      return CameraInitResult.initializationFailed(e.message);
    }
  }

  // ========== PERMISOS ==========

  @override
  Future<CameraPermissionResult> checkPermission() =>
      _permissionHandler.check();

  @override
  Future<CameraPermissionResult> requestPermission() =>
      _permissionHandler.request();

  @override
  Future<void> openAppSettings() => _permissionHandler.openSettings();

  Future<CameraPermissionResult> _ensurePermission() async {
    final current = await _permissionHandler.check();
    if (current == CameraPermissionResult.denied) {
      return _permissionHandler.request();
    }
    return current;
  }

  // ========== CONTROLES ==========

  @override
  Future<void> setZoomLevel(double zoom) =>
      _guardControl(() => _controllerWrapper.setZoomLevel(zoom));

  @override
  Future<void> setFlashMode(FlashMode mode) => _guardControl(() async {
        await _controllerWrapper.setFlashMode(mode);
        _config = _config.copyWith(flashMode: mode);
      });

  @override
  Future<void> setExposureOffset(double offset) => _guardControl(() async {
        await _controllerWrapper.setExposureOffset(offset);
        _config = _config.copyWith(exposureOffset: offset);
      });

  @override
  Future<void> setFocusMode(FocusMode mode) => _guardControl(() async {
        await _controllerWrapper.setFocusMode(mode);
        _config = _config.copyWith(focusMode: mode);
      });

  @override
  Future<void> setFocusPoint(Offset? point) =>
      _guardControl(() => _controllerWrapper.setFocusPoint(point));

  @override
  Future<void> setResolution(ResolutionPreset preset) =>
      _guardControl(() async {
        // El paquete `camera` no permite cambiar la resolución en caliente:
        // se recrea el controlador con la nueva configuración.
        _emit(CameraState.initializing);
        _config = _config.copyWith(resolutionPreset: preset);
        await _controllerWrapper.initialize(_config);
        _emit(CameraState.ready);
      });

  @override
  Future<void> lockExposure() =>
      _guardControl(() => _controllerWrapper.lockExposure());

  @override
  Future<void> unlockExposure() =>
      _guardControl(() => _controllerWrapper.unlockExposure());

  @override
  Future<void> setPreviewOrientationLock(bool locked) =>
      _guardControl(() async {
        await _controllerWrapper.setPreviewOrientationLock(locked);
        _config = _config.copyWith(lockPreviewOrientation: locked);
      });

  // ========== FRAME STREAM (REALTIME) ==========

  @override
  Future<void> startFrameStream(FrameStreamConfig config) async {
    if (_state != CameraState.ready) {
      throw const CameraException(
        type: CameraErrorType.controllerDisposed,
        message: 'La cámara no está lista para iniciar frame stream.',
      );
    }
    if (_frameStreamConfig != null) {
      throw const CameraException(
        type: CameraErrorType.deviceError,
        message: 'Frame stream ya activo. Llamar stopFrameStream() primero.',
      );
    }

    _frameStreamConfig = config;
    _wrapperFrameSubscription = _controllerWrapper.frameStream
        .listen(_onWrapperFrame, onError: _onWrapperFrameError);
    await _controllerWrapper.startFrameStream(config);
  }

  @override
  Future<void> stopFrameStream() async {
    await _wrapperFrameSubscription?.cancel();
    _wrapperFrameSubscription = null;
    await _controllerWrapper.stopFrameStream();
    _frameStreamConfig = null;
  }

  void _onWrapperFrame(CameraFrame frame) {
    if (!_frameController.isClosed) {
      _frameController.add(frame);
    }
  }

  void _onWrapperFrameError(Object error, StackTrace stackTrace) {
    if (!_frameController.isClosed) {
      _frameController.addError(error, stackTrace);
    }
  }

  Future<void> _guardControl(Future<void> Function() action) async {
    if (_state != CameraState.ready) {
      throw const CameraException(
        type: CameraErrorType.controllerDisposed,
        message: 'La cámara no está lista para recibir controles.',
      );
    }
    try {
      await action();
    } on CameraException catch (e) {
      _logger.w('Control de cámara falló: ${e.message}');
      if (e.type == CameraErrorType.deviceError) {
        _emit(CameraState.error);
      }
      rethrow;
    }
  }

  // ========== CAPTURA ==========

  @override
  Future<CaptureResult> takePicture() async {
    if (_state != CameraState.ready) {
      throw const CameraException(
        type: CameraErrorType.controllerDisposed,
        message: 'La cámara no está lista para capturar.',
      );
    }
    try {
      final output = await _controllerWrapper.takePicture();

      Uint8List? bytes;
      try {
        bytes = await File(output.path).readAsBytes();
      } catch (e) {
        _logger.w('No se pudieron leer bytes de la captura: $e');
      }

      return CaptureResult(
        path: output.path,
        bytes: bytes,
        metadata: CaptureMetadata(
          timestamp: DateTime.now(),
          lensDirection: _config.lensDirection,
          zoomLevel: _config.zoomLevel,
          flashMode: _config.flashMode,
          exposureOffset: _config.exposureOffset,
          resolution: output.resolution,
          sensorOrientation:
              _controllerWrapper.currentInfo?.sensorOrientation ?? 0,
        ),
      );
    } on CameraException catch (e) {
      _logger.e(
          'takePicture falló: ${e.message}', e.originalError, e.stackTrace);
      if (e.type == CameraErrorType.deviceError) {
        _emit(CameraState.error);
      }
      rethrow;
    }
  }

  // ========== PREVIEW ==========

  @override
  Widget buildPreview({BoxFit fit = BoxFit.cover}) =>
      _controllerWrapper.buildPreview(fit);

  // ========== CICLO DE VIDA ==========

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopFrameStream();
    await _frameController.close();
    await _controllerWrapper.dispose();
    _emit(CameraState.disposed);
    await _stateController.close();
  }

  @override
  Future<void> pause() async {
    if (_state != CameraState.ready) return;
    await stopFrameStream();
    await _controllerWrapper.dispose();
    _emit(CameraState.uninitialized);
  }

  @override
  Future<void> resume() async {
    if (_state == CameraState.ready || _disposed) return;
    _emit(CameraState.initializing);
    try {
      final selected =
          await _controllerWrapper.selectCamera(_config.lensDirection);
      if (selected == null) {
        _emit(CameraState.unavailable);
        return;
      }
      await _controllerWrapper.initialize(_config);
      _emit(CameraState.ready);
      // Nota: El frame stream NO se reanuda automáticamente.
      // El consumidor debe llamar startFrameStream() de nuevo si lo desea.
    } on CameraException catch (e) {
      _logger.e('resume falló: ${e.message}', e.originalError, e.stackTrace);
      _emit(CameraState.error);
    }
  }
}
