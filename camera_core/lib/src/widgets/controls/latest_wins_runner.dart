/// Ejecutor "latest-wins" para controles continuos (zoom, exposición).
///
/// Garantiza una sola operación en vuelo sobre el servicio de cámara: mientras
/// una llamada está pendiente, conserva solo el ÚLTIMO valor solicitado y lo
/// aplica al terminar la anterior. Evita saturar el `CameraController` con
/// llamadas concurrentes desde un slider. Sin `Timer`, sin managers.
///
/// Es un helper interno reutilizable por los controles de `camera_core`; no
/// forma parte de la API pública.
class LatestWinsRunner {
  final Future<void> Function(double value) _apply;

  LatestWinsRunner(this._apply);

  double? _pending;
  bool _busy = false;
  bool _disposed = false;

  /// Solicita aplicar [value]. Si ya hay una operación en vuelo, reemplaza el
  /// valor pendiente; en caso contrario arranca el procesamiento.
  void request(double value) {
    if (_disposed) return;
    _pending = value;
    if (_busy) return;
    _process();
  }

  Future<void> _process() async {
    _busy = true;
    while (_pending != null && !_disposed) {
      final value = _pending!;
      _pending = null;
      try {
        await _apply(value);
      } catch (_) {
        // Degradación silenciosa: un control no debe romper la experiencia.
      }
    }
    _busy = false;
  }

  void dispose() {
    _disposed = true;
    _pending = null;
  }
}
