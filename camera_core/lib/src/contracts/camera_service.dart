import 'package:flutter/widgets.dart';

import '../models/camera_config.dart';
import '../models/camera_capabilities.dart';
import '../models/camera_error.dart';
import '../models/camera_frame.dart';
import '../models/camera_info.dart';
import '../models/camera_init_result.dart';
import '../models/camera_state.dart';
import '../models/capture_result.dart';
import '../models/frame_stream_config.dart';

/// Contrato público del módulo de cámara.
///
/// Los consumidores dependen de esta abstracción, nunca de la implementación
/// concreta ni del paquete `camera`. Ningún tipo del paquete `camera` aparece
/// en esta firma; solo modelos propios y tipos de Flutter (`Widget`, `BoxFit`).
abstract class ICameraService {
  // ========== ESTADO ==========
  CameraState get state;
  Stream<CameraState> get stateStream;

  CameraCapabilities? get capabilities;
  CameraInfo? get currentCameraInfo;

  // ========== INICIALIZACIÓN ==========
  Future<CameraInitResult> initialize({
    CameraLensDirection preferredDirection = CameraLensDirection.back,
    ResolutionPreset preset = ResolutionPreset.high,
  });

  Future<CameraInitResult> switchCamera(CameraLensDirection direction);

  // ========== PERMISOS ==========
  Future<CameraPermissionResult> checkPermission();
  Future<CameraPermissionResult> requestPermission();
  Future<void> openAppSettings();

  // ========== CONTROLES ==========
  Future<void> setZoomLevel(double zoom);
  Future<void> setFlashMode(FlashMode mode);
  Future<void> setExposureOffset(double offset);
  Future<void> setFocusMode(FocusMode mode);

  /// Enfoque por punto (tap-to-focus). [point] usa coordenadas normalizadas en
  /// el rango (0,0)–(1,1) relativas al área de preview. Pasar `null` restablece
  /// el punto de enfoque al valor por defecto del dispositivo.
  Future<void> setFocusPoint(Offset? point);
  Future<void> setResolution(ResolutionPreset preset);
  Future<void> lockExposure();
  Future<void> unlockExposure();
  Future<void> setPreviewOrientationLock(bool locked);

  // ========== CAPTURA ==========
  Future<CaptureResult> takePicture();

  // ========== PREVIEW ==========
  Widget buildPreview({BoxFit fit = BoxFit.cover});

  // ========== FRAME STREAM (REALTIME) ==========
  /// Inicia el stream de frames para procesamiento en tiempo real.
  /// Debe llamarse tras `initialize()` exitoso y estado `ready`.
  /// Requiere `stopFrameStream()` para liberar recursos.
  Future<void> startFrameStream(FrameStreamConfig config);

  /// Detiene el stream de frames.
  Future<void> stopFrameStream();

  /// Stream de frames. Solo emite tras `startFrameStream()` exitoso.
  /// Broadcast: múltiples consumidores pueden escuchar simultáneamente.
  Stream<CameraFrame> get frameStream;

  /// Configuración actual del stream (null si no iniciado).
  FrameStreamConfig? get frameStreamConfig;

  // ========== CICLO DE VIDA ==========
  Future<void> dispose();
  Future<void> pause();
  Future<void> resume();
}
