import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Recolecta recursivamente todos los .dart bajo un directorio.
List<File> _dartFiles(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Invariante arquitectónico de `camera_core` (adaptado del test de aislamiento
/// de CAPPFRONT, conservando solo el grupo que aplica al paquete).
///
/// Los grupos de ML Kit y de "realtime simulada" NO se portan: verifican
/// invariantes de la app, no del core (ML Kit y realtime quedan fuera del
/// paquete por diseño).
void main() {
  group('Aislamiento de package:camera', () {
    test('package:camera solo se importa en camera_controller_wrapper', () {
      final offenders = <String>[];
      for (final file in _dartFiles('lib')) {
        final content = file.readAsStringSync();
        if (content.contains('package:camera/')) {
          final normalized = file.path.replaceAll(r'\', '/');
          if (!normalized
              .endsWith('src/infrastructure/camera_controller_wrapper.dart')) {
            offenders.add(normalized);
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'package:camera debe estar solo en el wrapper. '
              'Archivos infractores: $offenders');
    });

    test('ningún archivo del core importa ML Kit', () {
      final offenders = <String>[];
      for (final file in _dartFiles('lib')) {
        final content = file.readAsStringSync();
        if (content.contains('package:google_mlkit_')) {
          offenders.add(file.path.replaceAll(r'\', '/'));
        }
      }
      expect(offenders, isEmpty,
          reason: 'camera_core NO debe conocer ML Kit. Infractores: $offenders');
    });

    test('ningún archivo del core importa casos de uso de visión', () {
      const forbidden = [
        'face_detection',
        'face_recognition',
        'barcode',
        'document_scanner',
        'realtime_params',
      ];
      final offenders = <String>[];
      for (final file in _dartFiles('lib')) {
        // Revisar únicamente las líneas de import, no comentarios/docs.
        final importLines = file
            .readAsLinesSync()
            .where((l) => l.trimLeft().startsWith('import '))
            .map((l) => l.toLowerCase());
        for (final line in importLines) {
          for (final symbol in forbidden) {
            if (line.contains(symbol)) {
              offenders.add('${file.path.replaceAll(r'\', '/')} → $symbol');
            }
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'camera_core no debe depender de capacidades de visión: '
              '$offenders');
    });
  });

  group('Capas de UI', () {
    test('los widgets dependen del contrato/modelos, no de infraestructura', () {
      // Los primitivos de UI (preview, state builder, view, controles) deben
      // consumir solo ICameraService y modelos públicos; nunca el wrapper, el
      // permission handler ni la impl concreta del servicio.
      const forbiddenInfra = [
        'camera_controller_wrapper',
        'camera_permission_handler',
        'camera_service_impl',
      ];
      final offenders = <String>[];
      for (final file in _dartFiles('lib/src/widgets')) {
        final importLines = file
            .readAsLinesSync()
            .where((l) => l.trimLeft().startsWith('import '))
            .map((l) => l.toLowerCase());
        for (final line in importLines) {
          for (final symbol in forbiddenInfra) {
            if (line.contains(symbol)) {
              offenders.add('${file.path.replaceAll(r'\', '/')} → $symbol');
            }
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'La UI no debe acoplarse a la infraestructura interna: '
              '$offenders');
    });
  });
}
