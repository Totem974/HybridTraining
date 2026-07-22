import 'package:test/test.dart';
import 'package:training_engine_web_bridge/training_engine_web_bridge.dart';

void main() {
  test('requires initialization before operations', () {
    final service = BridgeService(_Bindings());
    expect(service.engineInfo, throwsA(isA<StateError>()));
  });

  test('passes JSON strings without exposing Dart objects', () {
    final bindings = _Bindings();
    final service = BridgeService(bindings);
    expect(service.initialize('{}'), '{"initialized":true}');
    expect(service.generateCycle('{"apiVersion":"v1"}'), '{"ok":true}');
    expect(bindings.lastRequest, '{"apiVersion":"v1"}');
  });

  test('rejects non-object JSON at the boundary', () {
    final service = BridgeService(_Bindings());
    expect(() => service.initialize('[]'), throwsA(isA<FormatException>()));
  });
}

final class _Bindings implements TrainingEngineJsonBindings {
  String? lastRequest;

  @override
  String initialize(String catalogJson) => '{"initialized":true}';
  @override
  String engineInfo() => '{"ok":true}';
  @override
  String catalogIndex(String requestJson) => '{"ok":true}';
  @override
  String cycleEditorSchema(String requestJson) => '{"ok":true}';
  @override
  String validateCycle(String requestJson) => '{"ok":true}';
  @override
  String generateCycle(String requestJson) {
    lastRequest = requestJson;
    return '{"ok":true}';
  }

  @override
  String generateMacrocycle(String requestJson) => '{"ok":true}';
}
