import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/oracles/generate_engine_v1_fixtures.dart';

const _fixtureRoot = 'test/fixtures/source-calculator-v1';
const _fixtureSetId = 'source-calculator-v1';
const _sourceArchiveSha256 =
    '6f9b3613d0ecc6a0ff18837308f74aecc4e9cf4f5cee0201de595152a404583f';

void main() {
  final root = Directory(_fixtureRoot);

  test('source calculator documents and manifest are complete', () {
    expect(root.existsSync(), isTrue);
    final manifest = _readObject(root, 'manifest.json');
    expect(manifest['fixtureSetId'], _fixtureSetId);
    expect(manifest['immutable'], isTrue);

    final listedFiles = _strings(manifest['files'], r'$.files');
    expect(listedFiles.toSet(), hasLength(listedFiles.length));
    final actualJsonFiles = _relativeFiles(
      root,
    ).where((path) => path.endsWith('.json')).toSet();
    expect(listedFiles.toSet(), actualJsonFiles);

    for (final path in listedFiles) {
      _expectSafeRelativePath(path);
      final document = _readObject(root, path);
      if (path.startsWith('schemas/')) {
        expect(
          document[r'$schema'],
          'https://json-schema.org/draft/2020-12/schema',
          reason: path,
        );
        expect(document[r'$id'], isNotEmpty, reason: path);
      } else {
        expect(document['schemaVersion'], 1, reason: path);
        final schemaPath =
            'schemas/${path.split('/').last.replaceFirst('.json', '.schema.json')}';
        expect(document[r'$schema'], schemaPath, reason: path);
        expect(actualJsonFiles, contains(schemaPath), reason: path);
      }
    }
  });

  test('raw-byte checksums protect every source evidence document', () {
    final checksums = _readObject(root, 'checksums.json');
    expect(checksums['algorithm'], 'sha256');
    final sourceArchive = _object(
      checksums['sourceArchive'],
      r'$.sourceArchive',
    );
    expect(sourceArchive['sizeBytes'], 5737984);
    expect(sourceArchive['sha256'], _sourceArchiveSha256);

    final provenance = _readObject(root, 'provenance.json');
    expect(
      _object(
        provenance['sourceArchive'],
        r'provenance.$.sourceArchive',
      )['sha256'],
      _sourceArchiveSha256,
    );

    final byPath = <String, String>{};
    for (final entry in _objects(checksums['files'], r'$.files')) {
      final path = _requiredString(entry, 'path');
      final digest = _requiredString(entry, 'sha256');
      _expectSafeRelativePath(path);
      expect(digest, matches(RegExp(r'^[0-9a-f]{64}$')), reason: path);
      expect(byPath.containsKey(path), isFalse, reason: 'duplicate: $path');
      byPath[path] = digest;
    }

    final expectedPaths = _relativeFiles(root)
        .where(
          (path) =>
              path.endsWith('.json') &&
              !path.startsWith('schemas/') &&
              path != 'manifest.json' &&
              path != 'checksums.json',
        )
        .toSet();
    expect(byPath.keys.toSet(), expectedPaths);
    for (final entry in byPath.entries) {
      expect(
        sha256.convert(_file(root, entry.key).readAsBytesSync()).toString(),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('every declared control value and anomaly is accounted for', () {
    final controls = _objects(
      _readObject(root, 'controls.json')['controls'],
      r'controls.$.controls',
    );
    final coverage = _readObject(root, 'coverage.json');
    final observations = _objects(
      _readObject(root, 'observations.json')['observations'],
      r'observations.$.observations',
    );
    final anomalies = _objects(
      _readObject(root, 'anomalies.json')['anomalies'],
      r'anomalies.$.anomalies',
    );

    final observationIds = <String>{};
    for (final observation in observations) {
      expect(observationIds.add(_requiredString(observation, 'id')), isTrue);
      expect({
        'exactGolden',
        'documented',
        'partialExact',
        'pendingExactCapture',
        'intentionalDivergence',
      }, contains(_requiredString(observation, 'captureStatus')));
    }
    expect(
      observations.singleWhere(
        (item) => item['id'] == 'OBS-STATIC-INVENTORY',
      )['coversAllDeclaredControlValues'],
      isTrue,
    );

    final declaredValues = <String, Set<String>>{};
    for (final control in controls) {
      final id = _requiredString(control, 'id');
      expect(declaredValues.containsKey(id), isFalse, reason: id);
      final values = {
        for (final value in _objects(control['values'], '$id.values'))
          _requiredString(value, 'id'),
      };
      expect(values, isNotEmpty, reason: id);
      declaredValues[id] = values;
    }

    final coveredIds = <String>{};
    for (final item in _objects(coverage['controls'], r'$.controls')) {
      final id = _requiredString(item, 'controlId');
      expect(coveredIds.add(id), isTrue, reason: id);
      expect(
        _strings(item['coveredValueIds'], '$id.coveredValueIds').toSet(),
        declaredValues[id],
        reason: id,
      );
      expect(
        observationIds,
        containsAll(_strings(item['observationIds'], '$id.observationIds')),
      );
    }
    expect(coveredIds, declaredValues.keys.toSet());

    for (final observation in observations) {
      for (final reference in _objects(
        observation['controlValues'] ?? const <Object?>[],
        '${observation['id']}.controlValues',
      )) {
        final controlId = _requiredString(reference, 'controlId');
        final valueId = _requiredString(reference, 'valueId');
        expect(declaredValues[controlId], contains(valueId));
      }
    }

    final anomalyIds = <String>{};
    for (final anomaly in anomalies) {
      final id = _requiredString(anomaly, 'id');
      expect(anomalyIds.add(id), isTrue, reason: id);
      expect({
        'mustMatch',
        'needsDecision',
        'pendingExactCapture',
        'intentionalDivergence',
      }, contains(_requiredString(anomaly, 'targetDisposition')));
    }
    expect(anomalyIds, {
      for (var index = 1; index <= 13; index++)
        'SRC-${index.toString().padLeft(3, '0')}',
    });
    final coveredAnomalies = <String>{};
    for (final item in _objects(coverage['anomalies'], r'$.anomalies')) {
      final id = _requiredString(item, 'anomalyId');
      expect(coveredAnomalies.add(id), isTrue, reason: id);
      expect(
        observationIds,
        containsAll(_strings(item['observationIds'], '$id.observationIds')),
      );
    }
    expect(coveredAnomalies, anomalyIds);

    for (final observation in observations) {
      for (final anomalyId in _strings(
        observation['anomalyIds'] ?? const <Object?>[],
        '${observation['id']}.anomalyIds',
      )) {
        expect(anomalyIds, contains(anomalyId));
      }
    }
  });

  test('exact-golden metadata references the complete frozen matrix', () {
    final exactGoldens = _readObject(root, 'exact-goldens.json');
    final scenarios = _objects(
      exactGoldens['scenarios'],
      r'exactGoldens.$.scenarios',
    );
    final scenarioIds = {
      for (final scenario in scenarios) _requiredString(scenario, 'id'),
    };
    expect(exactGoldens['scenarioCount'], 35);
    expect(scenarioIds, hasLength(35));

    final manifest = _readObject(root, 'manifest.json');
    expect(
      _object(
        manifest['exactGoldenMatrix'],
        r'manifest.$.exactGoldenMatrix',
      )['scenarioCount'],
      scenarios.length,
    );
    final provenance = _readObject(root, 'provenance.json');
    expect(
      _object(
        provenance['exactGoldenCapture'],
        r'provenance.$.exactGoldenCapture',
      )['scenarioCount'],
      scenarios.length,
    );

    final coverage = _readObject(root, 'coverage.json');
    for (final item in _objects(
      coverage['acceptanceMatrix'],
      r'coverage.$.acceptanceMatrix',
    )) {
      if (item['captureStatus'] != 'exactGolden') continue;
      final references = _strings(
        item['goldenScenarioIds'],
        '${item['id']}.goldenScenarioIds',
      );
      expect(references, isNotEmpty, reason: item['id'] as String);
      expect(
        scenarioIds,
        containsAll(references),
        reason: item['id'] as String,
      );
    }

    const standaloneTwoDays = {
      'two-day-option-one-deload',
      'two-day-option-one-no-deload',
      'two-day-option-two-deload',
      'two-day-option-two-no-deload',
      'two-day-option-three-profile-65-75-85',
      'two-day-option-three-profile-70-80-90',
      'two-day-option-three-profile-75-85-95',
      'two-day-option-three-profile-80-90-100',
      'two-day-option-three-no-deload',
      'two-day-option-one-reordered-pairs',
      'two-day-option-three-reordered-lifts',
      'two-day-option-one-warmup-joker',
      'two-day-option-three-deload-two',
    };
    expect(scenarioIds, containsAll(standaloneTwoDays));

    final optionOne = _objects(
      _readObject(root, 'observations.json')['observations'],
      r'observations.$.observations',
    ).singleWhere((item) => item['id'] == 'OBS-STANDALONE-TWO-DAYS-OPTION-ONE');
    expect(optionOne['captureStatus'], 'exactGolden');
    expect(
      _strings(
        _object(
          optionOne['expected'],
          r'optionOne.$.expected',
        )['week1FirstSessionAssistance'],
        r'optionOne.$.expected.week1FirstSessionAssistance',
      ),
      contains('bicepCurl 3x10'),
    );
  });

  test(
    'engine-v1 fixture generation is technically barred from this oracle',
    () async {
      final manifest = _readObject(root, 'manifest.json');
      expect(
        _object(
          manifest['authorityBoundary'],
          r'$.authorityBoundary',
        )['engineV1Generator'],
        'forbidden',
      );
      final provenance = _readObject(root, 'provenance.json');
      expect(
        _object(
          provenance['capture'],
          r'$.capture',
        )['generatedByHybridTraining'],
        isFalse,
      );

      await expectLater(
        generateEngineV1Fixtures(root),
        throwsA(isA<StateError>()),
      );
    },
  );
}

List<String> _relativeFiles(Directory root) {
  final result =
      root
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .map(
            (file) =>
                file.path.substring(root.path.length + 1).replaceAll(r'\', '/'),
          )
          .toList()
        ..sort();
  return result;
}

File _file(Directory root, String relativePath) => File(
  <String>[root.path, ...relativePath.split('/')].join(Platform.pathSeparator),
);

Map<String, Object?> _readObject(Directory root, String relativePath) {
  final value = jsonDecode(_file(root, relativePath).readAsStringSync());
  return _object(value, relativePath);
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map) {
    throw TestFailure('$path must be a JSON object');
  }
  return value.cast<String, Object?>();
}

List<Map<String, Object?>> _objects(Object? value, String path) {
  if (value is! List) {
    throw TestFailure('$path must be a JSON array');
  }
  return [
    for (var index = 0; index < value.length; index++)
      _object(value[index], '$path[$index]'),
  ];
}

List<String> _strings(Object? value, String path) {
  if (value is! List || value.any((item) => item is! String)) {
    throw TestFailure('$path must be an array of strings');
  }
  return value.cast<String>();
}

String _requiredString(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! String || result.isEmpty) {
    throw TestFailure('$key must be a non-empty string');
  }
  return result;
}

void _expectSafeRelativePath(String path) {
  expect(path, isNotEmpty);
  expect(path, isNot(startsWith('/')));
  expect(path, isNot(contains(r'\')));
  expect(path, isNot(contains(':')));
  for (final segment in path.split('/')) {
    expect(segment, isNot(anyOf('', '.', '..')), reason: path);
  }
}
