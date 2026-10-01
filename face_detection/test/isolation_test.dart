import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dartFiles(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

List<String> _importLines(File f) => f
    .readAsLinesSync()
    .where((l) => l.trimLeft().startsWith('import '))
    .toList();

/// Invariantes de aislamiento de `face_detection`.
void main() {
  group('Aislamiento de ML Kit', () {
    test('google_mlkit_* solo se importa en el adaptador', () {
      final offenders = <String>[];
      for (final file in _dartFiles('lib')) {
        if (_importLines(file).any((l) => l.contains('google_mlkit_'))) {
          final normalized = file.path.replaceAll(r'\', '/');
          if (!normalized
              .endsWith('src/infrastructure/mlkit_face_adapter.dart')) {
            offenders.add(normalized);
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'ML Kit debe estar confinado en el adaptador. '
              'Infractores: $offenders');
    });
  });

  group('No se expone package:camera', () {
    test('ningún archivo del paquete importa package:camera', () {
      final offenders = <String>[];
      for (final file in _dartFiles('lib')) {
        if (_importLines(file).any((l) => l.contains('package:camera/'))) {
          offenders.add(file.path.replaceAll(r'\', '/'));
        }
      }
      expect(offenders, isEmpty,
          reason: 'face_detection no debe importar package:camera directamente '
              '(usa camera_core). Infractores: $offenders');
    });
  });

  group('El barrel público no filtra tipos de ML Kit ni del plugin camera', () {
    test('face_detection.dart no re-exporta google_mlkit_* ni package:camera',
        () {
      final exportLines = File('lib/face_detection.dart')
          .readAsLinesSync()
          .where((l) => l.trimLeft().startsWith('export '))
          .toList();
      final offenders = exportLines
          .where((l) =>
              l.contains('google_mlkit_') || l.contains('package:camera/'))
          .toList();
      expect(offenders, isEmpty,
          reason: 'El barrel no debe exportar ML Kit ni package:camera: '
              '$offenders');
    });
  });

  group('Dependencia unidireccional (camera_core NO conoce face_detection)', () {
    test('camera_core no importa face_detection', () {
      final cameraCoreLib = Directory('../camera_core/lib');
      if (!cameraCoreLib.existsSync()) return;
      final offenders = <String>[];
      for (final file in _dartFiles(cameraCoreLib.path)) {
        if (_importLines(file).any((l) => l.contains('face_detection'))) {
          offenders.add(file.path.replaceAll(r'\', '/'));
        }
      }
      expect(offenders, isEmpty,
          reason: 'camera_core NO debe depender de face_detection. '
              'Infractores: $offenders');
    });
  });
}
