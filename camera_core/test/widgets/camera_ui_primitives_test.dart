import 'package:camera_core/camera_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_camera_service.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('CameraPreview (primitivo nivel 1)', () {
    testWidgets('renderiza el preview del servicio sin máquina de estados',
        (tester) async {
      final service = FakeCameraService();
      await tester.pumpWidget(_wrap(CameraPreview(controller: service)));

      expect(find.byKey(const Key('fake-preview')), findsOneWidget);
      // No introduce indicador de carga: es un primitivo puro.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await service.dispose();
    });

    testWidgets('se compone libremente dentro de un Stack con overlay',
        (tester) async {
      final service = FakeCameraService();
      await tester.pumpWidget(_wrap(Stack(children: [
        CameraPreview(controller: service),
        const Text('overlay-qr'),
      ])));

      expect(find.byKey(const Key('fake-preview')), findsOneWidget);
      expect(find.text('overlay-qr'), findsOneWidget);
      await service.dispose();
    });
  });

  group('CameraStateBuilder', () {
    testWidgets('elige el builder correcto por estado', (tester) async {
      final service = FakeCameraService(initialState: CameraState.ready);
      await tester.pumpWidget(_wrap(CameraStateBuilder(
        controller: service,
        ready: (_) => const Text('READY'),
        loadingBuilder: (_) => const Text('LOADING'),
        permissionDeniedBuilder: (_) => const Text('DENIED'),
      )));
      expect(find.text('READY'), findsOneWidget);

      service.emit(CameraState.initializing);
      await tester.pump(); // procesa el evento del stream
      await tester.pump(); // y el rebuild del StreamBuilder
      expect(find.text('LOADING'), findsOneWidget);

      service.emit(CameraState.permissionDenied);
      await tester.pump();
      await tester.pump();
      expect(find.text('DENIED'), findsOneWidget);

      await service.dispose();
    });

    testWidgets('loading por defecto es un CircularProgressIndicator',
        (tester) async {
      final service = FakeCameraService(initialState: CameraState.initializing);
      await tester.pumpWidget(_wrap(CameraStateBuilder(
        controller: service,
        ready: (_) => const Text('READY'),
      )));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await service.dispose();
    });
  });

  group('CameraCaptureButton', () {
    testWidgets('habilitado en ready dispara y entrega el resultado',
        (tester) async {
      final service = FakeCameraService();
      CaptureResult? captured;
      await tester.pumpWidget(_wrap(CameraCaptureButton(
        controller: service,
        onCaptured: (r) => captured = r,
      )));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(service.takePictureCalls, 1);
      expect(captured, isNotNull);
      await service.dispose();
    });

    testWidgets('deshabilitado fuera de ready no dispara', (tester) async {
      final service = FakeCameraService(initialState: CameraState.initializing);
      await tester.pumpWidget(_wrap(CameraCaptureButton(
        controller: service,
        onCaptured: (_) {},
      )));

      final fab = tester.widget<FloatingActionButton>(
          find.byType(FloatingActionButton));
      expect(fab.onPressed, isNull);
      expect(service.takePictureCalls, 0);
      await service.dispose();
    });

    testWidgets('entrega el error por onError sin romper', (tester) async {
      final service = FakeCameraService()..throwOnTakePicture = true;
      CameraException? error;
      await tester.pumpWidget(_wrap(CameraCaptureButton(
        controller: service,
        onCaptured: (_) {},
        onError: (e) => error = e,
      )));

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      expect(error, isNotNull);
      expect(error!.type, CameraErrorType.captureFailed);
      await service.dispose();
    });
  });

  group('CameraFlashButton', () {
    testWidgets('cicla los modos y aplica al servicio', (tester) async {
      final service = FakeCameraService();
      await tester.pumpWidget(_wrap(CameraFlashButton(controller: service)));

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(service.flashCalls, [FlashMode.auto]);

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(service.flashCalls, [FlashMode.auto, FlashMode.on]);
      await service.dispose();
    });

    testWidgets('deshabilitado fuera de ready', (tester) async {
      final service = FakeCameraService(initialState: CameraState.error);
      await tester.pumpWidget(_wrap(CameraFlashButton(controller: service)));
      final btn = tester.widget<IconButton>(find.byType(IconButton));
      expect(btn.onPressed, isNull);
      await service.dispose();
    });
  });

  group('CameraSwitchButton', () {
    testWidgets('alterna la cámara en ready', (tester) async {
      final service = FakeCameraService();
      await tester.pumpWidget(_wrap(CameraSwitchButton(controller: service)));
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(service.switchCalls, 1);
      await service.dispose();
    });
  });

  group('CameraZoomControl', () {
    testWidgets('muestra slider en ready y aplica zoom', (tester) async {
      final service = FakeCameraService();
      await tester.pumpWidget(_wrap(CameraZoomControl(controller: service)));

      expect(find.byType(Slider), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(3.0);
      await tester.pump();
      // latest-wins: al menos el último valor llega al servicio.
      await tester.pump(const Duration(milliseconds: 10));
      expect(service.zoomCalls, contains(3.0));
      await service.dispose();
    });

    testWidgets('se oculta si no soporta zoom', (tester) async {
      final service = FakeCameraService(
        capabilities: const CameraCapabilities(
          minZoom: 1.0,
          maxZoom: 1.0,
          minExposureOffset: 0,
          maxExposureOffset: 0,
          exposureStepSize: 0,
          supportedResolutions: [ResolutionPreset.high],
          supportedFlashModes: [FlashMode.off],
          supportedFocusModes: [FocusMode.auto],
          supportsExposureControl: false,
          supportsFocusControl: false,
          supportsZoom: false,
        ),
      );
      await tester.pumpWidget(_wrap(CameraZoomControl(controller: service)));
      expect(find.byType(Slider), findsNothing);
      await service.dispose();
    });
  });

  group('CameraFocusGesture', () {
    testWidgets('convierte el tap a coordenadas normalizadas', (tester) async {
      final service = FakeCameraService();
      Offset? reported;
      await tester.pumpWidget(_wrap(SizedBox(
        width: 200,
        height: 200,
        child: CameraFocusGesture(
          controller: service,
          onFocusRequested: (p) => reported = p,
          child: const SizedBox.expand(),
        ),
      )));

      await tester.tapAt(const Offset(100, 100)); // centro aproximado
      await tester.pump();

      expect(reported, isNotNull);
      expect(service.focusPointCalls, isNotEmpty);
      expect(service.focusPointCalls.last!.dx, closeTo(0.5, 0.1));
      await service.dispose();
    });
  });

  group('CameraView (nivel 3, conveniencia)', () {
    testWidgets('compone preview + overlay + controls sin flags',
        (tester) async {
      final service = FakeCameraService();
      await tester.pumpWidget(_wrap(CameraView(
        controller: service,
        overlay: const Text('ov'),
        controlsBuilder: (_) => const Text('ctrls'),
      )));

      expect(find.byKey(const Key('fake-preview')), findsOneWidget);
      expect(find.text('ov'), findsOneWidget);
      expect(find.text('ctrls'), findsOneWidget);
      await service.dispose();
    });

    testWidgets('sin overlay ni controls devuelve solo el preview',
        (tester) async {
      final service = FakeCameraService();
      await tester.pumpWidget(_wrap(CameraView(controller: service)));
      expect(find.byKey(const Key('fake-preview')), findsOneWidget);
      await service.dispose();
    });

    testWidgets('muestra loading por defecto fuera de ready', (tester) async {
      final service = FakeCameraService(initialState: CameraState.initializing);
      await tester.pumpWidget(_wrap(CameraView(controller: service)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await service.dispose();
    });
  });
}
