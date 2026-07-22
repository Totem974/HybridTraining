import 'dart:convert';

/// Integration seam owned by the lead when `training_engine` public codecs land.
///
/// Implementations must decode through the engine's strict v1 codecs and return
/// canonical JSON envelopes. This package deliberately contains no domain rules.
abstract interface class TrainingEngineJsonBindings {
  String initialize(String catalogJson);
  String engineInfo();
  String catalogIndex(String requestJson);
  String cycleEditorSchema(String requestJson);
  String validateCycle(String requestJson);
  String generateCycle(String requestJson);
  String generateMacrocycle(String requestJson);
}

final class BridgeService {
  BridgeService(this._bindings);

  final TrainingEngineJsonBindings _bindings;
  bool _initialized = false;

  String initialize(String catalogJson) {
    _requireJsonObject(catalogJson, operation: 'initialize');
    final result = _bindings.initialize(catalogJson);
    _requireJsonObject(result, operation: 'initialize response');
    _initialized = true;
    return result;
  }

  String engineInfo() {
    _requireInitialized();
    return _checkedResponse(_bindings.engineInfo(), 'engineInfo');
  }

  String catalogIndex(String requestJson) =>
      _invoke('catalogIndex', requestJson, _bindings.catalogIndex);

  String cycleEditorSchema(String requestJson) => _invoke(
    'cycleEditorSchema',
    requestJson,
    _bindings.cycleEditorSchema,
  );

  String validateCycle(String requestJson) =>
      _invoke('validateCycle', requestJson, _bindings.validateCycle);

  String generateCycle(String requestJson) =>
      _invoke('generateCycle', requestJson, _bindings.generateCycle);

  String generateMacrocycle(String requestJson) =>
      _invoke('generateMacrocycle', requestJson, _bindings.generateMacrocycle);

  String _invoke(
    String operation,
    String requestJson,
    String Function(String) handler,
  ) {
    _requireInitialized();
    _requireJsonObject(requestJson, operation: '$operation request');
    return _checkedResponse(handler(requestJson), operation);
  }

  String _checkedResponse(String response, String operation) {
    _requireJsonObject(response, operation: '$operation response');
    return response;
  }

  void _requireInitialized() {
    if (!_initialized) {
      throw StateError('ENGINE_NOT_INITIALIZED');
    }
  }

  static Map<String, Object?> _requireJsonObject(
    String source, {
    required String operation,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException('INVALID_JSON: $operation', error.source);
    }
    if (decoded is! Map<String, Object?>) {
      throw FormatException('JSON_OBJECT_REQUIRED: $operation');
    }
    return decoded;
  }
}
