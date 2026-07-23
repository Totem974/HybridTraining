import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine_web_bridge/training_engine_web_bridge.dart';

const _movementIds = ['overhead_press', 'deadlift', 'bench_press', 'squat'];

void main() {
  test('editor exposes bilingual FSL labels supplied by the catalog', () {
    final schema = _editorSchema(
      _initializedService(),
      templateId: 'source_calculator_first_set_last',
      variantId: 'standard',
    );
    final field = _field(schema, 'fsl_mode');

    expect(_choice(field, 'amrap')['label'], {'en': 'AMRAP', 'fr': 'AMRAP'});
    expect(_choice(field, 'multiple')['label'], {
      'en': 'Multiple sets',
      'fr': 'Séries multiples',
    });
  });

  test('editor exposes bilingual Two Days and Full Body labels', () {
    final service = _initializedService();
    final twoDay = _editorSchema(
      service,
      templateId: 'source_calculator_two_days_per_week',
      variantId: 'option_three',
    );
    final profile = _field(twoDay, 'second_lift_profile');
    expect(_choice(profile, '75_85_95')['label'], {
      'en': '75% × 5 · 85% × 3 · 95% × 1',
      'fr': '75 % × 5 · 85 % × 3 · 95 % × 1',
    });

    final fullBody = _editorSchema(
      service,
      templateId: 'classic_full_body',
      variantId: 'original',
    );
    final phase = _field(fullBody, 'phase');
    expect(_choice(phase, 'phase_two')['label'], {
      'en': 'Phase 2',
      'fr': 'Phase 2',
    });
  });

  test('editor falls back to the serialized enum value without metadata', () {
    final service = _initializedService(removeFslValueLabels: true);
    final schema = _editorSchema(
      service,
      templateId: 'source_calculator_first_set_last',
      variantId: 'standard',
    );

    expect(
      _choice(_field(schema, 'fsl_mode'), 'multiple')['label'],
      'multiple',
    );
  });

  test('GVT per-movement option maps generate through typed bridge maps', () {
    final service = _initializedService();
    final response =
        jsonDecode(service.generateCycle(jsonEncode(_gvtRequest)))
            as Map<String, Object?>;

    final cycle = response['cycle']! as Map<String, Object?>;
    expect(
      cycle['weeks'],
      isA<List<Object?>>().having((weeks) => weeks, 'weeks', isNotEmpty),
    );
  });
}

BridgeService _initializedService({bool removeFslValueLabels = false}) {
  final service = BridgeService(LocalTrainingEngineBindings());
  final bundle =
      jsonDecode(
            File(
              '../../apps/web_generator/public/catalog.bundle.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  for (final path in const [
    'classic/option_schemas.json',
    'classic/extended/option_schemas.json',
    'schedules/cycle_schedules_v1.json',
    'source_fsl_gvt/components.json',
    'source_fsl_gvt/option_schemas.json',
    'source_fsl_gvt/templates.json',
    'source_two_day/components.json',
    'source_two_day/option_schemas.json',
    'source_two_day/templates.json',
  ]) {
    _overlayDocument(bundle, path);
  }
  if (removeFslValueLabels) {
    final schema = _optionSchema(bundle, 'source_fsl_options');
    final parameter = (schema['parameters']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .singleWhere((candidate) => candidate['id'] == 'fsl_mode');
    parameter.remove('valueLabels');
  }
  service.initialize(jsonEncode(bundle));
  return service;
}

void _overlayDocument(Map<String, Object?> bundle, String path) {
  final documents = (bundle['documents']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final content =
      jsonDecode(File('../../catalog_src/$path').readAsStringSync())
          as Map<String, Object?>;
  final matches = documents.where((document) => document['path'] == path);
  if (matches.isEmpty) {
    documents.add({'path': path, 'content': content});
  } else {
    matches.single['content'] = content;
  }
}

Map<String, Object?> _optionSchema(
  Map<String, Object?> bundle,
  String schemaId,
) {
  for (final document
      in (bundle['documents']! as List<Object?>).cast<Map<String, Object?>>()) {
    final content = document['content']! as Map<String, Object?>;
    if (content['kind'] != 'optionSchemas') continue;
    for (final schema
        in (content['optionSchemas']! as List<Object?>)
            .cast<Map<String, Object?>>()) {
      if (schema['id'] == schemaId) return schema;
    }
  }
  throw StateError('Missing option schema $schemaId');
}

Map<String, Object?> _editorSchema(
  BridgeService service, {
  required String templateId,
  required String variantId,
}) =>
    jsonDecode(
          service.cycleEditorSchema(
            jsonEncode({
              'apiVersion': 'v1',
              'schemaVersion': 1,
              'templateId': templateId,
              'variantId': variantId,
            }),
          ),
        )
        as Map<String, Object?>;

Map<String, Object?> _field(Map<String, Object?> schema, String id) =>
    (schema['fields']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .singleWhere((field) => field['id'] == id);

Map<String, Object?> _choice(Map<String, Object?> field, Object value) =>
    (field['choices']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .singleWhere((choice) => choice['value'] == value);

final Map<String, Object?> _gvtRequest = {
  'apiVersion': 'v1',
  'schemaVersion': 1,
  'cycleId': 'gvt-per-movement-map',
  'templateId': 'source_calculator_gvt',
  'variantId': 'standard',
  'scheduleId': 'schedule_four_day_fixed',
  'startDate': '2026-01-05T00:00:00.000Z',
  'trainingDays': [1, 2, 4, 5],
  'sessionOrder': _movementIds,
  'maxInputs': {
    for (final movementId in _movementIds)
      movementId: {
        'type': 'oneRepMax',
        'weight': {'centiUnits': 15000, 'unit': 'lb'},
      },
  },
  'globalTrainingMaxRatioBasisPoints': 9000,
  'trainingMaxRatioByMovement': <String, Object?>{},
  'percentageParameters': <String, Object?>{},
  'percentageParametersByMovement': {
    'overhead_press': {'gvt_percentage': 3000},
    'deadlift': {'gvt_percentage': 4000},
    'bench_press': {'gvt_percentage': 5000},
    'squat': {'gvt_percentage': 6000},
  },
  'options': {
    'warmUp': {'enabled': false},
    'joker': {'enabled': false},
    'deload': {'enabled': false},
    'gvt_use_same_ratio': false,
    'gvt_percentage': {
      'overhead_press': 3000,
      'deadlift': 4000,
      'bench_press': 5000,
      'squat': 6000,
    },
    'gvt_alternate': false,
  },
  'unit': 'lb',
  'roundingIncrement': {'centiUnits': 500, 'unit': 'lb'},
  'barProfile': {
    'weight': {'centiUnits': 4500, 'unit': 'lb'},
    'platesPerSide': [
      {'centiUnits': 4500, 'unit': 'lb'},
      {'centiUnits': 2500, 'unit': 'lb'},
      {'centiUnits': 1000, 'unit': 'lb'},
      {'centiUnits': 500, 'unit': 'lb'},
      {'centiUnits': 250, 'unit': 'lb'},
    ],
  },
  'includeDeload': false,
};
