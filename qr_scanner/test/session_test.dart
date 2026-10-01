import 'dart:async';

import 'package:camera_core/camera_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scanner/qr_scanner.dart';

import 'support/fake_qr_scanner.dart';
import 'support/frame_factory.dart';

void main() {
  group('QrScanSession — detección y filtrado', () {
    test('emite un resultado cuando el detector encuentra un código',
        () async {
      final scanner = FakeQrScanner((_) => qrResult('ABC'));
      final frames = StreamController<CameraFrame>.broadcast();
      final session = QrScanner.session(
        scanner: scanner,
        frames: frames.stream,
        duplicatePolicy: const QrDuplicatePolicy.emitEveryFrame(),
      );

      final received = <QrScanResult>[];
      final sub = session.results.listen(received.add);

      frames.add(fakeFrame(id: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(received, hasLength(1));
      expect(received.first.rawValue, 'ABC');

      await sub.cancel();
      session.dispose();
      await frames.close();
    });

    test('no emite cuando el detector devuelve null', () async {
      final scanner = FakeQrScanner((_) => null);
      final frames = StreamController<CameraFrame>.broadcast();
      final session = QrScanner.session(scanner: scanner, frames: frames.stream);

      final received = <QrScanResult>[];
      final sub = session.results.listen(received.add);

      frames.add(fakeFrame(id: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(received, isEmpty);
      expect(scanner.detectCalls, 1);

      await sub.cancel();
      session.dispose();
      await frames.close();
    });

    test('propaga errores del detector por el stream sin cerrarlo', () async {
      final scanner = FakeQrScanner((_) => throw StateError('boom'));
      final frames = StreamController<CameraFrame>.broadcast();
      final session = QrScanner.session(scanner: scanner, frames: frames.stream);

      Object? error;
      final sub = session.results.listen(
        (_) {},
        onError: (Object e, StackTrace _) => error = e,
      );

      frames.add(fakeFrame(id: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(error, isA<StateError>());

      await sub.cancel();
      session.dispose();
      await frames.close();
    });
  });

  group('QrScanSession — drop-if-busy', () {
    test('descarta frames que llegan mientras hay una detección en vuelo',
        () async {
      // Detector lento: 60ms por frame.
      final scanner = FakeQrScanner(
        (_) => qrResult('ABC'),
        delay: const Duration(milliseconds: 60),
      );
      final frames = StreamController<CameraFrame>.broadcast();
      final session = QrScanner.session(
        scanner: scanner,
        frames: frames.stream,
        duplicatePolicy: const QrDuplicatePolicy.emitEveryFrame(),
      );
      final sub = session.results.listen((_) {});

      // Emitir 5 frames casi simultáneos; solo el primero debe procesarse
      // (los demás caen por drop-if-busy mientras el primero está en vuelo).
      for (var i = 0; i < 5; i++) {
        frames.add(fakeFrame(id: i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
      // Durante la detección en vuelo: una sola llamada.
      expect(scanner.detectCalls, 1);

      await sub.cancel();
      session.dispose();
      await frames.close();
    });
  });

  group('QrScanSession — throttle temporal', () {
    test('respeta el intervalo mínimo entre detecciones', () async {
      final scanner = FakeQrScanner((_) => qrResult('ABC'));
      final frames = StreamController<CameraFrame>.broadcast();
      final session = QrScanner.session(
        scanner: scanner,
        frames: frames.stream,
        throttle: const QrScanThrottle(minInterval: Duration(milliseconds: 100)),
        duplicatePolicy: const QrDuplicatePolicy.emitEveryFrame(),
      );
      final sub = session.results.listen((_) {});

      // Primer frame pasa; segundo inmediato debe descartarse por throttle.
      frames.add(fakeFrame(id: 1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      frames.add(fakeFrame(id: 2));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(scanner.detectCalls, 1);

      // Tras superar el intervalo, otro frame sí se procesa.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      frames.add(fakeFrame(id: 3));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(scanner.detectCalls, 2);

      await sub.cancel();
      session.dispose();
      await frames.close();
    });
  });

  group('QrScanSession — duplicados', () {
    test('cooldown suprime el mismo valor repetido entre frames', () async {
      final scanner = FakeQrScanner((_) => qrResult('ABC'));
      final frames = StreamController<CameraFrame>.broadcast();
      final session = QrScanner.session(
        scanner: scanner,
        frames: frames.stream,
        duplicatePolicy: const QrDuplicatePolicy.cooldown(Duration(seconds: 10)),
      );
      final received = <QrScanResult>[];
      final sub = session.results.listen(received.add);

      // Varios frames con el mismo valor, espaciados para evitar drop-if-busy.
      for (var i = 0; i < 4; i++) {
        frames.add(fakeFrame(id: i));
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }

      // Solo la primera emisión; el resto suprimido por cooldown.
      expect(received, hasLength(1));
      expect(received.first.rawValue, 'ABC');

      await sub.cancel();
      session.dispose();
      await frames.close();
    });
  });

  group('QrScanSession — ciclo de vida', () {
    test('dispose detiene el procesamiento y cierra el stream', () async {
      final scanner = FakeQrScanner((_) => qrResult('ABC'));
      final frames = StreamController<CameraFrame>.broadcast();
      final session = QrScanner.session(scanner: scanner, frames: frames.stream);
      session.dispose();

      // Tras dispose, nuevos frames no generan trabajo.
      frames.add(fakeFrame(id: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(scanner.detectCalls, 0);

      await frames.close();
    });
  });
}
