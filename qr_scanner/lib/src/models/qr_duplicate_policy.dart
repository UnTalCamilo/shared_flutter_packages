/// Política de emisión de resultados duplicados.
///
/// Una cámara puede detectar el mismo código durante cientos de frames. Esta
/// política —parte del CONTRATO, no una variable escondida en el widget— decide
/// cuándo un resultado se emite y cuándo se suprime por repetido.
///
/// Modos:
/// - [QrDuplicatePolicy.cooldown]: tras emitir un valor, suprime el MISMO valor
///   durante [cooldown]; pasado ese tiempo lo vuelve a emitir. Evita el
///   bombardeo sin bloquear permanentemente.
/// - [QrDuplicatePolicy.once]: emite un valor una sola vez; solo vuelve a
///   emitir cuando el valor cambia a otro distinto.
/// - [QrDuplicatePolicy.emitEveryFrame]: sin supresión (cada detección se
///   emite).
class QrDuplicatePolicy {
  final _QrDuplicateMode _mode;
  final Duration cooldown;

  const QrDuplicatePolicy._(this._mode, this.cooldown);

  /// Suprime el mismo valor durante [duration]; luego lo reemite.
  const QrDuplicatePolicy.cooldown(Duration duration)
      : this._(_QrDuplicateMode.cooldown, duration);

  /// Emite un valor una sola vez hasta que cambie a otro distinto.
  const QrDuplicatePolicy.once()
      : this._(_QrDuplicateMode.once, Duration.zero);

  /// Sin supresión: cada detección se emite.
  const QrDuplicatePolicy.emitEveryFrame()
      : this._(_QrDuplicateMode.every, Duration.zero);

  /// Crea un matcher con estado para una sesión. Cada sesión usa el suyo.
  QrDuplicateMatcher createMatcher() => QrDuplicateMatcher._(_mode, cooldown);
}

enum _QrDuplicateMode { cooldown, once, every }

/// Estado mutable que decide, por sesión, si un valor debe emitirse ahora.
///
/// Vive junto a la política (no en el widget ni en el servicio de detección),
/// para que la regla de duplicados sea una sola fuente de verdad.
class QrDuplicateMatcher {
  final _QrDuplicateMode _mode;
  final Duration _cooldown;

  String? _lastValue;
  DateTime? _lastEmitted;

  QrDuplicateMatcher._(this._mode, this._cooldown);

  /// Devuelve `true` si [value] debe emitirse en [now]; actualiza el estado
  /// interno en consecuencia.
  bool shouldEmit(String value, DateTime now) {
    switch (_mode) {
      case _QrDuplicateMode.every:
        return true;
      case _QrDuplicateMode.once:
        if (value == _lastValue) return false;
        _lastValue = value;
        return true;
      case _QrDuplicateMode.cooldown:
        final sameValue = value == _lastValue;
        final within = _lastEmitted != null &&
            now.difference(_lastEmitted!) < _cooldown;
        if (sameValue && within) return false;
        _lastValue = value;
        _lastEmitted = now;
        return true;
    }
  }

  /// Reinicia el estado (p. ej. al reanudar el escaneo).
  void reset() {
    _lastValue = null;
    _lastEmitted = null;
  }
}
