/// Estrategia de ritmo de procesamiento de frames para una sesión de escaneo.
///
/// La detección debe trabajar sobre el frame MÁS RECIENTE, no sobre una cola.
/// Por eso la sesión siempre aplica *drop-if-busy* (un solo frame en vuelo). A
/// eso se suma, opcionalmente, un intervalo mínimo entre detecciones.
class QrScanThrottle {
  /// Intervalo mínimo entre dos detecciones. `Duration.zero` = sin límite extra
  /// (solo rige el drop-if-busy).
  final Duration minInterval;

  const QrScanThrottle({this.minInterval = Duration.zero});

  /// Sin throttle de tiempo (solo drop-if-busy).
  static const QrScanThrottle none = QrScanThrottle();

  /// Atajo para limitar a ~[fps] detecciones por segundo.
  factory QrScanThrottle.fps(int fps) => QrScanThrottle(
        minInterval: fps <= 0
            ? Duration.zero
            : Duration(milliseconds: (1000 / fps).floor()),
      );
}
