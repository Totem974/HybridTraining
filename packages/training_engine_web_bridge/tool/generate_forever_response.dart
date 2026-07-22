import 'dart:convert';
import 'dart:io';

import 'package:training_engine_web_bridge/training_engine_web_bridge.dart';

/// Emits the canonical native bridge response for the v1 Forever fixture.
///
/// Optional arguments are the catalog bundle path followed by the request path.
void main(List<String> arguments) {
  final catalogPath = arguments.isNotEmpty
      ? arguments[0]
      : _existingPath(const [
          'apps/web_generator/public/catalog.bundle.json',
          '../../apps/web_generator/public/catalog.bundle.json',
        ]);
  final requestPath = arguments.length > 1
      ? arguments[1]
      : _existingPath(const [
          'contracts/v1/fixtures/forever_request.valid.json',
          '../../contracts/v1/fixtures/forever_request.valid.json',
        ]);
  final service = BridgeService(LocalTrainingEngineBindings());
  service.initialize(File(catalogPath).readAsStringSync());
  final response = service.generateMacrocycle(
    File(requestPath).readAsStringSync(),
  );
  stdout.writeln(_canonicalJson(jsonDecode(response)));
}

String _existingPath(List<String> candidates) => candidates.firstWhere(
  (candidate) => File(candidate).existsSync(),
  orElse: () => throw ArgumentError('Required fixture not found: $candidates'),
);

String _canonicalJson(Object? value) {
  if (value is List<Object?>) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  return jsonEncode(value);
}
