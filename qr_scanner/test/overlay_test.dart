import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scanner/qr_scanner.dart';

void main() {
  group('QrScannerOverlay', () {
    testWidgets('se renderiza sin cámara ni servicio y no captura toques',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Stack(children: [QrScannerOverlay()]),
        ),
      ));

      expect(find.byType(QrScannerOverlay), findsOneWidget);
      // Es solo pintura: ignora punteros (no intercepta gestos del preview).
      // El IgnorePointer vive DENTRO del overlay (puede haber otros en el árbol
      // de Material, por eso se busca como descendiente).
      expect(
        find.descendant(
          of: find.byType(QrScannerOverlay),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
      // Y envuelve un CustomPaint (la pintura del marco).
      expect(
        find.descendant(
          of: find.byType(QrScannerOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('se compone sobre un placeholder de preview en un Stack',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            SizedBox.expand(key: Key('preview-placeholder')),
            QrScannerOverlay(windowSize: 200, scrimOpacity: 0.3),
          ]),
        ),
      ));

      expect(find.byKey(const Key('preview-placeholder')), findsOneWidget);
      expect(find.byType(QrScannerOverlay), findsOneWidget);
    });
  });
}
