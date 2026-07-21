import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/workspace/workspace_database_schema.dart';
import 'package:hybrid_training/features/poc_531/data/generic_engine_sqlite_codec.dart';
import 'package:hybrid_training/features/poc_531/data/sqlite_engine_request_repository.dart';
import 'package:hybrid_training/features/poc_531/domain/generic_engine/generic_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late _SnapshotPort snapshotPort;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: WorkspaceDatabaseSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, version) => WorkspaceDatabaseSchema.create(db),
      ),
    );
    snapshotPort = _SnapshotPort(_snapshot());
    await _insertWorkspace(database);
  });

  tearDown(() => database.close());

  test('builds an EngineRequest only from coherent v1 and v2 data', () async {
    final repository = _repository(database, snapshotPort);

    final request = await repository.load(
      draftId: 'draft-one',
      athleteId: 'athlete-one',
    );

    expect(request.snapshot.id, CatalogId('catalog-v1'));
    expect(request.trainingMaxes.trainingMaxFor(CatalogId('back-squat')), 90);
    expect(request.trainingMaxes.ratioFor(CatalogId('back-squat')), 0.85);
    expect(request.trainingMaxes.ratioFor(CatalogId('bench-press')), 0.9);
    expect(request.equipment.barWeight, 20);
    expect(request.equipment.availablePlates, [20]);
    expect(request.assistance?.selections.single.deload, isNotNull);
    expect(request.conditioning.single.definition.id, CatalogId('sled'));
    expect(snapshotPort.requestedId, CatalogId('catalog-v1'));
  });

  test('rejects a draft pinned to another catalog content hash', () async {
    await database.update(
      'workspace_drafts',
      {'catalog_content_hash': 'b' * 64},
      where: 'id = ?',
      whereArgs: ['draft-one'],
    );

    await expectLater(
      _repository(
        database,
        snapshotPort,
      ).load(draftId: 'draft-one', athleteId: 'athlete-one'),
      throwsA(
        isA<EngineRequestLoadException>()
            .having((error) => error.code, 'code', 'catalog.hash_mismatch')
            .having(
              (error) => error.path,
              'path',
              r'$.draft.catalogContentHash',
            ),
      ),
    );
  });

  test(
    'rejects a missing athlete rounding increment instead of defaulting',
    () async {
      await database.update(
        'athlete_profiles',
        {'rounding_increment': null},
        where: 'id = ?',
        whereArgs: ['athlete-one'],
      );

      await expectLater(
        _repository(
          database,
          snapshotPort,
        ).load(draftId: 'draft-one', athleteId: 'athlete-one'),
        throwsA(
          isA<EngineRequestLoadException>().having(
            (error) => error.code,
            'code',
            'training_max.missing_rounding',
          ),
        ),
      );
    },
  );

  test(
    'rejects a persisted per-movement ratio that differs from payload',
    () async {
      await database.update(
        'weight_profiles',
        {'training_max_ratio': 0.8},
        where: 'athlete_id = ? AND movement_key = ?',
        whereArgs: ['athlete-one', 'back-squat'],
      );

      await expectLater(
        _repository(
          database,
          snapshotPort,
        ).load(draftId: 'draft-one', athleteId: 'athlete-one'),
        throwsA(
          isA<EngineRequestLoadException>().having(
            (error) => error.code,
            'code',
            'training_max.ratio_mismatch',
          ),
        ),
      );
    },
  );

  test('rejects custom assistance without its structured deload', () async {
    await database.delete(
      'workspace_draft_assistance_prescriptions',
      where: 'selection_id = ? AND phase = ?',
      whereArgs: ['selection-one', 'deload'],
    );

    await expectLater(
      _repository(
        database,
        snapshotPort,
      ).load(draftId: 'draft-one', athleteId: 'athlete-one'),
      throwsA(
        isA<EngineRequestLoadException>().having(
          (error) => error.code,
          'code',
          'assistance.invalid_deload',
        ),
      ),
    );
  });

  test('rejects conditioning order gaps before catalog resolution', () async {
    await database.update(
      'workspace_draft_conditioning',
      {'sequence': 2},
      where: 'draft_id = ?',
      whereArgs: ['draft-one'],
    );

    await expectLater(
      _repository(
        database,
        snapshotPort,
      ).load(draftId: 'draft-one', athleteId: 'athlete-one'),
      throwsA(
        isA<EngineRequestLoadException>().having(
          (error) => error.code,
          'code',
          'conditioning.non_contiguous_sequence',
        ),
      ),
    );
  });
}

SqliteEngineRequestRepository _repository(
  Database database,
  CatalogSnapshotPort snapshotPort,
) => SqliteEngineRequestRepository(
  database: database,
  snapshotPort: snapshotPort,
  codec: const GenericEngineSqliteCodec(),
  maxCalculationRulePort: const _MaxRulePort(),
  assistanceConfigurationPort: const _AssistancePort(),
  conditioningConfigurationPort: const _ConditioningPort(),
);

final class _SnapshotPort implements CatalogSnapshotPort {
  _SnapshotPort(this.snapshot);

  final CatalogSnapshot snapshot;
  CatalogId? requestedId;

  @override
  Future<CatalogSnapshot> load(CatalogId snapshotId, {int? revision}) async {
    requestedId = snapshotId;
    return snapshot;
  }
}

final class _MaxRulePort implements MaxCalculationRulePort {
  const _MaxRulePort();

  @override
  Future<MaxCalculationRule> load({
    required CatalogId ruleId,
    required CatalogId catalogVersionId,
  }) async => MaxCalculationRule(
    id: CatalogId('tm-rule'),
    governance: _governance,
    formulas: {RepMaxFormula.epley},
    evidence: _evidence('tm-rule'),
  );
}

final class _AssistancePort implements AssistanceConfigurationPort {
  const _AssistancePort();

  @override
  Future<AssistancePlan> resolve({
    required CatalogId planId,
    required List<WorkspaceAssistanceSelection> selections,
    required CatalogSnapshot snapshot,
  }) async {
    if (planId != CatalogId('assistance-plan')) {
      throw StateError('unknown plan');
    }
    return AssistancePlan(
      slots: [
        AssistanceSlot(
          id: CatalogId('push-slot'),
          roleId: CatalogId('push'),
          minimumSelections: 1,
          maximumSelections: 1,
          movementIds: {CatalogId('back-squat')},
        ),
      ],
      selections: [
        for (final selection in selections)
          AssistanceSelection(
            slotId: selection.slotId,
            movementId: selection.movementId,
            regular: selection.regular,
            deloadMode: selection.deloadMode,
            deload: selection.deload,
          ),
      ],
    );
  }
}

final class _ConditioningPort implements ConditioningConfigurationPort {
  const _ConditioningPort();

  @override
  Future<List<ConditioningConfiguration>> resolve({
    required List<WorkspaceConditioningSelection> selections,
    required CatalogSnapshot snapshot,
  }) async => [
    for (final selection in selections)
      ConditioningConfiguration(
        definition: ConditioningDefinition(
          id: CatalogId('sled'),
          modalities: {ConditioningModality.time},
          governance: _governance,
          evidence: _evidence('conditioning-rule'),
        ),
        prescription: selection.prescription,
      ),
  ];
}

CatalogSnapshot _snapshot() => CatalogSnapshot(
  id: CatalogId('catalog-v1'),
  revision: 1,
  contentHash: 'a' * 64,
  canonicalizationVersion: 1,
  movements: [
    MovementDefinition(
      id: CatalogId('back-squat'),
      governance: _governance,
      kind: MovementKind.barbell,
      bodyRegion: BodyRegion.lower,
      capabilities: const {},
      evidence: _evidence('movement-rule'),
    ),
    MovementDefinition(
      id: CatalogId('bench-press'),
      governance: _governance,
      kind: MovementKind.barbell,
      bodyRegion: BodyRegion.upper,
      capabilities: const {},
      evidence: _evidence('movement-rule'),
    ),
  ],
  templates: [
    TrainingTemplateGraph(
      id: CatalogId('template'),
      revision: 1,
      governance: _governance,
      variants: [TemplateVariant(id: CatalogId('base'), moduleIds: const {})],
      parameters: const [],
      modules: const [],
      evidence: _evidence('template-rule'),
    ),
  ],
  modules: const [],
  finitePrograms: const [],
);

final _governance = CatalogGovernance(
  authority: CatalogAuthority.canonical,
  review: CatalogReviewStatus.confirmed,
  lifecycle: CatalogLifecycle.published,
  visibility: CatalogVisibility.public,
  executable: true,
);

CatalogEvidence _evidence(String ruleId) => CatalogEvidence(
  ruleId: CatalogId(ruleId),
  references: [
    EvidenceReference(
      sourceId: CatalogId('fixture-source'),
      locator: 'fictitious test fixture',
      sourceRevision: 1,
    ),
  ],
);

Future<void> _insertWorkspace(Database database) async {
  await database.insert('athlete_profiles', {
    'id': 'athlete-one',
    'display_name': 'Fixture Athlete',
    'preferred_unit': 'kg',
    'rounding_increment': 2.5,
    'created_at': '2026-07-21T00:00:00Z',
    'updated_at': '2026-07-21T00:00:00Z',
  });
  await database.insert('weight_profiles', {
    'id': 'weight-one',
    'athlete_id': 'athlete-one',
    'movement_key': 'back-squat',
    'one_rep_max': null,
    'training_max': 90,
    'training_max_ratio': 0.85,
    'unit': 'kg',
    'effective_at': '2026-07-21T00:00:00Z',
  });
  await database.insert('weight_profiles', {
    'id': 'weight-two',
    'athlete_id': 'athlete-one',
    'movement_key': 'bench-press',
    'one_rep_max': null,
    'training_max': 50,
    'training_max_ratio': 0.9,
    'unit': 'kg',
    'effective_at': '2026-07-21T00:00:00Z',
  });
  await database.insert('gyms', {
    'id': 'gym-one',
    'athlete_id': 'athlete-one',
    'name': 'Fixture Gym',
    'is_default': 1,
  });
  await database.insert('bars', {
    'id': 'bar-one',
    'gym_id': 'gym-one',
    'name': 'Fixture Bar',
    'weight': 20,
    'unit': 'kg',
    'quantity': 1,
  });
  await database.insert('plates', {
    'id': 'plate-one',
    'gym_id': 'gym-one',
    'weight': 20,
    'unit': 'kg',
    'quantity': 2,
  });
  await database.insert('workspace_drafts', {
    'id': 'draft-one',
    'athlete_id': 'athlete-one',
    'catalog_version_id': 'catalog-v1',
    'catalog_content_hash': 'a' * 64,
    'catalog_canonicalization_version': 1,
    'payload_schema_version': 1,
    'kind': 'configuration',
    'payload_json': jsonEncode(_payload),
    'created_at': '2026-07-21T00:00:00Z',
    'updated_at': '2026-07-21T00:00:00Z',
  });
  await database.insert('workspace_draft_equipment', {
    'draft_id': 'draft-one',
    'athlete_id': 'athlete-one',
    'gym_id': 'gym-one',
    'bar_id': 'bar-one',
  });
  for (final equipmentId in ['barbell']) {
    await database.insert('workspace_draft_equipment_ids', {
      'draft_id': 'draft-one',
      'equipment_id': equipmentId,
    });
  }
  for (final loadKind in ['externalWeight', 'bodyweight']) {
    await database.insert('workspace_draft_supported_loads', {
      'draft_id': 'draft-one',
      'load_kind': loadKind,
    });
  }
  await database.insert('workspace_draft_assistance', {
    'draft_id': 'draft-one',
    'assistance_plan_id': 'assistance-plan',
  });
  await database.insert('workspace_draft_assistance_selections', {
    'id': 'selection-one',
    'draft_id': 'draft-one',
    'slot_id': 'push-slot',
    'movement_id': 'back-squat',
    'deload_mode': 'custom',
  });
  for (final phase in ['regular', 'deload']) {
    await database.insert('workspace_draft_assistance_prescriptions', {
      'selection_id': 'selection-one',
      'phase': phase,
      'sets': phase == 'regular' ? 3 : 2,
      'repetition_kind': 'fixed',
      'repetition_minimum': phase == 'regular' ? 10 : 5,
      'repetition_maximum': null,
      'load_kind': 'bodyweight',
      'load_value': null,
    });
  }
  await database.insert('workspace_draft_conditioning', {
    'draft_id': 'draft-one',
    'sequence': 0,
    'definition_id': 'sled',
    'modality': 'time',
    'target': 600,
    'work_seconds': null,
    'rest_seconds': null,
  });
}

final Map<String, Object?> _payload = {
  'schemaVersion': 1,
  'templateId': 'template',
  'templateRevision': 1,
  'variantId': 'base',
  'parameters': <Object?>[],
  'trainingMaxes': {
    'calculationRuleId': 'tm-rule',
    'globalRatio': 0.9,
    'unit': 'kilograms',
    'roundingIncrement': 2.5,
    'inputs': [
      {'movementId': 'back-squat', 'kind': 'directTrainingMax', 'weight': 90},
      {'movementId': 'bench-press', 'kind': 'directTrainingMax', 'weight': 50},
    ],
    'ratiosByMovement': [
      {'movementId': 'back-squat', 'ratio': 0.85},
    ],
  },
  'equipment': {
    'equipmentIds': ['barbell'],
    'supportedLoads': ['externalWeight', 'bodyweight'],
    'barWeight': 20,
    'availablePlates': [20],
  },
  'assistance': {
    'slots': [
      {
        'id': 'push-slot',
        'roleId': 'push',
        'minimumSelections': 1,
        'maximumSelections': 1,
        'movementIds': ['back-squat'],
      },
    ],
    'selections': [
      {
        'slotId': 'push-slot',
        'movementId': 'back-squat',
        'regular': {
          'sets': 3,
          'repetitions': {'kind': 'fixed', 'count': 10},
          'load': {'kind': 'bodyweight'},
        },
        'deloadMode': 'custom',
        'deload': {
          'sets': 2,
          'repetitions': {'kind': 'fixed', 'count': 5},
          'load': {'kind': 'bodyweight'},
        },
      },
    ],
  },
  'conditioning': [
    {
      'definitionId': 'sled',
      'prescription': {'modality': 'time', 'target': 600},
    },
  ],
};
