import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/oracles/generate_engine_v1_fixtures.dart';

void main() {
  test(
    'engine v1 fixtures are deterministic and cover the published catalog',
    () async {
      final temporary = Directory.systemTemp.createTempSync(
        'engine_v1_fixture_test_',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      await generateEngineV1Fixtures(temporary);

      final checkedIn = Directory('test/fixtures/engine-v1');
      final expectedFiles = _relativeJsonFiles(checkedIn);
      final actualFiles = _relativeJsonFiles(temporary);
      expect(actualFiles, orderedEquals(expectedFiles));
      for (final path in expectedFiles) {
        expect(
          jsonDecode(File('${temporary.path}/$path').readAsStringSync()),
          jsonDecode(File('${checkedIn.path}/$path').readAsStringSync()),
          reason: path,
        );
      }

      final manifest = _json('${checkedIn.path}/manifest.json');
      expect(manifest['fixtureVersion'], 1);
      expect(manifest['catalogVersion'], 2);
      expect(manifest['cycleVariantCount'], 23);
      expect(manifest['cycleFixtures'], hasLength(23));
      expect(manifest['errorFixtures'], hasLength(3));
      expect(manifest['foreverFixtures'], hasLength(1));

      final modes = <String>{};
      final units = <String>{};
      var hasMovementRatio = false;
      var hasDeload = false;
      var omitsDeload = false;
      for (final path in expectedFiles.where(
        (path) => path.startsWith('cycle/'),
      )) {
        final fixture = _json('${checkedIn.path}/$path');
        final response = (fixture['response']! as Map).cast<String, Object?>();
        final snapshot = (fixture['snapshot']! as Map).cast<String, Object?>();
        expect(snapshot, response);
        expect(fixture['logicalHash'], logicalHash(snapshot));
        expect((response['weeks']! as List), isNotEmpty);
        final coverage = (fixture['coverage']! as Map).cast<String, Object?>();
        modes.addAll((coverage['maxInputModes']! as List).cast<String>());
        units.add(coverage['unit']! as String);
        hasMovementRatio |= coverage['perMovementRatio']! as bool;
        hasDeload |= coverage['includeDeload']! as bool;
        omitsDeload |= !(coverage['includeDeload']! as bool);
        expect(coverage['schedule'], isTrue);
        expect(coverage['plating'], isTrue);
        expect(coverage['catalogOptions'], isTrue);
      }
      expect(modes, equals({'oneRepMax', 'repMax', 'directTrainingMax'}));
      expect(units, equals({'kg', 'lb'}));
      expect(hasMovementRatio, isTrue);
      expect(hasDeload, isTrue);
      expect(omitsDeload, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

List<String> _relativeJsonFiles(Directory root) {
  final paths =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .map(
            (file) =>
                file.path.substring(root.path.length + 1).replaceAll('\\', '/'),
          )
          .toList()
        ..sort();
  return paths;
}

Map<String, Object?> _json(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();
