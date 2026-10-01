import 'dart:typed_data';

import 'camera_config.dart';

/// Formato REAL de píxeles de un frame entregado por la cámara.
///
/// Refleja el formato efectivamente recibido de la plataforma, no el solicitado.
/// Alineado con los grupos que expone `package:camera` (mapeado en el wrapper,
/// sin importar tipos externos aquí).
enum CameraFrameFormat {
  /// YUV 4:2:0. La disposición concreta (tri/biplanar) la indica [FrameLayout].
  yuv420,

  /// YCbCr NV21 (Android): Y + VU interleaved.
  nv21,

  /// 32-bit BGRA (típico de iOS por defecto y GPU-friendly).
  bgra8888,

  /// JPEG comprimido (algunas plataformas pueden entregarlo directo).
  jpeg,

  /// Formato no reconocido / no mapeable a un grupo conocido.
  unknown,
}

/// Disposición física de los planos del frame.
///
/// Es información imprescindible para que un consumidor (GPU/ML) interprete los
/// buffers sin conocer `package:camera` ni la plataforma de origen.
enum FrameLayout {
  /// YUV420 con 3 planos separados (Android `YUV_420_888`): Y, U, V.
  yuv420Triplanar,

  /// YUV420 con 2 planos (iOS biplanar): Y, CbCr interleaved.
  yuv420Biplanar,

  /// NV21: Y + VU interleaved (puede representarse en 1 o 2 planos).
  nv21,

  /// Un único plano BGRA interleaved.
  bgra8888,

  /// Un único plano JPEG.
  jpeg,

  /// Disposición desconocida.
  unknown,
}

/// Descriptor de un plano de imagen. Modelo propio, equivalente conceptual a
/// `Plane` de `package:camera` pero sin dependencia de esa librería.
///
/// [bytesPerPixel] es `null` en iOS; [width]/[height] son `null` en Android
/// (reflejando exactamente lo que la plataforma provee).
class PlaneDescriptor {
  final Uint8List bytes;

  /// Row stride en bytes (distancia entre filas). Puede incluir padding.
  final int bytesPerRow;

  /// Pixel stride en bytes (distancia entre muestras). `null` si la plataforma
  /// no lo provee (iOS).
  final int? bytesPerPixel;

  /// Ancho del buffer de este plano, si la plataforma lo provee (iOS).
  final int? width;

  /// Alto del buffer de este plano, si la plataforma lo provee (iOS).
  final int? height;

  const PlaneDescriptor({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
    this.width,
    this.height,
  });

  int get byteSize => bytes.length;
}

/// Orientación efectiva del frame para consumidores realtime (GPU/ML Kit).
///
/// Modelo propio: no acopla a ML Kit ni a `package:camera`.
///
/// [rotationDegrees] es la rotación (0/90/180/270) que un consumidor debe
/// aplicar para mostrar/analizar el frame en la orientación correcta, cuando se
/// pueda derivar. Si no puede determinarse, es `null` (desconocido) — nunca se
/// inventa un valor.
class FrameOrientation {
  /// Orientación del sensor en grados (0/90/180/270). Siempre disponible.
  final int sensorOrientation;

  /// Orientación del dispositivo/display en grados, si Camera Core la conoce.
  /// Actualmente no se captura por frame → `null`.
  final int? deviceOrientation;

  /// Rotación efectiva a aplicar (derivada de sensor + device). `null` si no
  /// puede determinarse de forma fiable con la información actual.
  final int? rotationDegrees;

  const FrameOrientation({
    required this.sensorOrientation,
    this.deviceOrientation,
    this.rotationDegrees,
  });
}

/// Metadatos por frame necesarios para interpretar el buffer.
///
/// Decisión de diseño (A1): este modelo contiene únicamente lo necesario para
/// **interpretar la imagen**. El estado de control de la cámara (zoom,
/// exposición) NO vive aquí: no es un dato de la imagen sino del controlador, y
/// un consumidor de visión (QR/rostro/OCR) no lo necesita para leer el frame.
/// Las dimensiones del frame viven en [CameraFrame.width]/[CameraFrame.height]
/// y no se duplican aquí.
class CameraFrameMetadata {
  final DateTime timestamp;

  /// Orientación/geometría del frame.
  final FrameOrientation orientation;

  final CameraLensDirection lensDirection;

  /// Estado de espejado (mirroring) del frame.
  ///
  /// `package:camera` no expone de forma fiable si el buffer frontal ya viene
  /// espejado. Este campo es una HEURÍSTICA (`true` para cámara frontal) y así
  /// se documenta; los consumidores de ML/overlays no deben tratarlo como
  /// garantía. `null` cuando no se puede afirmar nada.
  final bool? isMirroredHeuristic;

  const CameraFrameMetadata({
    required this.timestamp,
    required this.orientation,
    required this.lensDirection,
    this.isMirroredHeuristic,
  });

  /// Acceso de conveniencia a la orientación del sensor.
  int get sensorOrientation => orientation.sensorOrientation;
}

/// Frame de cámara para procesamiento en tiempo real.
///
/// Frontera rica e independiente de `package:camera`. Transporta los planos tal
/// como los entrega la plataforma (con sus strides y dimensiones), el formato
/// REAL recibido y su disposición ([layout]), para que un consumidor (GPU, ML
/// Kit, etc.) pueda interpretarlo inequívocamente sin conocer la librería de
/// cámara.
///
/// Inmutable. Los buffers de [planes] son COPIAS propiedad del consumidor: el
/// wrapper copia cada plano al construir el frame, por lo que no hay riesgo de
/// que la cámara reutilice/modifique el buffer entregado.
class CameraFrame {
  /// Planos del frame. 1 plano (BGRA/JPEG/NV21 empaquetado), 2 (YUV biplanar)
  /// o 3 (YUV triplanar), según [layout].
  final List<PlaneDescriptor> planes;

  final int width;
  final int height;

  /// Formato real recibido de la plataforma.
  final CameraFrameFormat format;

  /// Disposición física de los planos.
  final FrameLayout layout;

  final CameraFrameMetadata metadata;
  final int frameId;

  const CameraFrame({
    required this.planes,
    required this.width,
    required this.height,
    required this.format,
    required this.layout,
    required this.metadata,
    required this.frameId,
  });

  double get aspectRatio => width / height;

  /// Suma de bytes de todos los planos.
  int get byteSize {
    var total = 0;
    for (final p in planes) {
      total += p.bytes.length;
    }
    return total;
  }

  /// Bytes del primer plano, por conveniencia (p. ej. plano Y de YUV o el
  /// buffer BGRA). No representa el frame completo en formatos multiplano.
  Uint8List get primaryPlaneBytes => planes.first.bytes;
}
