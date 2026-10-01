import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart' as cam;
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart';

import '../models/camera_capabilities.dart';
import '../models/camera_config.dart';
import '../models/camera_error.dart';
import '../models/camera_frame.dart';
import '../models/camera_info.dart';
import '../models/frame_stream_config.dart';
import 'camera_logger.dart';

/// Wrapper fino y ÚNICO punto de acoplamiento al paquete `camera`.
///
/// Aquí (y solo aquí) aparecen `CameraController`, `CameraDescription`,
/// `XFile` y las excepciones del paquete. Toda excepción del paquete se traduce
/// a [CameraException] antes de salir de esta clase.
///
/// No expone estado reactivo ni orquesta permisos: esa lógica vive en
/// `CameraServiceImpl`.
class CameraControllerWrapper {
  final CameraLogger _logger;

  CameraControllerWrapper({CameraLogger logger = const DebugPrintCameraLogger()})
      : _logger = logger;

  cam.CameraController? _controller;
  cam.CameraDescription? _description;

  bool get isInitialized =>
      _controller != null && _controller!.value.isInitialized;

  CameraInfo? get currentInfo => _description == null
      ? null
      : _toCameraInfo(
          _description!, _currentCapabilities ?? _defaultCapabilities());

  CameraCapabilities? get capabilities => _currentCapabilities;

  CameraCapabilities? _currentCapabilities;

  /// Descubre las cámaras disponibles como modelos propios.
  Future<List<CameraInfo>> availableCameras() async {
    try {
      final descriptions = await cam.availableCameras();
      // Las capacidades reales requieren un controller inicializado; aquí
      // devolvemos capacidades por defecto hasta que se inicialice.
      return descriptions
          .map((d) => _toCameraInfo(d, _defaultCapabilities()))
          .toList();
    } on cam.CameraException catch (e, s) {
      throw _translate(e, s, CameraErrorType.deviceError);
    } catch (e, s) {
      throw CameraException(
        type: CameraErrorType.unknown,
        message: 'Error descubriendo cámaras: $e',
        originalError: e,
        stackTrace: s,
      );
    }
  }

  /// Selecciona una `CameraDescription` por dirección de lente, con fallback a
  /// la primera disponible.
  Future<CameraInfo?> selectCamera(CameraLensDirection direction) async {
    final descriptions = await _rawAvailableCameras();
    if (descriptions.isEmpty) return null;

    final target = _toPackageLens(direction);
    final match = descriptions.firstWhere(
      (d) => d.lensDirection == target,
      orElse: () => descriptions.first,
    );
    _description = match;
    return _toCameraInfo(match, _currentCapabilities ?? _defaultCapabilities());
  }

  /// Inicializa el `CameraController` con la configuración dada. Debe llamarse
  /// tras [selectCamera] o pasando una descripción vía la última selección.
  Future<void> initialize(CameraConfig config) async {
    if (_description == null) {
      throw const CameraException(
        type: CameraErrorType.initializationFailed,
        message: 'No hay cámara seleccionada antes de initialize().',
      );
    }
    try {
      final controller = cam.CameraController(
        _description!,
        _toPackagePreset(config.resolutionPreset),
        enableAudio: config.enableAudio,
        // Fijar explícitamente el grupo de formato del stream de imágenes en
        // lugar de depender del default de plataforma (Android YUV420 / iOS
        // BGRA). El formato REAL entregado se lee luego de cada CameraImage.
        imageFormatGroup: _requestedImageFormatGroup,
      );
      await controller.initialize();
      _controller = controller;

      await _applyConfig(config);
      _currentCapabilities = await _readCapabilities(controller);
    } on cam.CameraException catch (e, s) {
      await _safeDisposeController();
      throw _translate(e, s, CameraErrorType.initializationFailed);
    } catch (e, s) {
      await _safeDisposeController();
      throw CameraException(
        type: CameraErrorType.initializationFailed,
        message: 'Fallo inicializando la cámara: $e',
        originalError: e,
        stackTrace: s,
      );
    }
  }

  /// Cambia a otra cámara física por dirección de lente.
  ///
  /// Si hay un frame stream activo, lo detiene y limpia antes de destruir el
  /// controller. Tras el cambio el consumidor debe reiniciar el stream.
  Future<void> switchCamera(
    CameraLensDirection direction,
    CameraConfig config,
  ) async {
    final info = await selectCamera(direction);
    if (info == null) {
      throw const CameraException(
        type: CameraErrorType.noCameraAvailable,
        message: 'No hay cámara para la dirección solicitada.',
      );
    }
    // Detener el stream sobre el controller aún vivo antes de recrearlo, para
    // no dejar _frameStreamActive/_frameStreamConfig apuntando a un controller
    // que ya no existe.
    await stopFrameStream();
    await _safeDisposeController();
    await initialize(config);
  }

  /// Captura una fotografía y devuelve su ruta local junto con la resolución
  /// real del archivo generado.
  ///
  /// La resolución se lee decodificando las dimensiones del archivo capturado
  /// (no el `previewSize`, que corresponde al preview y difiere de la foto).
  /// Si la lectura de dimensiones falla, se devuelve [ui.Size.zero] sin abortar
  /// la captura.
  Future<CaptureOutput> takePicture() async {
    final controller = _requireController();
    try {
      final cam.XFile file = await controller.takePicture();
      final resolution = await _readImageResolution(file.path);
      return CaptureOutput(path: file.path, resolution: resolution);
    } on cam.CameraException catch (e, s) {
      throw _translate(e, s, CameraErrorType.captureFailed);
    } catch (e, s) {
      throw CameraException(
        type: CameraErrorType.captureFailed,
        message: 'Fallo al capturar la foto: $e',
        originalError: e,
        stackTrace: s,
      );
    }
  }

  /// Decodifica las dimensiones reales de la imagen capturada usando `dart:ui`.
  /// No lanza: ante cualquier fallo devuelve [ui.Size.zero].
  Future<ui.Size> _readImageResolution(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final descriptor = await ui.ImageDescriptor.encoded(
        await ui.ImmutableBuffer.fromUint8List(bytes),
      );
      final size =
          ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
      descriptor.dispose();
      return size;
    } catch (e) {
      _logger.w('No se pudo leer la resolución de la captura: $e');
      return ui.Size.zero;
    }
  }

  // ========== CONTROLES ==========

  Future<void> setZoomLevel(double zoom) =>
      _guard(() => _requireController().setZoomLevel(zoom));

  Future<void> setFlashMode(FlashMode mode) =>
      _guard(() => _requireController().setFlashMode(_toPackageFlash(mode)));

  Future<void> setExposureOffset(double offset) =>
      _guard(() => _requireController().setExposureOffset(offset));

  Future<void> setFocusMode(FocusMode mode) =>
      _guard(() => _requireController().setFocusMode(_toPackageFocus(mode)));

  /// Tap-to-focus. [point] en coordenadas normalizadas (0,0)–(1,1); `null`
  /// restablece el punto de enfoque por defecto. `Offset` es un tipo de
  /// `dart:ui`, no del paquete `camera`, por lo que no cruza la frontera.
  ///
  /// Nota (Android/CameraX): el plugin `camera_android_camerax` reporta
  /// `focusPointSupported = true` de forma fija para toda cámara, así que ese
  /// flag NO permite predecir el soporte real. La única señal fiable es la
  /// respuesta del hardware: al enviar el punto, CameraX lanza
  /// "None of the specified AF/AE/AWB MeteringPoints is supported on this
  /// camera" en cámaras (típicamente frontales) sin metering configurable.
  /// Por eso se captura y degrada esa excepción concreta sin propagarla como
  /// fallo. Cualquier otra excepción se traduce/propaga normalmente.
  Future<void> setFocusPoint(Offset? point) => _guard(() async {
        final controller = _requireController();
        try {
          await controller.setFocusPoint(point);
        } on cam.CameraException catch (e) {
          if (_isMeteringUnsupported(e)) {
            _logger.d(
                'La cámara activa no soporta metering por punto (tap-to-focus '
                'omitido en hardware): ${e.description ?? e.code}');
            return; // Degradación segura: no propagar como error.
          }
          rethrow;
        }
      });

  /// Detecta la excepción de CameraX de metering no soportado por el hardware.
  bool _isMeteringUnsupported(cam.CameraException e) {
    final text = '${e.code} ${e.description ?? ''}'.toLowerCase();
    return text.contains('meteringpoint') && text.contains('supported');
  }

  Future<void> lockExposure() => _guard(
      () => _requireController().setExposureMode(cam.ExposureMode.locked));

  Future<void> unlockExposure() =>
      _guard(() => _requireController().setExposureMode(cam.ExposureMode.auto));

  Future<void> setPreviewOrientationLock(bool locked) => _guard(() async {
        final controller = _requireController();
        if (locked) {
          await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
        } else {
          await controller.unlockCaptureOrientation();
        }
      });

  /// Rango de zoom soportado, para que el servicio no toque el paquete.
  Future<double> getMinZoom() =>
      _guard(() => _requireController().getMinZoomLevel());
  Future<double> getMaxZoom() =>
      _guard(() => _requireController().getMaxZoomLevel());

  // ========== PREVIEW ==========

  Widget buildPreview(BoxFit fit) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final size = controller.value.previewSize;
    if (size == null) {
      return cam.CameraPreview(controller);
    }
    return ClipRect(
      child: FittedBox(
        fit: fit,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: cam.CameraPreview(controller),
        ),
      ),
    );
  }

  Size? get previewResolution {
    final size = _controller?.value.previewSize;
    if (size == null) return null;
    return Size(size.width, size.height);
  }

  // ========== FRAME STREAM (REALTIME) ==========

  final StreamController<CameraFrame> _frameController =
      StreamController<CameraFrame>.broadcast();

  Stream<CameraFrame> get frameStream => _frameController.stream;

  bool _frameStreamActive = false;
  int _frameCounter = 0;
  FrameStreamConfig? _frameStreamConfig;

  /// Grupo de formato solicitado a la plataforma para el stream (se aplica al
  /// construir el `CameraController`). Por defecto YUV420.
  cam.ImageFormatGroup _requestedImageFormatGroup = cam.ImageFormatGroup.yuv420;

  /// Marca de tiempo del último frame ENTREGADO, para aplicar throttling por
  /// `maxFps` antes de cualquier trabajo costoso.
  int _lastDeliveredFrameMicros = 0;

  /// Inicia el stream de frames de la cámara.
  ///
  /// No convierte color: entrega los planos tal como llegan de la plataforma
  /// (copiados a buffers propios) junto con su formato y disposición reales.
  Future<void> startFrameStream(FrameStreamConfig config) async {
    if (_frameStreamActive) {
      throw const CameraException(
        type: CameraErrorType.deviceError,
        message: 'Frame stream already active. Call stopFrameStream() first.',
      );
    }

    final controller = _requireController();
    // Registrar el formato solicitado para futuras (re)inicializaciones del
    // controller. El controller vigente conserva el imageFormatGroup con el que
    // fue creado; el formato REAL se lee de cada frame de todas formas.
    _requestedImageFormatGroup =
        _toPackageImageFormatGroup(config.requestedFormat);
    _frameStreamConfig = config;
    _frameCounter = 0;
    _lastDeliveredFrameMicros = 0;
    _frameStreamActive = true;

    await controller.startImageStream(_onImageAvailable);
  }

  /// Detiene el stream de frames y limpia su estado. Idempotente.
  Future<void> stopFrameStream() async {
    if (!_frameStreamActive) return;

    final controller = _controller;
    _frameStreamActive = false;
    _frameStreamConfig = null;

    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.stopImageStream();
      } catch (e) {
        _logger.w('Error deteniendo image stream: $e');
      }
    }
  }

  void _onImageAvailable(cam.CameraImage image) {
    // Protección contra frames tardíos: si el stream ya se detuvo, ignorar.
    if (!_frameStreamActive) return;

    final config = _frameStreamConfig;
    if (config == null) return;

    // Throttling por maxFps ANTES de cualquier copia de buffers.
    if (!_shouldDeliver(config)) return;

    try {
      final format = mapPackageFormatGroup(image.format.group);
      final layout = resolveFrameLayout(format, image.planes.length);
      // Copia defensiva de cada plano (ownership del consumidor). No hay
      // conversión de color: se preservan bytes, strides y dimensiones tal cual.
      final planes = <PlaneDescriptor>[
        for (final p in image.planes)
          PlaneDescriptor(
            bytes: Uint8List.fromList(p.bytes),
            bytesPerRow: p.bytesPerRow,
            bytesPerPixel: p.bytesPerPixel,
            width: p.width,
            height: p.height,
          ),
      ];

      final frame = CameraFrame(
        planes: planes,
        width: image.width,
        height: image.height,
        format: format,
        layout: layout,
        metadata: CameraFrameMetadata(
          timestamp: DateTime.now(),
          orientation: FrameOrientation(
            sensorOrientation: _description?.sensorOrientation ?? 0,
            // Camera Core no captura hoy la orientación de display por frame;
            // por tanto rotationDegrees no puede derivarse de forma fiable.
            deviceOrientation: null,
            rotationDegrees: null,
          ),
          lensDirection: _description != null
              ? _fromPackageLens(_description!.lensDirection)
              : CameraLensDirection.back,
          // Heurística explícita: no hay dato fiable de mirroring en el paquete.
          isMirroredHeuristic:
              _description?.lensDirection == cam.CameraLensDirection.front,
        ),
        frameId: _frameCounter++,
      );
      if (_frameStreamActive && !_frameController.isClosed) {
        _frameController.add(frame);
      }
    } catch (e, s) {
      _logger.e('Error procesando frame: $e', e, s);
      if (!_frameController.isClosed) {
        _frameController.addError(e, s);
      }
    }
  }

  /// Decide si el frame actual debe entregarse según `maxFps`. Descarta frames
  /// que lleguen antes del intervalo mínimo. `maxFps` null o <= 0 = sin límite.
  bool _shouldDeliver(FrameStreamConfig config) {
    final maxFps = config.maxFps;
    if (maxFps == null || maxFps <= 0) return true;

    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    final minIntervalMicros = 1000000 ~/ maxFps;
    if (_lastDeliveredFrameMicros != 0 &&
        (nowMicros - _lastDeliveredFrameMicros) < minIntervalMicros) {
      return false; // Descartar: llegó demasiado pronto.
    }
    _lastDeliveredFrameMicros = nowMicros;
    return true;
  }

  cam.ImageFormatGroup _toPackageImageFormatGroup(CameraFrameFormat f) =>
      switch (f) {
        CameraFrameFormat.yuv420 => cam.ImageFormatGroup.yuv420,
        CameraFrameFormat.nv21 => cam.ImageFormatGroup.nv21,
        CameraFrameFormat.bgra8888 => cam.ImageFormatGroup.bgra8888,
        CameraFrameFormat.jpeg => cam.ImageFormatGroup.jpeg,
        CameraFrameFormat.unknown => cam.ImageFormatGroup.unknown,
      };

  // ========== CICLO DE VIDA ==========

  Future<void> dispose() async {
    await stopFrameStream();
    await _frameController.close();
    await _safeDisposeController();
    _description = null;
    _currentCapabilities = null;
  }

  // ========== INTERNOS ==========

  Future<List<cam.CameraDescription>> _rawAvailableCameras() async {
    try {
      return await cam.availableCameras();
    } on cam.CameraException catch (e, s) {
      throw _translate(e, s, CameraErrorType.deviceError);
    }
  }

  Future<void> _applyConfig(CameraConfig config) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setFlashMode(_toPackageFlash(config.flashMode));
    await controller.setFocusMode(_toPackageFocus(config.focusMode));
    if (config.exposureOffset != 0.0) {
      await controller.setExposureOffset(config.exposureOffset);
    }
    if (config.zoomLevel != 1.0) {
      await controller.setZoomLevel(config.zoomLevel);
    }
    if (config.lockPreviewOrientation) {
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    }
  }

  Future<CameraCapabilities> _readCapabilities(
    cam.CameraController controller,
  ) async {
    final minZoom = await controller.getMinZoomLevel();
    final maxZoom = await controller.getMaxZoomLevel();
    final minExp = await controller.getMinExposureOffset();
    final maxExp = await controller.getMaxExposureOffset();
    final step = await controller.getExposureOffsetStepSize();
    return CameraCapabilities(
      minZoom: minZoom,
      maxZoom: maxZoom,
      minExposureOffset: minExp,
      maxExposureOffset: maxExp,
      exposureStepSize: step,
      supportedResolutions: const [
        ResolutionPreset.low,
        ResolutionPreset.medium,
        ResolutionPreset.high,
        ResolutionPreset.veryHigh,
        ResolutionPreset.ultraHigh,
        ResolutionPreset.max,
      ],
      supportedFlashModes: const [
        FlashMode.off,
        FlashMode.on,
        FlashMode.auto,
        FlashMode.torch,
      ],
      supportedFocusModes: const [
        FocusMode.auto,
        FocusMode.locked,
      ],
      supportsExposureControl: maxExp != minExp,
      supportsFocusControl: true,
      supportsZoom: maxZoom > minZoom,
    );
  }

  CameraCapabilities _defaultCapabilities() => const CameraCapabilities(
        minZoom: 1.0,
        maxZoom: 1.0,
        minExposureOffset: 0.0,
        maxExposureOffset: 0.0,
        exposureStepSize: 0.0,
        supportedResolutions: [ResolutionPreset.high],
        supportedFlashModes: [FlashMode.off],
        supportedFocusModes: [FocusMode.auto],
        supportsExposureControl: false,
        supportsFocusControl: false,
        supportsZoom: false,
      );

  cam.CameraController _requireController() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const CameraException(
        type: CameraErrorType.controllerDisposed,
        message: 'El controlador de cámara no está inicializado.',
      );
    }
    return controller;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on CameraException {
      rethrow;
    } on cam.CameraException catch (e, s) {
      throw _translate(e, s, CameraErrorType.deviceError);
    } catch (e, s) {
      throw CameraException(
        type: CameraErrorType.deviceError,
        message: 'Error de dispositivo de cámara: $e',
        originalError: e,
        stackTrace: s,
      );
    }
  }

  Future<void> _safeDisposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (e) {
      _logger.w('Error liberando CameraController: $e');
    }
  }

  CameraException _translate(
    cam.CameraException e,
    StackTrace s,
    CameraErrorType fallback,
  ) {
    final type = switch (e.code) {
      'CameraAccessDenied' => CameraErrorType.permissionDenied,
      'CameraAccessDeniedWithoutPrompt' =>
        CameraErrorType.permissionDeniedForever,
      'CameraAccessRestricted' => CameraErrorType.permissionDenied,
      _ => fallback,
    };
    return CameraException(
      type: type,
      message: e.description ?? e.code,
      originalError: e,
      stackTrace: s,
    );
  }

  // ---- Mapeos enum propio <-> paquete ----

  CameraInfo _toCameraInfo(
    cam.CameraDescription d,
    CameraCapabilities caps,
  ) {
    return CameraInfo(
      name: d.name,
      lensDirection: _fromPackageLens(d.lensDirection),
      sensorOrientation: d.sensorOrientation,
      capabilities: caps,
    );
  }

  cam.CameraLensDirection _toPackageLens(CameraLensDirection d) => switch (d) {
        CameraLensDirection.front => cam.CameraLensDirection.front,
        CameraLensDirection.back => cam.CameraLensDirection.back,
        CameraLensDirection.external => cam.CameraLensDirection.external,
      };

  CameraLensDirection _fromPackageLens(cam.CameraLensDirection d) =>
      switch (d) {
        cam.CameraLensDirection.front => CameraLensDirection.front,
        cam.CameraLensDirection.back => CameraLensDirection.back,
        cam.CameraLensDirection.external => CameraLensDirection.external,
      };

  cam.ResolutionPreset _toPackagePreset(ResolutionPreset p) => switch (p) {
        ResolutionPreset.low => cam.ResolutionPreset.low,
        ResolutionPreset.medium => cam.ResolutionPreset.medium,
        ResolutionPreset.high => cam.ResolutionPreset.high,
        ResolutionPreset.veryHigh => cam.ResolutionPreset.veryHigh,
        ResolutionPreset.ultraHigh => cam.ResolutionPreset.ultraHigh,
        ResolutionPreset.max => cam.ResolutionPreset.max,
      };

  cam.FlashMode _toPackageFlash(FlashMode m) => switch (m) {
        FlashMode.off => cam.FlashMode.off,
        FlashMode.on => cam.FlashMode.always,
        FlashMode.auto => cam.FlashMode.auto,
        FlashMode.torch => cam.FlashMode.torch,
      };

  cam.FocusMode _toPackageFocus(FocusMode m) => switch (m) {
        FocusMode.auto => cam.FocusMode.auto,
        FocusMode.locked => cam.FocusMode.locked,
        // El paquete no expone un modo "macro" dedicado; se mapea a auto.
        FocusMode.macro => cam.FocusMode.auto,
      };
}

/// Salida cruda de una captura del wrapper: ruta local + resolución real del
/// archivo. Tipo interno del subsistema de cámara; no expone tipos del paquete
/// `camera`.
class CaptureOutput {
  final String path;
  final ui.Size resolution;

  const CaptureOutput({required this.path, required this.resolution});
}

// ============================================================================
// Mapeos puros (sin dependencia de estado del controlador) extraídos para que
// puedan testearse unitariamente. Toman/retornan únicamente tipos del paquete
// `camera` de entrada y modelos propios de salida.
// ============================================================================

/// Mapea el `ImageFormatGroup` real del paquete a nuestro formato propio.
CameraFrameFormat mapPackageFormatGroup(cam.ImageFormatGroup group) =>
    switch (group) {
      cam.ImageFormatGroup.yuv420 => CameraFrameFormat.yuv420,
      cam.ImageFormatGroup.nv21 => CameraFrameFormat.nv21,
      cam.ImageFormatGroup.bgra8888 => CameraFrameFormat.bgra8888,
      cam.ImageFormatGroup.jpeg => CameraFrameFormat.jpeg,
      cam.ImageFormatGroup.unknown => CameraFrameFormat.unknown,
    };

/// Deriva la disposición física a partir del formato real y el número de
/// planos entregados. No asume 3 planos.
FrameLayout resolveFrameLayout(CameraFrameFormat format, int planeCount) {
  switch (format) {
    case CameraFrameFormat.bgra8888:
      return FrameLayout.bgra8888;
    case CameraFrameFormat.jpeg:
      return FrameLayout.jpeg;
    case CameraFrameFormat.nv21:
      return FrameLayout.nv21;
    case CameraFrameFormat.yuv420:
      if (planeCount >= 3) return FrameLayout.yuv420Triplanar;
      if (planeCount == 2) return FrameLayout.yuv420Biplanar;
      return FrameLayout.unknown;
    case CameraFrameFormat.unknown:
      return FrameLayout.unknown;
  }
}
