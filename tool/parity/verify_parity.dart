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
    'runners': <String, Object?>{},
  };
  try {
    await generateEngineV1Fixtures(nativeOutput);
    final contractFailures = report['contractFailures']! as List<Object?>;
    final cycleFailures = report['cycleParityFailures']! as List<Object?>;
    final foreverFailures = report['foreverParityFailures']! as List<Object?>;
    _validateContracts(fixtures, contractFailures);
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
  if (manifest['fixtureVersion'] != 1 || manifest['cycleVariantCount'] != 23) {
    failures.add({
      'fixture': 'manifest.json',
      'message': 'Expected fixtureVersion 1 and exactly 23 Cycle variants.',
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
  final nativeForever = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}hybrid_forever_native_${DateTime.now().microsecondsSinceEpoch}.json',
  );
  late final ProcessResult result;
  try {
    final service = BridgeService(LocalTrainingEngineBindings());
    service.initialize(
      File('apps/web_generator/public/catalog.bundle.json').readAsStringSync(),
    );
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
      nativeForever.path,
    ]);
  } on ProcessException catch (error) {
    return {
      'status': 'skipped',
      'reason':
          'Node.js is unavailable (${error.message}); bridge parity was not simulated.',
    };
  }
  if (nativeForever.existsSync()) nativeForever.deleteSync();
  final output = '${result.stdout}'.trim();
  if (output.isEmpty) {
    return {
      'status': 'failed',
      'contractFailures': [
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
    return decoded.cast<String, Object?>();
  } catch (error) {
    return {
      'status': 'failed',
      'contractFailures': [
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
