import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_test/flutter_test.dart';

import 'package:camera_core/src/infrastructure/rotation_utils.dart';

void main() {
  group('deviceOrientationToDegrees', () {
    test('portraitUp -> 0', () {
      expect(deviceOrientationToDegrees(DeviceOrientation.portraitUp), 0);
    });

    test('portraitDown -> 180', () {
      expect(deviceOrientationToDegrees(DeviceOrientation.portraitDown), 180);
    });

    test('landscapeLeft -> 90', () {
      expect(deviceOrientationToDegrees(DeviceOrientation.landscapeLeft), 90);
    });

    test('landscapeRight -> 270', () {
      expect(deviceOrientationToDegrees(DeviceOrientation.landscapeRight), 270);
    });

    test('null -> null', () {
      expect(deviceOrientationToDegrees(null), isNull);
    });
  });

  group('computeRotationDegrees - Android, cámara trasera', () {
    test('sensor=0, device=0 (portrait) -> 0', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: 0,
          isAndroid: true,
          isFrontCamera: false,
        ),
        0,
      );
    });

    test('sensor=90, device=0 (portrait) -> 90', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 90,
          deviceOrientationDegrees: 0,
          isAndroid: true,
          isFrontCamera: false,
        ),
        90,
      );
    });

    test('sensor=0, device=90 (landscapeLeft) -> 270', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: 90,
          isAndroid: true,
          isFrontCamera: false,
        ),
        270,
      );
    });

    test('sensor=0, device=270 (landscapeRight) -> 90', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: 270,
          isAndroid: true,
          isFrontCamera: false,
        ),
        90,
      );
    });

    test('sensor=0, device=180 (portraitDown) -> 180', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: 180,
          isAndroid: true,
          isFrontCamera: false,
        ),
        180,
      );
    });

    test('deviceOrientation null -> null', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: null,
          isAndroid: true,
          isFrontCamera: false,
        ),
        isNull,
      );
    });
  });

  group('computeRotationDegrees - Android, cámara frontal', () {
    test('sensor=0, device=0 (portrait) -> 270', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: 0,
          isAndroid: true,
          isFrontCamera: true,
        ),
        270,
      );
    });

    test('sensor=0, device=90 (landscapeLeft) -> 0', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: 90,
          isAndroid: true,
          isFrontCamera: true,
        ),
        0,
      );
    });

    test('sensor=0, device=270 (landscapeRight) -> 180', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: 270,
          isAndroid: true,
          isFrontCamera: true,
        ),
        180,
      );
    });

    test('sensor=90, device=0 (portrait) -> 0', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 90,
          deviceOrientationDegrees: 0,
          isAndroid: true,
          isFrontCamera: true,
        ),
        0,
      );
    });
  });

  group('computeRotationDegrees - iOS', () {
    test('device=0 (portrait) -> 0', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: 0,
          isAndroid: false,
          isFrontCamera: false,
        ),
        0,
      );
    });

    test('device=90 (landscapeLeft) -> 90', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: 90,
          isAndroid: false,
          isFrontCamera: false,
        ),
        90,
      );
    });

    test('device=180 (portraitDown) -> 180', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: 180,
          isAndroid: false,
          isFrontCamera: false,
        ),
        180,
      );
    });

    test('device=270 (landscapeRight) -> 270', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: 270,
          isAndroid: false,
          isFrontCamera: false,
        ),
        270,
      );
    });

    test('deviceOrientation null -> null', () {
      expect(
        computeRotationDegrees(
          sensorOrientation: 0,
          deviceOrientationDegrees: null,
          isAndroid: false,
          isFrontCamera: false,
        ),
        isNull,
      );
    });
  });
}
