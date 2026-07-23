import 'dart:convert';
import 'dart:io';

import 'package:hybrid_training/features/cycle_generation/domain/cycle_compiler_impl.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/training_catalog/data/sqlite_training_catalog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../catalog/catalog_tool.dart' as catalog_tool;

const _catalogVersion = 2;
const _fixtureVersion = 1;
const _legacyCycleFixtureOrdinals = <String, int>{
  'beyond_boring_but_big--same_lift_5x10_50_two_cycles': 0,
  'beyond_first_set_last--amrap_four_day_two_cycles': 1,
  'beyond_fives_progression--main_lifts_four_day_two_cycles': 2,
  'beyond_pyramid--four_day_two_cycles': 3,
  'classic_531--four_day': 4,
  'classic_531--three_day_rotation': 5,
  'classic_531--two_day_rotation': 6,
  'classic_bodyweight--four_day': 7,
  'classic_boring_but_big--same_lift_5x10': 8,
  'classic_for_beginners--original_progression': 9,
  'classic_full_body--full_boring': 10,
  'classic_full_body--original': 11,
  'classic_full_body--updated': 12,
  'classic_jack_shit--main_lift_only': 13,
  'classic_periodization_bible--four_day': 14,
  'classic_simplest_strength--original': 15,
  'classic_simplest_strength--powerlifting': 16,
  'classic_triumvirate--four_day': 17,
  'powerlifting_classic_531--four_day_531_deload': 18,
};

Future<void> main(List<String> arguments) async {
  final output = Directory(
    arguments.isEmpty ? 'test/fixtures/engine-v1' : arguments.single,
  );
  await generateEngineV1Fixtures(output);
  stdout.writeln('generated ${output.path}');
}

Future<void> generateEngineV1Fixtures(Directory output) async {
  _rejectSourceCalculatorOracleOutput(output);
  sqfliteFfiInit();
  final temporary = Directory.systemTemp.createTempSync('engine_v1_oracles_');
  Database? database;
  try {
    final catalogPath = '${temporary.path}/catalog.db';
    await catalog_tool.buildCatalogDatabase(catalogPath);
    database = await databaseFactoryFfi.openDatabase(catalogPath);
    final catalog = SqliteTrainingCatalog(database);
    final index = await catalog.loadIndex(catalogVersion: _catalogVersion);
    final fixtures = <Map<String, Object?>>[];
    var nextNewOrdinal = _legacyCycleFixtureOrdinals.length;
    for (final template in index.templates) {
      for (final variantId in template.variantIds) {
        final fixtureId = '${template.id}--$variantId';
        // Existing fixture inputs remain stable when a catalog variant is added.
        final ordinal =
            _legacyCycleFixtureOrdinals[fixtureId] ?? nextNewOrdinal++;
        final definition = await catalog.resolve(
          catalogVersion: _catalogVersion,
          templateId: template.id,
          variantId: variantId,
        );
        final metadataRows = await database.query(
          'catalog_variant_metadata',
          columns: ['schedule_ids_json', 'valid_example_json'],
          where: 'version=? AND template_id=? AND variant_id=?',
          whereArgs: [_catalogVersion, template.id, variantId],
          limit: 1,
        );
        final metadata = metadataRows.single;
        final example =
            (jsonDecode(metadata['valid_example_json']! as String) as Map)
                .cast<String, Object?>();
        final allowedSchedules =
            (jsonDecode(metadata['schedule_ids_json']! as String) as List)
                .cast<String>();
        final fixture = _buildCycleFixture(
          definition: definition,
          ordinal: ordinal,
          example: example,
          allowedSchedules: allowedSchedules,
        );
        fixtures.add(fixture);
      }
    }
    fixtures.sort(
      (left, right) =>
          (left['id']! as String).compareTo(right['id']! as String),
    );

    final errors = _buildErrorFixtures();
    final forever = jsonDecode(
      await File(
        'test/fixtures/forever_macrocycle_plan.golden.json',
      ).readAsString(),
    );
    final foreverSnapshot = _canonicalize(forever);
    final manifest = <String, Object?>{
      'fixtureVersion': _fixtureVersion,
      'catalogVersion': _catalogVersion,
      'cycleVariantCount': fixtures.length,
      'cycleFixtures': fixtures.map((fixture) => fixture['id']).toList(),
      'errorFixtures': errors.map((fixture) => fixture['id']).toList(),
      'foreverFixtures': const ['forever-macrocycle-plan'],
    };

    output.createSync(recursive: true);
    for (final fixture in fixtures) {
      _writeJson(output, 'cycle/${fixture['id']}.json', fixture);
    }
    for (final fixture in errors) {
      _writeJson(output, 'errors/${fixture['id']}.json', fixture);
    }
    _writeJson(output, 'forever/forever-macrocycle-plan.json', {
      'fixtureVersion': _fixtureVersion,
      'id': 'forever-macrocycle-plan',
      'snapshot': foreverSnapshot,
      'logicalHash': logicalHash(foreverSnapshot),
    });
    _writeJson(output, 'manifest.json', manifest);
  } finally {
    await database?.close();
    if (temporary.existsSync()) temporary.deleteSync(recursive: true);
  }
}

void _rejectSourceCalculatorOracleOutput(Directory output) {
  String normalized(Directory directory) =>
      directory.absolute.path.replaceAll('\\', '/').toLowerCase();
  final protected = normalized(Directory('test/fixtures/source-calculator-v1'));
  final candidate = normalized(output);
  if (candidate == protected || candidate.startsWith('$protected/')) {
    throw StateError(
      'The independent source calculator oracle cannot be regenerated by '
      'the HybridTraining engine fixture generator.',
    );
  }
}

Map<String, Object?> _buildCycleFixture({
  required ResolvedCycleDefinition definition,
  required int ordinal,
  required Map<String, Object?> example,
  required List<String> allowedSchedules,
}) {
  final unit = ordinal.isEven ? WeightUnit.kg : WeightUnit.lb;
  final movements = _maximumMovementIds(definition).toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  final maxInputs = <MovementId, TrainingMaxInput>{};
  for (var index = 0; index < movements.length; index++) {
    final weight = Weight(12000 + ordinal * 200 + index * 1750, unit);
    maxInputs[movements[index]] = switch ((ordinal + index) % 3) {
      0 => OneRepMaxInput(weight),
      1 => RepMaxInput(weight, 3 + (index % 5)),
      _ => DirectTrainingMaxInput(weight),
    };
  }
  final ratio =
      example['trainingMaxRatioBasisPoints'] ??
      example['trainingMaxRatio'] ??
      9000;
  final ratioBasisPoints = ratio as int;
  final perMovementRatios = movements.length > 1
      ? <MovementId, Percentage>{
          movements.last: Percentage((ratioBasisPoints - 250).clamp(1, 10000)),
        }
      : const <MovementId, Percentage>{};
  final plates = unit == WeightUnit.kg
      ? const [2500, 2000, 1500, 1000, 500, 250, 125]
      : const [4500, 2500, 1000, 500, 250];
  final request = CycleRequest(
    cycleId: 'oracle-${definition.templateId}-${definition.variantId}',
    startDate: DateTime.utc(2026, 1, 5).add(Duration(days: ordinal)),
    trainingDays: [
      for (var i = 0; i < definition.sessionMovementIds.length; i++) i + 1,
    ],
    sessionOrder: definition.sessionMovementIds,
    maxInputs: maxInputs,
    globalTrainingMaxRatio: Percentage(ratioBasisPoints),
    trainingMaxRatioByMovement: perMovementRatios,
    unit: unit,
    roundingIncrement: Weight(unit == WeightUnit.kg ? 250 : 500, unit),
    barProfile: BarProfile(
      weight: Weight(unit == WeightUnit.kg ? 2000 : 4500, unit),
      platesPerSide: [for (final value in plates) Weight(value, unit)],
    ),
    includeDeload: ordinal % 4 != 0,
  );
  final response = const CycleCompilerImpl()
      .compile(definition, request)
      .toJson();
  final snapshot = _canonicalize(response) as Map<String, Object?>;
  return {
    'fixtureVersion': _fixtureVersion,
    'id': '${definition.templateId}--${definition.variantId}',
    'catalogSelection': {
      'catalogVersion': definition.catalogVersion,
      'templateId': definition.templateId,
      'variantId': definition.variantId,
      'sourceReference': definition.sourceReference,
      'allowedScheduleIds': allowedSchedules,
      'validExample': example,
    },
    'coverage': {
      'maxInputModes': maxInputs.values.map(_maxInputKind).toSet().toList()
        ..sort(),
      'unit': unit.name,
      'globalTrainingMaxRatio': ratioBasisPoints,
      'perMovementRatio': perMovementRatios.isNotEmpty,
      'schedule': true,
      'plating': true,
      'catalogOptions': true,
      'includeDeload': request.includeDeload,
    },
    'request': _requestJson(request),
    'response': response,
    'snapshot': snapshot,
    'logicalHash': logicalHash(snapshot),
  };
}

List<Map<String, Object?>> _buildErrorFixtures() => [
  {
    'fixtureVersion': _fixtureVersion,
    'id': 'missing-training-max',
    'requestPatch': {'maxInputs': <String, Object?>{}},
    'expectedError': {
      'category': 'validation',
      'code': 'missing_training_max',
      'path': r'$.maxInputs',
    },
  },
  {
    'fixtureVersion': _fixtureVersion,
    'id': 'invalid-schedule-cardinality',
    'requestPatch': {
      'trainingDays': [1],
      'sessionOrder': <String>[],
    },
    'expectedError': {
      'category': 'validation',
      'code': 'invalid_schedule',
      'path': r'$.sessionOrder',
    },
  },
  {
    'fixtureVersion': _fixtureVersion,
    'id': 'mixed-weight-units',
    'requestPatch': {
      'unit': 'kg',
      'roundingIncrement': {'centiUnits': 500, 'unit': 'lb'},
    },
    'expectedError': {
      'category': 'validation',
      'code': 'mixed_weight_units',
      'path': r'$.roundingIncrement.unit',
    },
  },
];

Map<String, Object?> _requestJson(CycleRequest request) => {
  'cycleId': request.cycleId,
  'startDate': request.startDate.toIso8601String(),
  'trainingDays': request.trainingDays,
  'sessionOrder': request.sessionOrder.map((id) => id.value).toList(),
  'maxInputs': request.maxInputs.map(
    (id, input) => MapEntry(id.value, _maxInputJson(input)),
  ),
  'globalTrainingMaxRatioBasisPoints':
      request.globalTrainingMaxRatio.basisPoints,
  'trainingMaxRatioByMovement': request.trainingMaxRatioByMovement.map(
    (id, value) => MapEntry(id.value, value.basisPoints),
  ),
  'percentageParameters': request.percentageParameters.map(
    (id, value) => MapEntry(id, value.basisPoints),
  ),
  'percentageParametersByMovement': request.percentageParametersByMovement.map(
    (id, values) => MapEntry(
      id.value,
      values.map((key, value) => MapEntry(key, value.basisPoints)),
    ),
  ),
  'unit': request.unit.name,
  'roundingIncrement': request.roundingIncrement.toJson(),
  'barProfile': {
    'weight': request.barProfile.weight.toJson(),
    'platesPerSide': request.barProfile.platesPerSide
        .map((plate) => plate.toJson())
        .toList(),
  },
  'includeDeload': request.includeDeload,
};

String _maxInputKind(TrainingMaxInput input) => switch (input) {
  OneRepMaxInput() => 'oneRepMax',
  RepMaxInput() => 'repMax',
  DirectTrainingMaxInput() => 'directTrainingMax',
  OnePlusSetInput() => 'onePlusSet',
};

Map<String, Object?> _maxInputJson(TrainingMaxInput input) => switch (input) {
  OneRepMaxInput(:final weight) => {
    'type': 'oneRepMax',
    'weight': weight.toJson(),
  },
  RepMaxInput(:final weight, :final repetitions, :final formula) => {
    'type': 'repMax',
    'weight': weight.toJson(),
    'repetitions': repetitions,
    'formula': formula,
  },
  DirectTrainingMaxInput(:final weight) => {
    'type': 'directTrainingMax',
    'weight': weight.toJson(),
  },
  OnePlusSetInput(:final weight, :final topSetPercentage) => {
    'type': 'onePlusSet',
    'weight': weight.toJson(),
    'topSetPercentageBasisPoints': topSetPercentage.basisPoints,
  },
};

Set<MovementId> _maximumMovementIds(ResolvedCycleDefinition definition) {
  final result = <MovementId>{};
  for (final week in definition.weeks) {
    if (week.sessions.isEmpty) {
      for (final sessionId in definition.sessionMovementIds) {
        for (final block in week.blocks) {
          result.add(block.movementId ?? sessionId);
        }
      }
    } else {
      for (final session in week.sessions) {
        for (final block in session.blocks) {
          result.add(block.movementId ?? session.id);
        }
      }
    }
  }
  return result;
}

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

String logicalHash(Object? value) {
  final bytes = utf8.encode(jsonEncode(_canonicalize(value)));
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

void _writeJson(Directory root, String relativePath, Object? value) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
  );
}
