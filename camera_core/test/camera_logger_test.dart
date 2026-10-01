import 'package:flutter_test/flutter_test.dart';

import 'package:camera_core/camera_core.dart';

/// Logger de prueba que captura los mensajes recibidos por nivel.
class _RecordingLogger implements CameraLogger {
  final List<String> debug = [];
  final List<String> warn = [];
  final List<(String, Object?)> error = [];

  @override
  void d(String message) => debug.add(message);

  @override
  void w(String message) => warn.add(message);

  @override
  void e(String message, [Object? error, StackTrace? stackTrace]) =>
      this.error.add((message, error));
}

void main() {
  group('CameraLogger (puerto)', () {
    test('SilentCameraLogger no lanza y descarta todo', () {
      const logger = SilentCameraLogger();
      // No debe lanzar en ninguno de los niveles.
      expect(() => logger.d('x'), returnsNormally);
      expect(() => logger.w('x'), returnsNormally);
      expect(() => logger.e('x', Exception('e'), StackTrace.current),
          returnsNormally);
    });

    test('DebugPrintCameraLogger no lanza en ningún nivel', () {
      const logger = DebugPrintCameraLogger();
      expect(() => logger.d('debug'), returnsNormally);
      expect(() => logger.w('warn'), returnsNormally);
      expect(() => logger.e('err', Exception('boom'), StackTrace.current),
          returnsNormally);
    });

    test('un logger propio recibe los mensajes (puente de la app)', () {
      final logger = _RecordingLogger();
      logger.d('d1');
      logger.w('w1');
      logger.e('e1', 'cause');

      expect(logger.debug, ['d1']);
      expect(logger.warn, ['w1']);
      expect(logger.error.single.$1, 'e1');
      expect(logger.error.single.$2, 'cause');
    });

    test('CameraCore.createService acepta un logger inyectado', () {
      final logger = _RecordingLogger();
      final service = CameraCore.createService(logger: logger);
      expect(service, isNotNull);
      // No se inicializa (requiere hardware); solo se verifica el cableado.
    });
  });
}
