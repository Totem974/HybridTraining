import 'dart:js_interop';

import 'package:training_engine_web_bridge/training_engine_web_bridge.dart';

@JS('globalThis.hybridTrainingEngine')
external set _globalEngine(JSObject value);

@JSExport()
final class HybridTrainingEngineJsApi {
  HybridTrainingEngineJsApi(this._service);

  final BridgeService _service;

  String initialize(String catalogJson) => _service.initialize(catalogJson);
  String engineInfo() => _service.engineInfo();
  String catalogIndex(String requestJson) =>
      _service.catalogIndex(requestJson);
  String cycleEditorSchema(String requestJson) =>
      _service.cycleEditorSchema(requestJson);
  String validateCycle(String requestJson) =>
      _service.validateCycle(requestJson);
  String generateCycle(String requestJson) =>
      _service.generateCycle(requestJson);
  String generateMacrocycle(String requestJson) =>
      _service.generateMacrocycle(requestJson);
}

/// Supplied by the integration layer once the package API is frozen.
TrainingEngineJsonBindings createTrainingEngineBindings() =>
    throw UnsupportedError(
      'INTEGRATION_REQUIRED: bind training_engine v1 JSON codecs',
    );

void main() {
  final api = HybridTrainingEngineJsApi(
    BridgeService(createTrainingEngineBindings()),
  );
  _globalEngine = createJSInteropWrapper(api);
}
