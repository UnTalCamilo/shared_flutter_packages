// Los colaboradores 1:1 (`_scanner`, `_throttle`) se agrupan en la lista de
// inicializadores junto a `_duplicates`, que sí se deriva; se omite el lint de
// initializing formals para mantenerlos juntos y legibles.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:camera_core/camera_core.dart';

import '../contracts/qr_scanner_service.dart';
import '../models/qr_duplicate_policy.dart';
import '../models/qr_scan_result.dart';
import '../models/qr_scan_throttle.dart';

/// Sesión de escaneo sobre un `Stream<CameraFrame>` continuo.
///
/// Aplica, en este orden, la estrategia correcta para detección en vivo:
/// 1. **throttle**: descarta frames que llegan antes del intervalo mínimo;
/// 2. **drop-if-busy**: si hay una detección en vuelo, descarta el frame (no
///    encola); así siempre se trabaja sobre un frame reciente;
/// 3. **duplicados**: aplica la [QrDuplicatePolicy] antes de emitir.
///
/// El `IQrScanner` subyacente NO es propiedad de la sesión: su `dispose()` lo
/// gestiona quien lo creó.
class QrScanSessionImpl implements IQrScanSession {
  final IQrScanner _scanner;
  final QrScanThrottle _throttle;
  final QrDuplicateMatcher _duplicates;

  final StreamController<QrScanResult> _results =
      StreamController<QrScanResult>.broadcast();
  StreamSubscription<CameraFrame>? _frameSub;

  bool _busy = false;
  int _lastProcessedMicros = 0;
  bool _disposed = false;

  QrScanSessionImpl({
    required IQrScanner scanner,
    required Stream<CameraFrame> frames,
    QrScanThrottle throttle = QrScanThrottle.none,
    QrDuplicatePolicy duplicatePolicy =
        const QrDuplicatePolicy.cooldown(Duration(seconds: 2)),
  })  : _scanner = scanner,
        _throttle = throttle,
        _duplicates = duplicatePolicy.createMatcher() {
    _frameSub = frames.listen(_onFrame, onError: _onError);
  }

  @override
  Stream<QrScanResult> get results => _results.stream;

  void _onFrame(CameraFrame frame) {
    if (_disposed || _busy) return; // drop-if-busy
    if (!_passesThrottle()) return; // throttle temporal
    _busy = true;
    _process(frame);
  }

  Future<void> _process(CameraFrame frame) async {
    try {
      final result = await _scanner.detect(frame);
      if (_disposed || result == null) return;
      final now = DateTime.now();
      if (_duplicates.shouldEmit(result.rawValue, now)) {
        if (!_results.isClosed) _results.add(result);
      }
    } catch (e, s) {
      if (!_results.isClosed) _results.addError(e, s);
    } finally {
      _busy = false;
    }
  }

  bool _passesThrottle() {
    final minMicros = _throttle.minInterval.inMicroseconds;
    if (minMicros <= 0) return true;
    final now = DateTime.now().microsecondsSinceEpoch;
    if (_lastProcessedMicros != 0 &&
        (now - _lastProcessedMicros) < minMicros) {
      return false;
    }
    _lastProcessedMicros = now;
    return true;
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (!_results.isClosed) _results.addError(error, stackTrace);
  }

  @override
  void resetDuplicates() => _duplicates.reset();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _frameSub?.cancel();
    _frameSub = null;
    _results.close();
  }
}
