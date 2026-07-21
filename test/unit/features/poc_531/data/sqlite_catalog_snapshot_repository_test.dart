import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/catalog/catalog_database_schema.dart';
import 'package:hybrid_training/core/database/catalog/catalog_publication_service.dart';
import 'package:hybrid_training/features/poc_531/data/generic_engine_sqlite_codec.dart';
import 'package:hybrid_training/features/poc_531/data/sqlite_catalog_snapshot_repository.dart';
import 'package:hybrid_training/features/poc_531/domain/generic_engine/catalog_contract.dart';
import 'package:hybrid_training/features/poc_531/domain/generic_engine/template_graph.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: CatalogDatabaseSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, version) => CatalogDatabaseSchema.create(db),
      ),
    );
  });

  tearDown(() => database.close());

  test('loads a verified published cycle V5 graph with proofs', () async {
    await _insertCycleGraph(database);
    await _publish(database);

    final snapshot = await SqliteCatalogSnapshotRepository(
      database: database,
      codec: const GenericEngineSqliteCodec(),
    ).load(CatalogId('catalog-v1'));

    expect(snapshot.id, CatalogId('catalog-v1'));
    expect(snapshot.revision, 1);
    expect(snapshot.canonicalizationVersion, 1);
    expect(snapshot.contentHash, hasLength(64));
    expect(snapshot.finitePrograms, isEmpty);
    expect(snapshot.movements.single.id, CatalogId('back-squat'));
    expect(snapshot.movements.single.evidence, isNotNull);
    final template = snapshot.templates.single as TrainingTemplateGraph;
    expect(template.id, CatalogId('standard-cycle'));
    expect(template.variants.single.id, CatalogId('base'));
    expect(
      template.variants.single.parameters.single.id,
      CatalogId('main-movement'),
    );
    expect(
      template.variants.single.moduleBindings.single.id,
      CatalogId('main-binding'),
    );
    expect(template.parameters, isEmpty);
    expect(template.modules, isEmpty);
    expect(snapshot.modules.single.id, CatalogId('main-work'));
    expect(snapshot.modules.single.evidence, isNotNull);
  });

  test('rejects a published receipt whose content hash is false', () async {
    await _insertCycleGraph(database);
    await _publish(database, preservePlaceholderHash: true);

    await expectLater(
      SqliteCatalogSnapshotRepository(
        database: database,
        codec: const _FixtureCodec(),
      ).load(CatalogId('catalog-v1')),
      throwsA(
        isA<CatalogSnapshotLoadException>().having(
          (error) => error.code,
          'code',
          'version.hash_mismatch',
        ),
      ),
    );
  });

  test('rejects finite programs instead of returning an empty list', () async {
    await _insertCycleGraph(database);
    await database.insert('finite_programs', {
      'id': 'finite-one',
      'catalog_version_id': 'catalog-v1',
      'template_id': 'template-one',
      'stable_key': 'finite-one',
    });
    await _evidence(
      database,
      id: 'evidence-finite',
      type: 'finiteProgram',
      subjectId: 'finite-one',
      ruleId: 'finite-rule',
    );
    await _publish(database);

    await expectLater(
      SqliteCatalogSnapshotRepository(
        database: database,
        codec: const _FixtureCodec(),
      ).load(CatalogId('catalog-v1')),
      throwsA(
        isA<CatalogSnapshotLoadException>().having(
          (error) => error.code,
          'code',
          'finite_program.unsupported',
        ),
      ),
    );
  });

  test(
    'round-trips multiple declarative rules with evidence by rule ID',
    () async {
      await _insertCycleGraph(database);
      await _insertRule(
        database,
        id: 'constraint-one',
        kind: 'constraint',
        condition: '{"astVersion":1,"nodeType":"always","value":true}',
      );
      await _insertRule(
        database,
        id: 'visible-main',
        kind: 'visibility',
        targetParameterId: 'main-movement',
        condition:
            '{"astVersion":1,"nodeType":"present","parameterId":"main-movement"}',
      );
      await _publish(database);

      final snapshot = await SqliteCatalogSnapshotRepository(
        database: database,
        codec: const GenericEngineSqliteCodec(),
      ).load(CatalogId('catalog-v1'));
      final variant =
          (snapshot.templates.single as TrainingTemplateGraph).variants.single;

      expect(variant.rules.map((rule) => rule.id), [
        CatalogId('constraint-one'),
        CatalogId('visible-main'),
      ]);
      expect(
        variant.evidenceByRuleId.keys,
        containsAll([CatalogId('constraint-one'), CatalogId('visible-main')]),
      );
    },
  );

  test('round-trips mutually exclusive schemas from A/B variants', () async {
    await _insertCycleGraph(database);
    await _insertSecondVariant(database);
    await _publish(database);

    final snapshot = await SqliteCatalogSnapshotRepository(
      database: database,
      codec: const GenericEngineSqliteCodec(),
    ).load(CatalogId('catalog-v1'));
    final variants =
        (snapshot.templates.single as TrainingTemplateGraph).variants;

    expect(variants, hasLength(2));
    expect(
      variants
          .singleWhere((variant) => variant.id == CatalogId('base'))
          .parameters
          .single
          .id,
      CatalogId('main-movement'),
    );
    expect(
      variants
          .singleWhere((variant) => variant.id == CatalogId('alternate'))
          .parameters
          .single
          .id,
      CatalogId('alternate-only'),
    );
  });

  test('rejects an unknown declarative rule AST node', () async {
    await _insertCycleGraph(database);
    await _insertRule(
      database,
      id: 'unknown-rule',
      kind: 'constraint',
      condition: '{"astVersion":1,"nodeType":"futureNode"}',
    );
    await _publish(database);

    await expectLater(
      SqliteCatalogSnapshotRepository(
        database: database,
        codec: const GenericEngineSqliteCodec(),
      ).load(CatalogId('catalog-v1')),
      throwsA(
        isA<CatalogSnapshotLoadException>().having(
          (error) => error.code,
          'code',
          'catalog.not_decodable',
        ),
      ),
    );
  });

  test(
    'resolves a governed catalog entry alias in its published version',
    () async {
      await _insertCycleGraph(database);
      await _evidence(
        database,
        id: 'evidence-alias',
        type: 'catalogEntry',
        subjectId: 'entry-template',
        ruleId: 'alias-rule',
      );
      await database.insert('catalog_entry_aliases', {
        'id': 'alias-one',
        'catalog_version_id': 'catalog-v1',
        'namespace': 'legacy',
        'alias': 'standard-531-v1',
        'catalog_entry_id': 'entry-template',
        'evidence_id': 'evidence-alias',
        'review_status': 'confirmed',
      });
      await _publish(database);
      final repository = SqliteCatalogSnapshotRepository(
        database: database,
        codec: const GenericEngineSqliteCodec(),
      );

      expect(
        await repository.resolveAlias(
          catalogVersionId: CatalogId('catalog-v1'),
          namespace: 'legacy',
          alias: 'standard-531-v1',
        ),
        CatalogId('standard-cycle'),
      );
      expect(
        await repository.resolveAlias(
          catalogVersionId: CatalogId('catalog-v1'),
          namespace: 'legacy',
          alias: 'unknown',
        ),
        isNull,
      );
    },
  );

  test('rejects missing executable child evidence', () async {
    await _insertCycleGraph(database, includeMovementEvidence: false);
    await _publish(database);

    await expectLater(
      SqliteCatalogSnapshotRepository(
        database: database,
        codec: const _FixtureCodec(),
      ).load(CatalogId('catalog-v1')),
      throwsA(
        isA<CatalogSnapshotLoadException>().having(
          (error) => error.code,
          'code',
          'evidence.missing',
        ),
      ),
    );
  });

  test('rejects an executable variant without a cycle V5 binding', () async {
    await _insertCycleGraph(database, engineKind: 'forever');
    await _publish(database);

    await expectLater(
      SqliteCatalogSnapshotRepository(
        database: database,
        codec: const GenericEngineSqliteCodec(),
      ).load(CatalogId('catalog-v1')),
      throwsA(
        isA<CatalogSnapshotLoadException>().having(
          (error) => error.code,
          'code',
          'engine_binding.cycle_v5_missing',
        ),
      ),
    );
  });

  test('fails closed for a decoded port unsupported by cycle V5', () async {
    await _insertCycleGraph(database, portKind: 'schedule');
    await _publish(database);

    await expectLater(
      SqliteCatalogSnapshotRepository(
        database: database,
        codec: const GenericEngineSqliteCodec(),
      ).load(CatalogId('catalog-v1')),
      throwsA(
        isA<CatalogSnapshotLoadException>().having(
          (error) => error.code,
          'code',
          'module.port_unsupported',
        ),
      ),
    );
  });
}

final class _FixtureCodec implements CatalogSnapshotCodec {
  const _FixtureCodec();

  @override
  List<ParameterDefinition> decodeParameterSchema(String source) => [
    ParameterDefinition(
      id: CatalogId('main-movement'),
      kind: ParameterKind.movement,
      allowedIds: {CatalogId('back-squat')},
    ),
  ];

  @override
  DeclarativeRule decodeDeclarativeRule(
    String source, {
    required CatalogId id,
    required DeclarativeRuleKind kind,
  }) => DeclarativeRule(
    id: id,
    kind: kind,
    expression: const AlwaysCondition(true),
    message: 'test.rule',
  );

  @override
  ModuleDefinition decodeModuleDefinition(
    String source, {
    required CatalogId id,
    required int revision,
    required CatalogGovernance governance,
    CatalogEvidence? evidence,
  }) {
    return ModuleDefinition(
      id: id,
      revision: revision,
      governance: governance,
      requiredMovementCapabilities: {CatalogId('barbell-squat')},
      requiredEquipment: {CatalogId('barbell')},
      supportedLoadKinds: {LoadKind.percentTrainingMax},
      inputPorts: [
        ModulePort(id: CatalogId('movement'), kind: ModulePortKind.movement),
      ],
      outputPorts: const [],
      evidence: evidence,
    );
  }

  @override
  ModuleBinding decodeModuleBindingConfiguration(
    String source, {
    required CatalogId id,
    required CatalogId moduleId,
    required int moduleRevision,
  }) => ModuleBinding(
    id: id,
    moduleId: moduleId,
    moduleRevision: moduleRevision,
    inputs: [
      PortBinding(
        portId: CatalogId('movement'),
        kind: ModulePortKind.movement,
        targetId: CatalogId('back-squat'),
      ),
    ],
    requiredMovementCapabilities: {CatalogId('barbell-squat')},
  );
}

Future<void> _insertCycleGraph(
  Database database, {
  bool includeMovementEvidence = true,
  String portKind = 'movement',
  String engineKind = 'cycleV5',
}) async {
  await database.insert('catalog_versions', {
    'id': 'catalog-v1',
    'ordinal': 1,
    'status': 'draft',
    'content_hash': '0' * 64,
    'canonicalization_version': 1,
    'signature_verified': 0,
    'trust_channel': 'bundled',
    'created_at': '2026-07-21T00:00:00Z',
  });
  await database.insert('sources', {
    'id': 'source-one',
    'revision': 1,
    'kind': 'reviewedRepository',
    'locator': 'test/fixtures/catalog-v1.json',
    'note': 'Fictitious test evidence.',
  });
  await database.insert(
    'catalog_entries',
    _entry('entry-template', 'TEST-001', 'standard-cycle'),
  );
  await database.insert(
    'catalog_entries',
    _entry('entry-module', 'TEST-002', 'main-work'),
  );
  await database.insert(
    'catalog_entries',
    _entry('entry-movement', 'TEST-003', 'back-squat'),
  );
  await database.insert('movement_categories', {
    'id': 'category-main',
    'catalog_version_id': 'catalog-v1',
    'stable_key': 'main-lift',
  });
  await database.insert('movements', {
    'id': 'movement-one',
    'catalog_version_id': 'catalog-v1',
    'catalog_entry_id': 'entry-movement',
    'stable_key': 'back-squat',
    'category_id': 'category-main',
    'kind': 'mainLift',
    'body_region': 'lower',
    'load_compatibility_json': '["percentTrainingMax"]',
  });
  await database.insert('movement_capabilities', {
    'id': 'movement-capability-one',
    'catalog_version_id': 'catalog-v1',
    'movement_id': 'movement-one',
    'capability_id': 'barbell-squat',
  });
  await database.insert('modules', {
    'id': 'module-one',
    'stable_key': 'main-work',
    'kind': 'main',
  });
  await database.insert('module_versions', {
    'id': 'module-version-one',
    'catalog_version_id': 'catalog-v1',
    'catalog_entry_id': 'entry-module',
    'module_id': 'module-one',
    'revision': 1,
    'definition_json':
        '''{
      "schemaVersion": 1,
      "requiredMovementCapabilities": ["barbell-squat"],
      "requiredEquipment": ["barbell"],
      "supportedLoadKinds": ["percentTrainingMax"],
      "inputPorts": [{"id":"movement","kind":"$portKind","required":true}],
      "outputPorts": []
    }''',
    'review_status': 'confirmed',
  });
  await database.insert('templates', {
    'id': 'template-one',
    'catalog_version_id': 'catalog-v1',
    'catalog_entry_id': 'entry-template',
    'stable_key': 'standard-cycle',
    'revision': 1,
    'kind': 'cycle',
    'name_key': 'program.standardCycle',
  });
  await database.insert('variants', {
    'id': 'variant-one',
    'catalog_version_id': 'catalog-v1',
    'template_id': 'template-one',
    'stable_key': 'base',
    'status': 'executable',
  });
  await database.insert('engine_bindings', {
    'id': 'engine-binding-one',
    'catalog_version_id': 'catalog-v1',
    'variant_id': 'variant-one',
    'engine_kind': engineKind,
    'engine_id': 'cycle-v5',
    'definition_id': 'standard-cycle',
    'definition_revision': 1,
    'status': 'executable',
  });
  await database.insert('parameter_schemas', {
    'id': 'parameter-schema-one',
    'catalog_version_id': 'catalog-v1',
    'variant_id': 'variant-one',
    'schema_version': 1,
    'schema_json': '''{
      "schemaVersion": 1,
      "parameters": [{
        "id": "main-movement",
        "kind": "movement",
        "allowedIds": ["back-squat"]
      }]
    }''',
  });
  await database.insert('variant_module_bindings', {
    'id': 'main-binding',
    'catalog_version_id': 'catalog-v1',
    'variant_id': 'variant-one',
    'module_version_id': 'module-version-one',
    'role': 'main',
    'sequence': 0,
    'configuration_json':
        '''{
      "schemaVersion": 1,
      "inputs": [{
        "portId": "movement",
        "kind": "$portKind",
        "targetId": "back-squat"
      }],
      "requiredMovementCapabilities": ["barbell-squat"]
    }''',
  });
  await _evidence(
    database,
    id: 'evidence-template',
    type: 'template',
    subjectId: 'template-one',
    ruleId: 'template-rule',
  );
  await _evidence(
    database,
    id: 'evidence-variant',
    type: 'variant',
    subjectId: 'variant-one',
    ruleId: 'variant-rule',
  );
  await _evidence(
    database,
    id: 'evidence-module',
    type: 'moduleVersion',
    subjectId: 'module-version-one',
    ruleId: 'module-rule',
  );
  if (includeMovementEvidence) {
    await _evidence(
      database,
      id: 'evidence-movement',
      type: 'movement',
      subjectId: 'movement-one',
      ruleId: 'movement-rule',
    );
  }
}

Future<void> _insertSecondVariant(Database database) async {
  await database.insert('variants', {
    'id': 'variant-two',
    'catalog_version_id': 'catalog-v1',
    'template_id': 'template-one',
    'stable_key': 'alternate',
    'status': 'executable',
  });
  await database.insert('engine_bindings', {
    'id': 'engine-binding-two',
    'catalog_version_id': 'catalog-v1',
    'variant_id': 'variant-two',
    'engine_kind': 'cycleV5',
    'engine_id': 'cycle-v5-alternate',
    'definition_id': 'standard-cycle',
    'definition_revision': 1,
    'status': 'executable',
  });
  await database.insert('parameter_schemas', {
    'id': 'parameter-schema-two',
    'catalog_version_id': 'catalog-v1',
    'variant_id': 'variant-two',
    'schema_version': 1,
    'schema_json': '''{
      "schemaVersion": 1,
      "parameters": [{"id":"alternate-only","kind":"boolean"}]
    }''',
  });
  await _evidence(
    database,
    id: 'evidence-variant-two',
    type: 'variant',
    subjectId: 'variant-two',
    ruleId: 'variant-two-rule',
  );
}

Future<void> _insertRule(
  Database database, {
  required String id,
  required String kind,
  required String condition,
  String? targetParameterId,
}) async {
  await database.insert('declarative_rules', {
    'id': id,
    'catalog_version_id': 'catalog-v1',
    'owner_type': 'variant',
    'owner_id': 'variant-one',
    'kind': kind,
    'expression_json': jsonEncode({
      'schemaVersion': 1,
      'ruleId': id,
      'kind': kind,
      'condition': jsonDecode(condition),
      'messageKey': 'genericEngine.rules.${id.replaceAll('-', 'X')}',
      'targetParameterId': ?targetParameterId,
    }),
    'schema_version': 1,
    'review_status': 'confirmed',
  });
  await _evidence(
    database,
    id: 'evidence-$id',
    type: 'rule',
    subjectId: id,
    ruleId: id,
  );
}

Map<String, Object?> _entry(String id, String key, String stableId) => {
  'id': id,
  'catalog_version_id': 'catalog-v1',
  'catalog_entry_key': key,
  'stable_domain_id': stableId,
  'nature': 'component',
  'authority': 'canonical',
  'review_status': 'confirmed',
  'implementation_status': 'implemented',
  'execution_status': 'executable',
  'product_surface': 'cycle',
  'visibility': 'visible',
  'license_status': 'compatible',
};

Future<void> _evidence(
  Database database, {
  required String id,
  required String type,
  required String subjectId,
  required String ruleId,
}) => database.insert('evidence', {
  'id': id,
  'catalog_version_id': 'catalog-v1',
  'source_id': 'source-one',
  'rule_id': ruleId,
  'subject_type': type,
  'subject_id': subjectId,
  'review_status': 'confirmed',
  'note': 'Fictitious test evidence.',
});

Future<void> _publish(
  Database database, {
  bool preservePlaceholderHash = false,
}) async {
  final actualHash = await const CatalogPublicationService().computeContentHash(
    database,
    catalogVersionId: 'catalog-v1',
  );
  final storedHash = preservePlaceholderHash ? '0' * 64 : actualHash;
  await database.update(
    'catalog_versions',
    {'content_hash': storedHash},
    where: 'id=?',
    whereArgs: ['catalog-v1'],
  );
  await database.insert('catalog_publication_validations', {
    'catalog_version_id': 'catalog-v1',
    'validated_content_hash': storedHash,
    'evidence_valid': 1,
    'licences_valid': 1,
    'dependencies_valid': 1,
    'children_valid': 1,
    'blockers_clear': 1,
    'signature_valid': 0,
    'validated_at': '2026-07-21T01:00:00Z',
  });
  await database.update(
    'catalog_versions',
    {'status': 'inReview'},
    where: 'id=?',
    whereArgs: ['catalog-v1'],
  );
  await database.update(
    'catalog_versions',
    {'status': 'approved'},
    where: 'id=?',
    whereArgs: ['catalog-v1'],
  );
  await database.update(
    'catalog_versions',
    {'status': 'published', 'published_at': '2026-07-21T01:00:00Z'},
    where: 'id=?',
    whereArgs: ['catalog-v1'],
  );
}
