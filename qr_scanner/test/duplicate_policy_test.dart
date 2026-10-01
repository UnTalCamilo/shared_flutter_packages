import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scanner/qr_scanner.dart';

void main() {
  final t0 = DateTime(2024, 1, 1, 0, 0, 0);

  group('QrDuplicatePolicy.cooldown', () {
    test('suprime el mismo valor dentro de la ventana y lo reemite después',
        () {
      final m = const QrDuplicatePolicy.cooldown(Duration(seconds: 2))
          .createMatcher();

      expect(m.shouldEmit('ABC', t0), isTrue);
      // Mismo valor dentro de 2s: suprimido.
      expect(m.shouldEmit('ABC', t0.add(const Duration(milliseconds: 500))),
          isFalse);
      expect(m.shouldEmit('ABC', t0.add(const Duration(milliseconds: 1999))),
          isFalse);
      // Pasada la ventana: reemite.
      expect(
          m.shouldEmit('ABC', t0.add(const Duration(seconds: 3))), isTrue);
    });

    test('un valor distinto siempre se emite de inmediato', () {
      final m = const QrDuplicatePolicy.cooldown(Duration(seconds: 2))
          .createMatcher();
      expect(m.shouldEmit('ABC', t0), isTrue);
      expect(m.shouldEmit('XYZ', t0.add(const Duration(milliseconds: 100))),
          isTrue);
    });

    test('reset limpia el estado', () {
      final m = const QrDuplicatePolicy.cooldown(Duration(seconds: 2))
          .createMatcher();
      expect(m.shouldEmit('ABC', t0), isTrue);
      m.reset();
      expect(m.shouldEmit('ABC', t0.add(const Duration(milliseconds: 100))),
          isTrue);
    });
  });

  group('QrDuplicatePolicy.once', () {
    test('emite una vez por valor hasta que cambie', () {
      final m = const QrDuplicatePolicy.once().createMatcher();
      expect(m.shouldEmit('ABC', t0), isTrue);
      expect(m.shouldEmit('ABC', t0.add(const Duration(hours: 1))), isFalse);
      expect(m.shouldEmit('XYZ', t0.add(const Duration(hours: 2))), isTrue);
    });
  });

  group('QrDuplicatePolicy.emitEveryFrame', () {
    test('nunca suprime', () {
      final m = const QrDuplicatePolicy.emitEveryFrame().createMatcher();
      expect(m.shouldEmit('ABC', t0), isTrue);
      expect(m.shouldEmit('ABC', t0), isTrue);
      expect(m.shouldEmit('ABC', t0), isTrue);
    });
  });
}
