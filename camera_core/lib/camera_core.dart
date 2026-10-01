/// camera_core — infraestructura de cámara reutilizable e independiente de
/// cualquier caso de uso de visión artificial.
///
/// Punto de entrada público del paquete. Solo se exportan los tipos que forman
/// la frontera pública; las implementaciones internas (`CameraServiceImpl`,
/// `CameraControllerWrapper`, `CameraPermissionHandler`) permanecen privadas y
/// se construyen a través de [CameraCore].
library camera_core;

// --- Contrato de comportamiento ---
export 'src/contracts/camera_service.dart' show ICameraService;

// --- Fábrica (cableado sin exponer internos ni depender de un DI) ---
export 'src/camera_core_factory.dart' show CameraCore;

// --- Modelos de dominio (frontera pública) ---
export 'src/models/camera_config.dart'
    show
        CameraConfig,
        CameraLensDirection,
        ResolutionPreset,
        FlashMode,
        FocusMode;
export 'src/models/camera_capabilities.dart' show CameraCapabilities;
export 'src/models/camera_info.dart' show CameraInfo;
export 'src/models/camera_state.dart' show CameraState, CameraStateModel;
export 'src/models/camera_init_result.dart'
    show CameraInitResult, CameraInitResultType;
export 'src/models/camera_error.dart'
    show CameraException, CameraErrorType, CameraPermissionResult;
export 'src/models/capture_result.dart' show CaptureResult, CaptureMetadata;
export 'src/models/camera_frame.dart'
    show
        CameraFrame,
        PlaneDescriptor,
        CameraFrameFormat,
        FrameLayout,
        FrameOrientation,
        CameraFrameMetadata;
export 'src/models/frame_stream_config.dart' show FrameStreamConfig;

// --- Presentación: primitivos de UI componibles ---
//
// Tres niveles de composición:
//  1. CameraPreview        -> solo el render del preview (composición libre).
//  2. Controles sueltos     -> una pieza por capacidad, sin barra ni flags.
//  3. CameraView            -> experiencia conveniente que compone 1 + 2.
// CameraStateBuilder expone la máquina de estados para composiciones a medida.
export 'src/widgets/camera_preview.dart' show CameraPreview;
export 'src/widgets/camera_state_builder.dart' show CameraStateBuilder;
export 'src/widgets/camera_view.dart' show CameraView;
export 'src/widgets/controls/camera_capture_button.dart'
    show CameraCaptureButton;
export 'src/widgets/controls/camera_flash_button.dart' show CameraFlashButton;
export 'src/widgets/controls/camera_switch_button.dart' show CameraSwitchButton;
export 'src/widgets/controls/camera_zoom_control.dart' show CameraZoomControl;
export 'src/widgets/controls/camera_focus_gesture.dart' show CameraFocusGesture;

// --- Logging (puerto; la app puede puentearlo a su propio logger) ---
export 'src/infrastructure/camera_logger.dart'
    show CameraLogger, DebugPrintCameraLogger, SilentCameraLogger;
