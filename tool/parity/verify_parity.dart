import 'dart:convert';
import 'dart:io';

import 'package:training_engine_web_bridge/training_engine_web_bridge.dart';
import '../oracles/generate_engine_v1_fixtures.dart';

Future<void> main(List<String> arguments) async {
  final fixtures = Directory('test/fixtures/engine-v1');
  final nativeOutput = Directory.systemTemp.createTempSync('parity_native_');
  final report = <String, Object?>{
    'cycleParityFailures': <Object?>[],
    'foreverParityFailures': <Object?>[],
    'contractFailures': <Object?>[],
    'coverage': <String, Object?>{},
    'runners': <String, Object?>{},
  };
  try {
    await generateEngineV1Fixtures(nativeOutput);
    final contractFailures = report['contractFailures']! as List<Object?>;
    final cycleFailures = report['cycleParityFailures']! as List<Object?>;
    final foreverFailures = report['foreverParityFailures']! as List<Object?>;
    _validateContracts(fixtures, contractFailures);
    final manifest = _readJson(File('${fixtures.path}/manifest.json'));
    final cycleFixtures = (manifest['cycleFixtures'] as List).cast<String>();
    report['coverage'] = {
      'publicCycleVariantCount': cycleFixtures.length,
      'publicCycleVariants': cycleFixtures,
      'nativeDartCompared': cycleFixtures.length,
      'bridgeJavaScriptCompared': 0,
      'foreverScenariosCompared': _files(fixtures, 'forever/').length,
    };
    _compareFixtureTrees(
      fixtures,
      nativeOutput,
      prefix: 'cycle/',
      failures: cycleFailures,
    );
    _compareFixtureTrees(
      fixtures,
      nativeOutput,
      prefix: 'forever/',
      failures: foreverFailures,
    );
    (report['runners']! as Map<String, Object?>)['nativeDart'] = {
      'status': cycleFailures.isEmpty && foreverFailures.isEmpty
          ? 'passed'
          : 'failed',
      'cycleFixtureCount': _files(fixtures, 'cycle/').length,
      'foreverFixtureCount': _files(fixtures, 'forever/').length,
    };

    final bridgeReport = await _runBridge(fixtures);
    (report['runners']! as Map<String, Object?>)['bridgeJavaScript'] =
        bridgeReport;
    (report['coverage']! as Map<String, Object?>)['bridgeJavaScriptCompared'] =
        bridgeReport['cycleFixtureCount'] ?? 0;
    if (bridgeReport['status'] == 'failed') {
      cycleFailures.addAll(
        (bridgeReport['cycleParityFailures'] as List<Object?>?) ?? const [],
      );
      foreverFailures.addAll(
        (bridgeReport['foreverParityFailures'] as List<Object?>?) ?? const [],
      );
      contractFailures.addAll(
        (bridgeReport['contractFailures'] as List<Object?>?) ?? const [],
      );
    }
  } catch (error, stackTrace) {
    (report['contractFailures']! as List<Object?>).add({
      'fixture': r'$',
      'message': '$error',
      'stackTrace': '$stackTrace',
    });
  } finally {
    if (nativeOutput.existsSync()) nativeOutput.deleteSync(recursive: true);
  }

  final failed = [
    report['cycleParityFailures']! as List,
    report['foreverParityFailures']! as List,
    report['contractFailures']! as List,
  ].any((failures) => failures.isNotEmpty);
  final skipped = (report['runners']! as Map<String, Object?>).values.any(
    (runner) => runner is Map && runner['status'] == 'skipped',
  );
  report['status'] = failed ? 'failed' : (skipped ? 'partial' : 'passed');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  if (failed || skipped) exitCode = 1;
}

void _validateContracts(Directory root, List<Object?> failures) {
  final manifest = _readJson(File('${root.path}/manifest.json'));
  final declaredFixtures =
      (manifest['cycleFixtures'] as List?)?.cast<String>() ?? const <String>[];
  final fixtureFiles = _files(root, 'cycle/')
      .map(
        (path) => path.substring('cycle/'.length, path.length - '.json'.length),
      )
      .toList();
  if (manifest['fixtureVersion'] != 1) {
    failures.add({
      'fixture': 'manifest.json',
      'message': 'Expected fixtureVersion 1.',
    });
  }
  if (manifest['cycleVariantCount'] != declaredFixtures.length) {
    failures.add({
      'fixture': 'manifest.json',
      'message': 'cycleVariantCount does not match cycleFixtures.',
      'declaredCount': manifest['cycleVariantCount'],
      'fixtureCount': declaredFixtures.length,
    });
  }
  if (declaredFixtures.toSet().length != declaredFixtures.length) {
    failures.add({
      'fixture': 'manifest.json',
      'message': 'cycleFixtures contains duplicate public variant ids.',
    });
  }
  if (_canonicalJson(declaredFixtures..sort()) !=
      _canonicalJson(fixtureFiles..sort())) {
    failures.add({
      'fixture': 'manifest.json',
      'message':
          'cycleFixtures does not exhaustively match the checked-in Cycle fixtures.',
      'declared': declaredFixtures,
      'files': fixtureFiles,
    });
  }
  for (final relative in _files(root, 'cycle/')) {
    final fixture = _readJson(File('${root.path}/$relative'));
    final response = fixture['response'];
    final snapshot = fixture['snapshot'];
    if (_canonicalJson(response) != _canonicalJson(snapshot)) {
      failures.add({
        'fixture': relative,
        'message': 'response and snapshot differ canonically',
      });
    }
    if (fixture['logicalHash'] != logicalHash(snapshot)) {
      failures.add({
        'fixture': relative,
        'message': 'logicalHash does not match the canonical snapshot',
      });
    }
  }
}

void _compareFixtureTrees(
  Directory expected,
  Directory actual, {
  required String prefix,
  required List<Object?> failures,
}) {
  final expectedFiles = _files(expected, prefix);
  final actualFiles = _files(actual, prefix);
  if (_canonicalJson(expectedFiles) != _canonicalJson(actualFiles)) {
    failures.add({
      'fixture': prefix,
      'message': 'native runner produced a different fixture inventory',
      'expected': expectedFiles,
      'actual': actualFiles,
    });
    return;
  }
  for (final relative in expectedFiles) {
    final left = _readJson(File('${expected.path}/$relative'));
    final right = _readJson(File('${actual.path}/$relative'));
    if (_canonicalJson(left) != _canonicalJson(right)) {
      failures.add({
        'fixture': relative,
        'message': 'native Dart output differs from the checked-in oracle',
      });
    }
  }
}

Future<Map<String, Object?>> _runBridge(Directory fixtures) async {
  final runner = File('tool/parity/bridge_runner.mjs');
  final nativeCycleCorpus = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}hybrid_cycle_bridge_corpus_${DateTime.now().microsecondsSinceEpoch}.json',
  );
  final nativeForever = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}hybrid_forever_native_${DateTime.now().microsecondsSinceEpoch}.json',
  );
  final corpusFailures = <Object?>[];
  late final ProcessResult result;
  try {
    final service = BridgeService(LocalTrainingEngineBindings());
    service.initialize(
      File('apps/web_generator/public/catalog.bundle.json').readAsStringSync(),
    );
    final corpus = _buildBridgeCorpus(fixtures, service, corpusFailures);
    nativeCycleCorpus.writeAsStringSync(jsonEncode(corpus));
    nativeForever.writeAsStringSync(
      service.generateMacrocycle(
        File(
          'contracts/v1/fixtures/forever_request.valid.json',
        ).readAsStringSync(),
      ),
    );
    result = await Process.run(Platform.isWindows ? 'node.exe' : 'node', [
      runner.path,
      fixtures.path,
      nativeCycleCorpus.path,
      nativeForever.path,
    ]);
  } on ProcessException catch (error) {
    return {
      'status': 'skipped',
      'reason':
          'Node.js is unavailable (${error.message}); bridge parity was not simulated.',
    };
  } catch (error, stackTrace) {
    return {
      'status': 'failed',
      'contractFailures': [
        ...corpusFailures,
        {
          'fixture': r'$',
          'message': 'Unable to prepare bridge parity corpus: $error',
          'stackTrace': '$stackTrace',
        },
      ],
    };
  } finally {
    if (nativeCycleCorpus.existsSync()) nativeCycleCorpus.deleteSync();
    if (nativeForever.existsSync()) nativeForever.deleteSync();
  }
  final output = '${result.stdout}'.trim();
  if (output.isEmpty) {
    return {
      'status': 'failed',
      'contractFailures': [
        ...corpusFailures,
        {
          'fixture': r'$',
          'message': 'Bridge runner returned no JSON: ${result.stderr}',
        },
      ],
    };
  }
  try {
    final decoded = jsonDecode(output);
    if (decoded is! Map) throw const FormatException('report is not an object');
    final bridgeReport = decoded.cast<String, Object?>();
    if (corpusFailures.isNotEmpty) {
      final failures =
          (bridgeReport['contractFailures'] as List<Object?>?) ?? <Object?>[];
      bridgeReport['contractFailures'] = [...corpusFailures, ...failures];
      bridgeReport['status'] = 'failed';
    }
    return bridgeReport;
  } catch (error) {
    return {
      'status': 'failed',
      'contractFailures': [
        ...corpusFailures,
        {
          'fixture': r'$',
          'message': 'Invalid bridge runner report: $error',
          'stdout': output,
          'stderr': '${result.stderr}',
        },
      ],
    };
  }
}

Map<String, Object?> _buildBridgeCorpus(
  Directory fixtures,
  BridgeService service,
  List<Object?> failures,
) {
  final manifest = _readJson(File('${fixtures.path}/manifest.json'));
  final ids = (manifest['cycleFixtures'] as List).cast<String>();
  final cases = <Map<String, Object?>>[];
  for (final id in ids) {
    try {
      final fixture = _readJson(File('${fixtures.path}/cycle/$id.json'));
      final selection = (fixture['catalogSelection'] as Map)
          .cast<String, Object?>();
      final templateId = selection['templateId']! as String;
      final variantId = selection['variantId']! as String;
      final validExample =
          (selection['validExample'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      final allowedScheduleIds =
          (selection['allowedScheduleIds'] as List?)?.cast<String>() ??
          const <String>[];
      final scheduleId =
          validExample['scheduleId'] as String? ??
          (allowedScheduleIds.isEmpty ? null : allowedScheduleIds.first);
      final schemaRequest = <String, Object?>{
        'apiVersion': 'v1',
        'schemaVersion': 1,
        'templateId': templateId,
        'variantId': variantId,
        'scheduleId': ?scheduleId,
      };
      final schema =
          (jsonDecode(service.cycleEditorSchema(jsonEncode(schemaRequest)))
                  as Map)
              .cast<String, Object?>();
      final fixtureRequest = (fixture['request'] as Map)
          .cast<String, Object?>();
      final request = _publicCycleRequest(
        id: id,
        fixtureRequest: fixtureRequest,
        templateId: templateId,
        variantId: variantId,
        scheduleId: scheduleId,
        schema: schema,
      );
      final validation =
          (jsonDecode(service.validateCycle(jsonEncode(request))) as Map)
              .cast<String, Object?>();
      if (validation['valid'] != true) {
        failures.add({
          'fixture': id,
          'message': 'Generated public Cycle request is not valid.',
          'errors': validation['errors'],
          'request': request,
        });
        continue;
      }
      final expected =
          (jsonDecode(service.generateCycle(jsonEncode(request))) as Map)
              .cast<String, Object?>();
      cases.add({'id': id, 'request': request, 'expected': expected});
    } catch (error, stackTrace) {
      failures.add({
        'fixture': id,
        'message': 'Failed to prepare public Cycle parity case: $error',
        'stackTrace': '$stackTrace',
      });
    }
  }
  return {
    'corpusVersion': 1,
    'sourceFixtureVersion': manifest['fixtureVersion'],
    'expectedCycleCaseCount': ids.length,
    'cycleCases': cases,
  };
}

Map<String, Object?> _publicCycleRequest({
  required String id,
  required Map<String, Object?> fixtureRequest,
  required String templateId,
  required String variantId,
  required String? scheduleId,
  required Map<String, Object?> schema,
}) {
  final request = <String, Object?>{
    'apiVersion': 'v1',
    'schemaVersion': 1,
    'cycleId': fixtureRequest['cycleId'] ?? 'parity-$id',
    'templateId': templateId,
    'variantId': variantId,
    'scheduleId': ?scheduleId,
    'startDate': fixtureRequest['startDate'] ?? '2026-01-05T00:00:00.000Z',
    'sessionOrder': (schema['sessionIds'] as List).cast<String>(),
    'maxInputs': _publicMaxInputs(fixtureRequest, schema),
    'globalTrainingMaxRatioBasisPoints':
        fixtureRequest['globalTrainingMaxRatioBasisPoints'] ?? 9000,
    'trainingMaxRatioByMovement':
        fixtureRequest['trainingMaxRatioByMovement'] ??
        fixtureRequest['trainingMaxRatioByMovementBasisPoints'] ??
        const <String, Object?>{},
    'percentageParameters':
        fixtureRequest['percentageParameters'] ?? const <String, Object?>{},
    'percentageParametersByMovement':
        fixtureRequest['percentageParametersByMovement'] ??
        const <String, Object?>{},
    'options': _schemaOptionDefaults(schema),
    'unit': fixtureRequest['unit'] ?? 'kg',
    'roundingIncrement': fixtureRequest['roundingIncrement'],
    'barProfile': fixtureRequest['barProfile'],
    'programTitle': 'Parity $id',
    'showPlating': true,
  };
  final options = (request['options'] as Map<String, Object?>);
  if (options['fullBody'] case final Map<String, Object?> fullBody) {
    // The public Full Body editor represents the selected profile as the
    // variant selector; its request payload carries that choice explicitly.
    fullBody['profile'] = variantId;
  }
  final deload = options['deload'];
  request['includeDeload'] = deload is Map && deload['enabled'] is bool
      ? deload['enabled']
      : fixtureRequest['includeDeload'] ?? true;
  request.removeWhere((_, value) => value == null);
  return request;
}

Map<String, Object?> _publicMaxInputs(
  Map<String, Object?> fixtureRequest,
  Map<String, Object?> schema,
) {
  final raw =
      (fixtureRequest['maxInputs'] as Map?)?.cast<String, Object?>() ??
      const <String, Object?>{};
  final unit = fixtureRequest['unit'] as String? ?? 'kg';
  return {
    for (final movement in (schema['movementIds'] as List).cast<String>())
      movement:
          raw[movement] ??
          {
            'type': 'directTrainingMax',
            'weight': {'centiUnits': 10000, 'unit': unit},
          },
  };
}

Map<String, Object?> _schemaOptionDefaults(Map<String, Object?> schema) {
  final options = <String, Object?>{};
  for (final rawField in (schema['fields'] as List)) {
    final field = (rawField as Map).cast<String, Object?>();
    final path = field['path'];
    if (path is! String || !path.startsWith('options.')) continue;
    if (!field.containsKey('value') || field['value'] == null) continue;
    _setJsonPath(options, path.substring('options.'.length), field['value']);
  }
  return options;
}

void _setJsonPath(Map<String, Object?> root, String path, Object? value) {
  final segments = path.split('.');
  var cursor = root;
  for (final segment in segments.take(segments.length - 1)) {
    final child = cursor[segment];
    if (child is Map<String, Object?>) {
      cursor = child;
    } else if (child is Map) {
      final next = child.cast<String, Object?>();
      cursor[segment] = next;
      cursor = next;
    } else {
      final next = <String, Object?>{};
      cursor[segment] = next;
      cursor = next;
    }
  }
  cursor[segments.last] = value;
}

List<String> _files(Directory root, String prefix) {
  final directory = Directory('${root.path}/$prefix');
  if (!directory.existsSync()) return const [];
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .map(
        (file) =>
            file.path.substring(root.path.length + 1).replaceAll('\\', '/'),
      )
      .toList()
    ..sort();
}

Map<String, Object?> _readJson(File file) =>
    (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalize).toList();
  return value;
}
