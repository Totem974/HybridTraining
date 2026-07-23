import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../../cycle_generation/application/catalog_plan_resolver.dart';
import 'package:training_engine/features/cycle_generation/domain/catalog_cycle_primitives.dart';
import 'package:training_engine/features/cycle_generation/domain/cycle_contract.dart';
import 'package:training_engine/features/cycle_generation/domain/cycle_option_schema.dart';
import '../application/catalog_repository.dart';
import 'package:training_engine/features/training_catalog/application/option_schema_composer.dart';
import 'package:training_engine/features/training_catalog/domain/catalog_codec.dart';
import 'package:training_engine/features/training_catalog/domain/catalog_index.dart';
import 'package:training_engine/features/training_catalog/domain/catalog_models.dart';
import 'catalog_plan_data_resolver.dart';
import 'catalog_source_document_codec.dart';

final class SqliteTrainingCatalog
    implements TrainingCatalogRepository, CycleCatalogQuery {
  SqliteTrainingCatalog(this.database);

  static const schemaVersion = 1;
  static const databaseSchemaVersion = 2;
  final Database database;

  static Future<void> createSchema(Database db) async {
    await db.execute(
      'CREATE TABLE catalog_metadata(schema_version INTEGER NOT NULL)',
    );
    await db.insert('catalog_metadata', {'schema_version': schemaVersion});
    await db.execute('''CREATE TABLE catalog_versions(
      version INTEGER PRIMARY KEY, status TEXT NOT NULL CHECK(status IN ('draft','published')),
      source_reference TEXT NOT NULL)''');
    await db.execute(
      '''CREATE TABLE catalog_movements(
      version INTEGER NOT NULL, id TEXT NOT NULL, name TEXT NOT NULL,
      PRIMARY KEY(version,id), FOREIGN KEY(version) REFERENCES catalog_versions(version))''',
    );
    await db.execute(
      '''CREATE TABLE catalog_templates(
      version INTEGER NOT NULL, id TEXT NOT NULL, name TEXT NOT NULL,
      PRIMARY KEY(version,id), FOREIGN KEY(version) REFERENCES catalog_versions(version))''',
    );
    await db.execute(
      '''CREATE TABLE catalog_variants(
      version INTEGER NOT NULL, template_id TEXT NOT NULL, id TEXT NOT NULL, name TEXT NOT NULL,
      PRIMARY KEY(version,template_id,id),
      FOREIGN KEY(version,template_id) REFERENCES catalog_templates(version,id))''',
    );
    await db.execute(
      '''CREATE TABLE catalog_sessions(
      version INTEGER NOT NULL, template_id TEXT NOT NULL, variant_id TEXT NOT NULL,
      position INTEGER NOT NULL, movement_id TEXT NOT NULL,
      PRIMARY KEY(version,template_id,variant_id,position),
      FOREIGN KEY(version,template_id,variant_id) REFERENCES catalog_variants(version,template_id,id),
      FOREIGN KEY(version,movement_id) REFERENCES catalog_movements(version,id))''',
    );
    await db.execute('''CREATE TABLE catalog_weeks(
      version INTEGER NOT NULL, template_id TEXT NOT NULL, variant_id TEXT NOT NULL,
      week_number INTEGER NOT NULL,
      PRIMARY KEY(version,template_id,variant_id,week_number),
      FOREIGN KEY(version,template_id,variant_id)
        REFERENCES catalog_variants(version,template_id,id))''');
    await db.execute(
      '''CREATE TABLE catalog_blocks(
      version INTEGER NOT NULL, template_id TEXT NOT NULL, variant_id TEXT NOT NULL,
      week_number INTEGER NOT NULL, position INTEGER NOT NULL, id TEXT NOT NULL, role TEXT NOT NULL,
      PRIMARY KEY(version,template_id,variant_id,week_number,position),
      FOREIGN KEY(version,template_id,variant_id,week_number)
        REFERENCES catalog_weeks(version,template_id,variant_id,week_number))''',
    );
    await db.execute(
      '''CREATE TABLE catalog_sets(
      version INTEGER NOT NULL, template_id TEXT NOT NULL, variant_id TEXT NOT NULL,
      week_number INTEGER NOT NULL, block_position INTEGER NOT NULL, position INTEGER NOT NULL,
      repetitions_json TEXT NOT NULL, load_json TEXT NOT NULL,
      PRIMARY KEY(version,template_id,variant_id,week_number,block_position,position),
      FOREIGN KEY(version,template_id,variant_id,week_number,block_position)
        REFERENCES catalog_blocks(version,template_id,variant_id,week_number,position))''',
    );
    await db.execute(
      '''CREATE TABLE catalog_components(
      version INTEGER NOT NULL, id TEXT NOT NULL, block_json TEXT NOT NULL, rule_ids_json TEXT NOT NULL,
      PRIMARY KEY(version,id), FOREIGN KEY(version) REFERENCES catalog_versions(version))''',
    );
    await db.execute(
      '''CREATE TABLE catalog_rules(
      version INTEGER NOT NULL, rule_id TEXT NOT NULL, work TEXT NOT NULL,
      edition TEXT NOT NULL, section TEXT NOT NULL, review_status TEXT NOT NULL
        CHECK(review_status IN ('reviewed','pending')),
      PRIMARY KEY(version,rule_id), FOREIGN KEY(version) REFERENCES catalog_versions(version))''',
    );
    await db.execute(
      '''CREATE TABLE catalog_variant_week_components(
      version INTEGER NOT NULL, template_id TEXT NOT NULL, variant_id TEXT NOT NULL,
      week_number INTEGER NOT NULL, position INTEGER NOT NULL, component_id TEXT NOT NULL,
      PRIMARY KEY(version,template_id,variant_id,week_number,position),
      FOREIGN KEY(version,component_id) REFERENCES catalog_components(version,id))''',
    );
    await _createCompleteCatalogTables(db);
    // Stable catalog vocabulary. Tables outside the first vertical slice are
    // intentionally empty until a concrete feature needs their columns.
    await db.execute(
      'CREATE TABLE sources(id TEXT PRIMARY KEY, reference TEXT NOT NULL)',
    );
    await db.execute('CREATE TABLE movements(id TEXT PRIMARY KEY)');
    await db.execute('CREATE TABLE components(id TEXT PRIMARY KEY)');
    await db.execute(
      'CREATE TABLE component_versions(id TEXT NOT NULL, version INTEGER NOT NULL, PRIMARY KEY(id,version))',
    );
    await db.execute('CREATE TABLE templates(id TEXT PRIMARY KEY)');
    await db.execute(
      'CREATE TABLE variants(id TEXT PRIMARY KEY, template_id TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE variant_components(variant_id TEXT NOT NULL, position INTEGER NOT NULL, component_id TEXT NOT NULL, PRIMARY KEY(variant_id,position))',
    );
    await db.execute('CREATE TABLE schedules(id TEXT PRIMARY KEY)');
    await db.execute(
      'CREATE TABLE schedule_sessions(schedule_id TEXT NOT NULL, position INTEGER NOT NULL, PRIMARY KEY(schedule_id,position))',
    );
    await db.execute(
      'CREATE TABLE schedule_blocks(schedule_id TEXT NOT NULL, session_position INTEGER NOT NULL, position INTEGER NOT NULL, PRIMARY KEY(schedule_id,session_position,position))',
    );
    await db.execute(
      'CREATE TABLE prescriptions(id TEXT PRIMARY KEY, payload_json TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE option_schemas(id TEXT PRIMARY KEY, payload_json TEXT NOT NULL)',
    );
    await db.execute('CREATE TABLE assistance_plans(id TEXT PRIMARY KEY)');
    await db.execute(
      'CREATE TABLE assistance_slots(plan_id TEXT NOT NULL, position INTEGER NOT NULL, PRIMARY KEY(plan_id,position))',
    );
    await db.execute(
      'CREATE TABLE conditioning_definitions(id TEXT PRIMARY KEY)',
    );
    await db.execute('CREATE TABLE forever_definitions(id TEXT PRIMARY KEY)');
    for (final table in [
      'catalog_versions',
      'catalog_movements',
      'catalog_templates',
      'catalog_variants',
      'catalog_sessions',
      'catalog_weeks',
      'catalog_blocks',
      'catalog_sets',
      'catalog_components',
      'catalog_rules',
      'catalog_variant_week_components',
      'catalog_inventory',
      'catalog_option_schemas',
      'catalog_schedules_v2',
      'catalog_variant_metadata',
      'catalog_library_entries',
    ]) {
      await db.execute(
        '''CREATE TRIGGER ${table}_published_update BEFORE UPDATE ON $table
        WHEN (SELECT status FROM catalog_versions WHERE version=OLD.version)='published'
        BEGIN SELECT RAISE(ABORT, 'published catalog version is immutable'); END''',
      );
      await db.execute(
        '''CREATE TRIGGER ${table}_published_delete BEFORE DELETE ON $table
        WHEN (SELECT status FROM catalog_versions WHERE version=OLD.version)='published'
        BEGIN SELECT RAISE(ABORT, 'published catalog version is immutable'); END''',
      );
    }
    for (final table in [
      'catalog_movements',
      'catalog_templates',
      'catalog_variants',
      'catalog_sessions',
      'catalog_weeks',
      'catalog_blocks',
      'catalog_sets',
      'catalog_components',
      'catalog_rules',
      'catalog_variant_week_components',
      'catalog_inventory',
      'catalog_option_schemas',
      'catalog_schedules_v2',
      'catalog_variant_metadata',
      'catalog_library_entries',
    ]) {
      await db.execute(
        '''CREATE TRIGGER ${table}_published_insert BEFORE INSERT ON $table
        WHEN (SELECT status FROM catalog_versions WHERE version=NEW.version)='published'
        BEGIN SELECT RAISE(ABORT, 'published catalog version is immutable'); END''',
      );
    }
  }

  static Future<void> _createCompleteCatalogTables(Database db) async {
    await db.execute(
      '''CREATE TABLE catalog_inventory(
      version INTEGER NOT NULL, id TEXT NOT NULL, generation TEXT NOT NULL,
      classification TEXT NOT NULL, title TEXT NOT NULL, cycle_template_id TEXT,
      source_rule_ids_json TEXT NOT NULL,
      PRIMARY KEY(version,id), FOREIGN KEY(version) REFERENCES catalog_versions(version))''',
    );
    await db.execute(
      '''CREATE TABLE catalog_option_schemas(
      version INTEGER NOT NULL, id TEXT NOT NULL, revision INTEGER NOT NULL,
      payload_json TEXT NOT NULL,
      PRIMARY KEY(version,id), FOREIGN KEY(version) REFERENCES catalog_versions(version))''',
    );
    await db.execute(
      '''CREATE TABLE catalog_schedules_v2(
      version INTEGER NOT NULL, id TEXT NOT NULL, revision INTEGER NOT NULL,
      payload_json TEXT NOT NULL,
      PRIMARY KEY(version,id), FOREIGN KEY(version) REFERENCES catalog_versions(version))''',
    );
    await db.execute('''CREATE TABLE catalog_variant_metadata(
      version INTEGER NOT NULL, template_id TEXT NOT NULL, variant_id TEXT NOT NULL,
      revision INTEGER NOT NULL, labels_json TEXT NOT NULL, source_rule_ids_json TEXT NOT NULL,
      option_schema_id TEXT NOT NULL, schedule_ids_json TEXT NOT NULL,
      compatibility_json TEXT NOT NULL, valid_example_json TEXT NOT NULL,
      PRIMARY KEY(version,template_id,variant_id),
      FOREIGN KEY(version,template_id,variant_id)
        REFERENCES catalog_variants(version,template_id,id),
      FOREIGN KEY(version,option_schema_id)
        REFERENCES catalog_option_schemas(version,id))''');
    await db.execute(
      '''CREATE TABLE catalog_library_entries(
      version INTEGER NOT NULL, kind TEXT NOT NULL, id TEXT NOT NULL,
      revision INTEGER NOT NULL, payload_json TEXT NOT NULL,
      PRIMARY KEY(version,kind,id), FOREIGN KEY(version) REFERENCES catalog_versions(version))''',
    );
  }

  static Future<void> upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await _createCompleteCatalogTables(db);
    }
  }

  Future<void> installSeed(String json) async {
    final seed = CatalogCodec().decode(json);
    if (seed.schemaVersion != schemaVersion) {
      throw CatalogFormatException(
        'Unsupported schemaVersion ${seed.schemaVersion}',
      );
    }
    final movementIds = seed.movements.map((movement) => movement.id).toSet();
    for (final template in seed.templates) {
      for (final variant in template.variants) {
        for (final movementId in variant.sessionMovementIds) {
          if (!movementIds.contains(movementId)) {
            throw CatalogFormatException(
              'Unknown movement reference $movementId',
            );
          }
        }
      }
    }
    await database.transaction((txn) async {
      await txn.insert('catalog_versions', {
        'version': seed.catalogVersion,
        'status': 'draft',
        'source_reference': seed.sourceReference,
      });
      for (final component in seed.components) {
        await txn.insert('catalog_components', {
          'version': seed.catalogVersion,
          'id': component.id,
          'block_json': jsonEncode(_blockJson(component.block)),
          'rule_ids_json': jsonEncode(component.ruleIds),
        });
      }
      for (final rule in seed.rules) {
        await txn.insert('catalog_rules', {
          'version': seed.catalogVersion,
          'rule_id': rule.ruleId,
          'work': rule.work,
          'edition': rule.edition,
          'section': rule.section,
          'review_status': rule.reviewStatus,
        });
      }
      for (final movement in seed.movements) {
        await txn.insert('catalog_movements', {
          'version': seed.catalogVersion,
          'id': movement.id,
          'name': movement.name,
        });
      }
      for (final template in seed.templates) {
        await txn.insert('catalog_templates', {
          'version': seed.catalogVersion,
          'id': template.id,
          'name': template.name,
        });
        for (final variant in template.variants) {
          await txn.insert('catalog_variants', {
            'version': seed.catalogVersion,
            'template_id': template.id,
            'id': variant.id,
            'name': variant.name,
          });
          for (var i = 0; i < variant.sessionMovementIds.length; i++) {
            await txn.insert('catalog_sessions', {
              'version': seed.catalogVersion,
              'template_id': template.id,
              'variant_id': variant.id,
              'position': i,
              'movement_id': variant.sessionMovementIds[i],
            });
          }
          for (final week in variant.weeks) {
            await txn.insert('catalog_weeks', {
              'version': seed.catalogVersion,
              'template_id': template.id,
              'variant_id': variant.id,
              'week_number': week.number,
            });
            final sourceWeek =
                variant.componentIdsByWeek[week.number] ?? const <String>[];
            for (var c = 0; c < sourceWeek.length; c++) {
              await txn.insert('catalog_variant_week_components', {
                'version': seed.catalogVersion,
                'template_id': template.id,
                'variant_id': variant.id,
                'week_number': week.number,
                'position': c,
                'component_id': sourceWeek[c],
              });
            }
            for (var b = 0; b < week.blocks.length; b++) {
              final block = week.blocks[b];
              await txn.insert('catalog_blocks', {
                'version': seed.catalogVersion,
                'template_id': template.id,
                'variant_id': variant.id,
                'week_number': week.number,
                'position': b,
                'id': block.id,
                'role': block.role,
              });
              for (var s = 0; s < block.sets.length; s++) {
                await txn.insert('catalog_sets', {
                  'version': seed.catalogVersion,
                  'template_id': template.id,
                  'variant_id': variant.id,
                  'week_number': week.number,
                  'block_position': b,
                  'position': s,
                  'repetitions_json': jsonEncode(
                    block.sets[s].repetitions.toJson(),
                  ),
                  'load_json': jsonEncode(
                    encodeCatalogLoadPrescription(block.sets[s].load),
                  ),
                });
              }
            }
          }
        }
      }
      if (seed.status == 'published') {
        await txn.update(
          'catalog_versions',
          {'status': 'published'},
          where: 'version=?',
          whereArgs: [seed.catalogVersion],
        );
      } else if (seed.status != 'draft') {
        throw CatalogFormatException('Unknown catalog status ${seed.status}');
      }
    });
  }

  @override
  Future<CycleCatalogIndex> loadIndex({required int catalogVersion}) async {
    await _requirePublished(catalogVersion);
    final templates = await database.query(
      'catalog_templates',
      where: 'version=?',
      whereArgs: [catalogVersion],
      orderBy: 'id',
    );
    final summaries = <CycleTemplateSummary>[];
    for (final template in templates) {
      final templateId = template['id']! as String;
      final definitionRows = await database.query(
        'catalog_library_entries',
        columns: ['payload_json'],
        where: 'version=? AND kind=? AND id=?',
        whereArgs: [catalogVersion, 'template_definition', templateId],
        limit: 1,
      );
      if (definitionRows.isNotEmpty) {
        final definition = _jsonMap(
          definitionRows.single['payload_json']! as String,
          'template definition',
        );
        if (definition['surface'] == 'foreverInternal') continue;
      }
      final variants = await database.query(
        'catalog_variants',
        where: 'version=? AND template_id=?',
        whereArgs: [catalogVersion, templateId],
        orderBy: 'id',
      );
      var labelEn = template['name']! as String;
      var labelFr = labelEn;
      var revision = 1;
      if (variants.isNotEmpty) {
        final metadata = await database.query(
          'catalog_variant_metadata',
          where: 'version=? AND template_id=?',
          whereArgs: [catalogVersion, templateId],
          limit: 1,
        );
        if (metadata.isNotEmpty) {
          revision = metadata.single['revision']! as int;
          final labels = _jsonMap(
            metadata.single['labels_json']! as String,
            'template labels',
          );
          labelEn = labels['en'] as String? ?? labelEn;
          labelFr = labels['fr'] as String? ?? labelEn;
        }
      }
      summaries.add(
        CycleTemplateSummary(
          id: templateId,
          revision: revision,
          labelEn: labelEn,
          labelFr: labelFr,
          variantIds: variants
              .map((row) => row['id']! as String)
              .toList(growable: false),
        ),
      );
    }
    return CycleCatalogIndex(
      catalogVersion: catalogVersion,
      templates: summaries,
    );
  }

  @override
  Future<CycleEditorSchema> loadEditorSchema({
    required int catalogVersion,
    required String templateId,
    required String variantId,
  }) async {
    await _requirePublished(catalogVersion);
    final selection = await _canonicalSelection(
      catalogVersion: catalogVersion,
      templateId: templateId,
      variantId: variantId,
    );
    templateId = selection.templateId;
    variantId = selection.variantId;
    final metadata = await database.query(
      'catalog_variant_metadata',
      where: 'version=? AND template_id=? AND variant_id=?',
      whereArgs: [catalogVersion, templateId, variantId],
      limit: 1,
    );
    if (metadata.isEmpty) {
      throw CatalogNotFoundException(
        'Missing editor metadata for $templateId/$variantId',
      );
    }
    final schemaId = metadata.single['option_schema_id']! as String;
    final parameters = await _composedOptionParameters(
      catalogVersion: catalogVersion,
      schemaId: schemaId,
    );
    return CycleEditorSchema(
      id: schemaId,
      templateId: templateId,
      variantId: variantId,
      options: parameters
          .map((value) => _decodeOption(value))
          .toList(growable: false),
    );
  }

  Future<void> createDraftFromPublished({
    required int sourceVersion,
    required int draftVersion,
  }) async {
    await database.transaction((txn) async {
      final source = await txn.query(
        'catalog_versions',
        where: 'version=? AND status=?',
        whereArgs: [sourceVersion, 'published'],
      );
      if (source.isEmpty) throw CatalogNotPublishedException(sourceVersion);
      await txn.insert('catalog_versions', {
        'version': draftVersion,
        'status': 'draft',
        'source_reference': source.single['source_reference'],
      });
      for (final table in const {
        'catalog_movements': ['id', 'name'],
        'catalog_templates': ['id', 'name'],
        'catalog_variants': ['template_id', 'id', 'name'],
        'catalog_sessions': [
          'template_id',
          'variant_id',
          'position',
          'movement_id',
        ],
        'catalog_weeks': ['template_id', 'variant_id', 'week_number'],
        'catalog_blocks': [
          'template_id',
          'variant_id',
          'week_number',
          'position',
          'id',
          'role',
        ],
        'catalog_sets': [
          'template_id',
          'variant_id',
          'week_number',
          'block_position',
          'position',
          'repetitions_json',
          'load_json',
        ],
        'catalog_components': ['id', 'block_json', 'rule_ids_json'],
        'catalog_rules': [
          'rule_id',
          'work',
          'edition',
          'section',
          'review_status',
        ],
        'catalog_variant_week_components': [
          'template_id',
          'variant_id',
          'week_number',
          'position',
          'component_id',
        ],
        'catalog_inventory': [
          'id',
          'generation',
          'classification',
          'title',
          'cycle_template_id',
          'source_rule_ids_json',
        ],
        'catalog_option_schemas': ['id', 'revision', 'payload_json'],
        'catalog_schedules_v2': ['id', 'revision', 'payload_json'],
        'catalog_library_entries': ['kind', 'id', 'revision', 'payload_json'],
        'catalog_variant_metadata': [
          'template_id',
          'variant_id',
          'revision',
          'labels_json',
          'source_rule_ids_json',
          'option_schema_id',
          'schedule_ids_json',
          'compatibility_json',
          'valid_example_json',
        ],
      }.entries) {
        final columns = table.value.join(',');
        await txn.execute(
          'INSERT INTO ${table.key}(version,$columns) SELECT ?,$columns FROM ${table.key} WHERE version=?',
          [draftVersion, sourceVersion],
        );
      }
    });
  }

  Future<void> validateDraft(int version) async {
    await database.transaction((txn) => _validateDraft(txn, version));
  }

  Future<void> publishDraft(int version) async {
    await database.transaction((txn) async {
      await _validateDraft(txn, version);
      await txn.update(
        'catalog_versions',
        {'status': 'published'},
        where: 'version=? AND status=?',
        whereArgs: [version, 'draft'],
      );
    });
  }

  @override
  Future<void> validateMovementReferences({
    required int catalogVersion,
    required Set<MovementId> movementIds,
  }) async {
    final versions = await database.query(
      'catalog_versions',
      columns: ['status'],
      where: 'version=?',
      whereArgs: [catalogVersion],
    );
    if (versions.isEmpty) {
      throw CatalogNotFoundException('Unknown catalog version $catalogVersion');
    }
    if (versions.single['status'] != 'published') {
      throw CatalogNotPublishedException(catalogVersion);
    }
    if (movementIds.isEmpty) return;
    final rows = await database.query(
      'catalog_movements',
      columns: ['id'],
      where: 'version=?',
      whereArgs: [catalogVersion],
    );
    final existing = rows.map((row) => row['id']! as String).toSet();
    final missing = movementIds.where((id) => !existing.contains(id.value));
    if (missing.isNotEmpty) {
      throw CatalogNotFoundException(
        'Unknown movement reference ${missing.first.value} in catalog version $catalogVersion',
      );
    }
  }

  Future<void> _requirePublished(int version) async {
    final rows = await database.query(
      'catalog_versions',
      columns: ['status'],
      where: 'version=?',
      whereArgs: [version],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw CatalogNotFoundException('Unknown catalog version $version');
    }
    if (rows.single['status'] != 'published') {
      throw CatalogNotPublishedException(version);
    }
  }

  static CycleOptionDefinition _decodeOption(Map<String, Object?> map) {
    _exactKeys(
      map,
      const {
        'id',
        'type',
        'scope',
        'default',
        'minimum',
        'maximum',
        'step',
        'allowedValues',
        'visibleWhen',
        'enabledWhen',
        'requiredWhen',
      },
      optional: const {'presentationGroup', 'labelEn', 'labelFr'},
    );
    final allowed = map['allowedValues'];
    if (allowed is! List<Object?>) {
      throw const CatalogFormatException('allowedValues must be a list');
    }
    return CycleOptionDefinition(
      id: map['id']! as String,
      type: CycleOptionType.values.byName(map['type']! as String),
      scope: CycleOptionScope.values.byName(map['scope']! as String),
      defaultValue: map['default']!,
      minimum: map['minimum'] as num?,
      maximum: map['maximum'] as num?,
      step: map['step'] as num?,
      allowedValues: List<Object>.unmodifiable(allowed.whereType<Object>()),
      visibleWhen: _decodeCondition(
        _objectMap(map['visibleWhen'], 'visibleWhen'),
      ),
      enabledWhen: _decodeCondition(
        _objectMap(map['enabledWhen'], 'enabledWhen'),
      ),
      requiredWhen: _decodeCondition(
        _objectMap(map['requiredWhen'], 'requiredWhen'),
      ),
      presentationGroup: CycleOptionPresentationGroup.values.byName(
        map['presentationGroup'] as String? ?? 'supplemental',
      ),
      labelEn: map['labelEn'] as String? ?? '',
      labelFr: map['labelFr'] as String? ?? '',
    );
  }

  static CycleOptionCondition _decodeCondition(Map<String, Object?> map) {
    final type = map['type'];
    if (type is! String) {
      throw const CatalogFormatException('Condition type must be a string');
    }
    switch (type) {
      case 'always':
        _allowedKeys(map, const {'type', 'value'});
        return AlwaysCondition(map['value'] as bool? ?? true);
      case 'present':
        _conditionKeys(map, const {'type'});
        return PresentCondition(_conditionOptionId(map));
      case 'equals':
        _conditionKeys(map, const {'type', 'value'});
        return EqualsCondition(_conditionOptionId(map), map['value']!);
      case 'not':
        _exactKeys(map, const {'type', 'condition'});
        return NotCondition(
          _decodeCondition(_objectMap(map['condition'], 'condition')),
        );
      case 'all':
      case 'any':
        _exactKeys(map, const {'type', 'conditions'});
        final values = map['conditions'];
        if (values is! List<Object?>) {
          throw const CatalogFormatException('conditions must be a list');
        }
        final conditions = values
            .map((value) => _decodeCondition(_objectMap(value, 'condition')))
            .toList(growable: false);
        return type == 'all'
            ? AllCondition(conditions)
            : AnyCondition(conditions);
      case 'in':
        _conditionKeys(map, const {'type', 'values'});
        final values = map['values'];
        if (values is! List<Object?>) {
          throw const CatalogFormatException('values must be a list');
        }
        return InCondition(
          _conditionOptionId(map),
          List<Object>.unmodifiable(values.whereType<Object>()),
        );
      case 'range':
        _conditionKeys(map, const {'type', 'minimum', 'maximum'});
        return RangeCondition(
          _conditionOptionId(map),
          minimum: map['minimum']! as num,
          maximum: map['maximum']! as num,
        );
      default:
        throw CatalogFormatException('Unknown condition type $type');
    }
  }

  static void _conditionKeys(Map<String, Object?> map, Set<String> expected) {
    _allowedKeys(map, {...expected, 'optionId', 'parameterId'});
    if (!map.keys.toSet().containsAll(expected)) {
      throw const CatalogFormatException('Unexpected object keys');
    }
    _conditionOptionId(map);
  }

  static String _conditionOptionId(Map<String, Object?> map) {
    final optionId = map['parameterId'] ?? map['optionId'];
    if (optionId is! String ||
        optionId.isEmpty ||
        (map.containsKey('parameterId') && map.containsKey('optionId'))) {
      throw const CatalogFormatException('Condition option id is invalid');
    }
    return optionId;
  }

  static Map<String, Object?> _jsonMap(String source, String label) =>
      _objectMap(jsonDecode(source), label);

  static Map<String, Object?> _objectMap(Object? value, String label) =>
      value is Map<String, Object?>
      ? value
      : throw CatalogFormatException('$label must be an object');

  static void _exactKeys(
    Map<String, Object?> map,
    Set<String> expected, {
    Set<String> optional = const {},
  }) {
    final allowed = {...expected, ...optional};
    if (map.keys.toSet().difference(allowed).isNotEmpty ||
        expected.difference(map.keys.toSet()).isNotEmpty) {
      throw const CatalogFormatException('Unexpected object keys');
    }
  }

  static void _allowedKeys(Map<String, Object?> map, Set<String> allowed) {
    if (map.keys.toSet().difference(allowed).isNotEmpty) {
      throw const CatalogFormatException('Unexpected object keys');
    }
  }

  static Future<void> _validateDraft(DatabaseExecutor db, int version) async {
    final rows = await db.query(
      'catalog_versions',
      where: 'version=?',
      whereArgs: [version],
    );
    if (rows.isEmpty) {
      throw CatalogNotFoundException('Unknown catalog version $version');
    }
    if (rows.single['status'] != 'draft') {
      throw CatalogVersionImmutableException(version);
    }
    final orphan = _firstIntValue(
      await db.rawQuery(
        '''SELECT COUNT(*) FROM catalog_variant_week_components r
      LEFT JOIN catalog_components c ON c.version=r.version AND c.id=r.component_id
      WHERE r.version=? AND c.id IS NULL''',
        [version],
      ),
    );
    if (orphan != 0) {
      throw CatalogFormatException(
        'Catalog version $version has missing component dependencies',
      );
    }
    final missingOptionSchema = _firstIntValue(
      await db.rawQuery(
        '''SELECT COUNT(*) FROM catalog_variant_metadata m
        LEFT JOIN catalog_option_schemas o
          ON o.version=m.version AND o.id=m.option_schema_id
        WHERE m.version=? AND o.id IS NULL''',
        [version],
      ),
    );
    if (missingOptionSchema != 0) {
      throw CatalogFormatException(
        'Catalog version $version has missing option schemas',
      );
    }
    final knownRules = (await db.query(
      'catalog_rules',
      columns: ['rule_id'],
      where: 'version=?',
      whereArgs: [version],
    )).map((row) => row['rule_id']! as String).toSet();
    final components = await db.query(
      'catalog_components',
      columns: ['rule_ids_json'],
      where: 'version=?',
      whereArgs: [version],
    );
    for (final component in components) {
      final ids = jsonDecode(component['rule_ids_json']! as String);
      if (ids is! List<Object?> ||
          ids.any((id) => id is! String || !knownRules.contains(id))) {
        throw CatalogFormatException(
          'Catalog version $version has missing rule dependencies',
        );
      }
    }
  }

  @override
  Future<ResolvedCycleDefinition> resolve({
    required int catalogVersion,
    required String templateId,
    required String variantId,
  }) async {
    return resolveWithOptions(
      catalogVersion: catalogVersion,
      templateId: templateId,
      variantId: variantId,
    );
  }

  Future<ResolvedCycleDefinition> resolveWithOptions({
    required int catalogVersion,
    required String templateId,
    required String variantId,
    Map<String, Object?> optionValues = const {},
  }) async {
    final metadata = await database.query('catalog_metadata', limit: 1);
    final actualSchema = metadata.single['schema_version'] as int;
    if (actualSchema != schemaVersion) {
      throw CatalogFormatException(
        'Unsupported database schemaVersion $actualSchema',
      );
    }
    final versions = await database.query(
      'catalog_versions',
      where: 'version=?',
      whereArgs: [catalogVersion],
    );
    if (versions.isEmpty) {
      throw CatalogNotFoundException('Unknown catalog version $catalogVersion');
    }
    if (versions.single['status'] != 'published') {
      throw CatalogNotPublishedException(catalogVersion);
    }
    final selection = await _canonicalSelection(
      catalogVersion: catalogVersion,
      templateId: templateId,
      variantId: variantId,
    );
    templateId = selection.templateId;
    variantId = selection.variantId;
    optionValues = {...selection.optionOverrides, ...optionValues};
    final variants = await database.query(
      'catalog_variants',
      where: 'version=? AND template_id=? AND id=?',
      whereArgs: [catalogVersion, templateId, variantId],
    );
    if (variants.isEmpty) {
      throw CatalogNotFoundException(
        'Unknown template/variant $templateId/$variantId',
      );
    }
    final declarative = await _resolveDeclarativePlan(
      catalogVersion: catalogVersion,
      templateId: templateId,
      variantId: variantId,
      sourceReference: versions.single['source_reference']! as String,
      optionValues: optionValues,
    );
    if (declarative != null) return declarative;
    final sessions = await database.query(
      'catalog_sessions',
      where: 'version=? AND template_id=? AND variant_id=?',
      whereArgs: [catalogVersion, templateId, variantId],
      orderBy: 'position',
    );
    final weekRows = await database.query(
      'catalog_weeks',
      where: 'version=? AND template_id=? AND variant_id=?',
      whereArgs: [catalogVersion, templateId, variantId],
      orderBy: 'week_number',
    );
    final weeks = <WeekDefinition>[];
    for (final weekRow in weekRows) {
      final number = weekRow['week_number'] as int;
      final blockRows = await database.query(
        'catalog_blocks',
        where: 'version=? AND template_id=? AND variant_id=? AND week_number=?',
        whereArgs: [catalogVersion, templateId, variantId, number],
        orderBy: 'position',
      );
      final blocks = <BlockDefinition>[];
      for (final blockRow in blockRows) {
        final position = blockRow['position'] as int;
        final setRows = await database.query(
          'catalog_sets',
          where:
              'version=? AND template_id=? AND variant_id=? AND week_number=? AND block_position=?',
          whereArgs: [catalogVersion, templateId, variantId, number, position],
          orderBy: 'position',
        );
        blocks.add(
          BlockDefinition(
            id: blockRow['id']! as String,
            role: blockRow['role']! as String,
            sets: setRows.map((row) => _decodeSet(row)).toList(growable: false),
          ),
        );
      }
      weeks.add(WeekDefinition(number: number, blocks: blocks));
    }
    return ResolvedCycleDefinition(
      catalogVersion: catalogVersion,
      templateId: templateId,
      variantId: variantId,
      sessionMovementIds: sessions
          .map((row) => MovementId(row['movement_id']! as String))
          .toList(growable: false),
      weeks: weeks,
      sourceReference: versions.single['source_reference']! as String,
    );
  }

  Future<ResolvedCycleDefinition?> _resolveDeclarativePlan({
    required int catalogVersion,
    required String templateId,
    required String variantId,
    required String sourceReference,
    Map<String, Object?> optionValues = const {},
  }) async {
    final templateRows = await database.query(
      'catalog_library_entries',
      columns: ['payload_json'],
      where: 'version=? AND kind=? AND id=?',
      whereArgs: [catalogVersion, 'template_definition', templateId],
      limit: 1,
    );
    if (templateRows.isEmpty) return null;
    const codec = CatalogSourceDocumentCodec();
    final template = codec
        .decodeTemplates(
          jsonEncode({
            'schemaVersion': 1,
            'kind': 'templates',
            'templates': [
              jsonDecode(templateRows.single['payload_json']! as String),
            ],
          }),
        )
        .single;
    final variant = template.variants.singleWhere(
      (item) => item.id == variantId,
      orElse: () => throw CatalogNotFoundException(
        'Unknown template/variant $templateId/$variantId',
      ),
    );
    final scheduleReference = variant.scheduleIds.first;
    final scheduleRows = await database.query(
      'catalog_schedules_v2',
      columns: ['payload_json'],
      where: 'version=? AND id=? AND revision=?',
      whereArgs: [
        catalogVersion,
        scheduleReference.id,
        scheduleReference.revision,
      ],
      limit: 1,
    );
    if (scheduleRows.isEmpty) {
      throw CatalogNotFoundException(
        'Missing schedule ${scheduleReference.id}',
      );
    }
    final schedules = codec.decodeSchedules(
      jsonEncode({
        'schemaVersion': 1,
        'kind': 'schedules',
        'schedules': [
          jsonDecode(scheduleRows.single['payload_json']! as String),
        ],
      }),
    );
    final componentRows = await database.query(
      'catalog_library_entries',
      columns: ['payload_json'],
      where: 'version=? AND kind=?',
      whereArgs: [catalogVersion, 'component_definition'],
      orderBy: 'id',
    );
    final components = codec.decodeComponents(
      jsonEncode({
        'schemaVersion': 1,
        'kind': 'components',
        'components': [
          for (final row in componentRows)
            jsonDecode(row['payload_json']! as String),
        ],
      }),
    );
    final recipeRows = await database.query(
      'catalog_library_entries',
      columns: ['payload_json'],
      where: 'version=? AND kind=?',
      whereArgs: [catalogVersion, 'cycle_option_recipe'],
      orderBy: 'id',
    );
    final optionRecipes = codec.decodeCycleOptionRecipes(
      jsonEncode({
        'schemaVersion': 1,
        'kind': 'cycleOptionRecipes',
        'cycleOptionRecipes': [
          for (final row in recipeRows)
            jsonDecode(row['payload_json']! as String),
        ],
      }),
    );
    final plan = const CatalogPlanDataResolver().resolve(
      catalogVersion: catalogVersion,
      template: template,
      variant: variant,
      scheduleReference: scheduleReference,
      schedules: schedules,
      components: components,
      optionRecipes: optionRecipes,
      optionValues: optionValues,
      optionDefaults: await _optionDefaults(
        catalogVersion: catalogVersion,
        templateId: templateId,
        variantId: variantId,
      ),
      sourceReference: sourceReference,
    );
    return const CatalogPlanResolver().resolve(plan);
  }

  Future<Map<String, Object?>> _optionDefaults({
    required int catalogVersion,
    required String templateId,
    required String variantId,
  }) async {
    final metadata = await database.query(
      'catalog_variant_metadata',
      columns: ['option_schema_id'],
      where: 'version=? AND template_id=? AND variant_id=?',
      whereArgs: [catalogVersion, templateId, variantId],
      limit: 1,
    );
    if (metadata.isEmpty) return const {};
    final parameters = await _composedOptionParameters(
      catalogVersion: catalogVersion,
      schemaId: metadata.single['option_schema_id']! as String,
    );
    return {
      for (final parameter in parameters)
        if (parameter['default'] != null)
          parameter['id']! as String: parameter['default'],
    };
  }

  Future<List<Map<String, Object?>>> _composedOptionParameters({
    required int catalogVersion,
    required String schemaId,
  }) async {
    final rows = await database.query(
      'catalog_option_schemas',
      columns: ['id', 'revision', 'payload_json'],
      where: 'version=?',
      whereArgs: [catalogVersion],
      orderBy: 'id',
    );
    final targetRows = rows.where((row) => row['id'] == schemaId).toList();
    if (targetRows.isEmpty) {
      throw CatalogNotFoundException('Missing option schema $schemaId');
    }
    final schemas = [
      for (final row in rows)
        {
          ..._jsonMap(row['payload_json']! as String, 'option schema'),
          'id': row['id'],
          'revision': row['revision'],
        },
    ];
    try {
      return const OptionSchemaComposer().compose(
        schemas: schemas,
        reference: ComponentReference(
          schemaId,
          targetRows.single['revision']! as int,
        ),
      );
    } on FormatException catch (error) {
      throw CatalogFormatException(error.message.toString());
    }
  }

  Future<_CanonicalSelection> _canonicalSelection({
    required int catalogVersion,
    required String templateId,
    required String variantId,
  }) async {
    final rows = await database.query(
      'catalog_library_entries',
      columns: ['payload_json'],
      where: 'version=? AND kind=? AND id=?',
      whereArgs: [catalogVersion, 'template_alias', '$templateId/$variantId'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return _CanonicalSelection(templateId, variantId, const {});
    }
    final alias = _jsonMap(
      rows.single['payload_json']! as String,
      'template alias',
    );
    return _CanonicalSelection(
      alias['templateId']! as String,
      alias['variantId']! as String,
      Map<String, Object?>.unmodifiable(
        _objectMap(alias['optionOverrides'], 'option overrides'),
      ),
    );
  }

  static PrescribedSetDefinition _decodeSet(Map<String, Object?> row) =>
      const CatalogSourceDocumentCodec()
          .decodeComponents(
            jsonEncode({
              'schemaVersion': 1,
              'kind': 'components',
              'components': [
                {
                  'id': 'sqlite_set_decoder',
                  'revision': 1,
                  'role': 'main_work',
                  'labels': {'en': 'Decoder', 'fr': 'Decoder'},
                  'sourceRuleIds': <Object?>[],
                  'parameterSchemaIds': <Object?>[],
                  'constraints': <String, Object?>{},
                  'compatibilities': <String, Object?>{},
                  'block': {
                    'id': 'sqlite_set_decoder',
                    'role': 'main_work',
                    'sets': [
                      {
                        'repetitions': jsonDecode(
                          row['repetitions_json']! as String,
                        ),
                        'load': jsonDecode(row['load_json']! as String),
                      },
                    ],
                  },
                },
              ],
            }),
          )
          .single
          .block
          .sets
          .single;

  static Map<String, Object> _loadJson(LoadPrescription load) =>
      encodeCatalogLoadPrescription(load);

  static Map<String, Object?> _blockJson(BlockDefinition block) => {
    'id': block.id,
    'role': block.role,
    'movementId': block.movementId?.value,
    'sets': block.sets
        .map(
          (set) => {
            'repetitions': set.repetitions.toJson(),
            'load': _loadJson(set.load),
          },
        )
        .toList(),
  };
}

Map<String, Object> encodeCatalogLoadPrescription(LoadPrescription load) =>
    switch (load) {
      MainWorkSetPlusLoad(:final cumulativeIncreaseBasisPoints) => {
        'type': 'main_work_set_plus',
        'cumulativeIncreaseBasisPoints': cumulativeIncreaseBasisPoints,
      },
      WarmUpBaseLoad(:final region, :final fixedWeight) =>
        fixedWeight != null
            ? {
                'type': 'warm_up_base',
                'centiUnits': fixedWeight.centiUnits,
                'unit': fixedWeight.unit.name,
              }
            : {'type': 'warm_up_base', 'region': region!.name},
      TrainingMaxRampLoad(
        :final anchor,
        :final stepBasisPoints,
        :final lowerBoundStepFractionBasisPoints,
        :final anchorMultiplierBasisPoints,
        :final maximumExclusiveBasisPoints,
      ) =>
        {
          'type': 'training_max_ramp',
          'anchor': switch (anchor) {
            TrainingMaxRampAnchor.beforeMainWork => 'before_main_work',
            TrainingMaxRampAnchor.warmUpBase => 'warm_up_base',
          },
          'stepBasisPoints': stepBasisPoints,
          if (lowerBoundStepFractionBasisPoints != null) ...{
            'lowerBound': 'warm_up_base_plus_step_fraction',
            'lowerBoundStepFractionBasisPoints':
                lowerBoundStepFractionBasisPoints,
          },
          'anchorMultiplierBasisPoints': ?anchorMultiplierBasisPoints,
          'maximumExclusiveBasisPoints': ?maximumExclusiveBasisPoints,
        },
      TrainingMaxPercentageLoad(:final percentage) => {
        'type': 'training_max_percentage',
        'basisPoints': percentage.basisPoints,
      },
      ParameterizedTrainingMaxPercentageLoad(
        :final parameterId,
        :final defaultValue,
        :final minimum,
        :final maximum,
      ) =>
        {
          'type': 'parameterized_training_max_percentage',
          'parameterId': parameterId,
          'defaultBasisPoints': defaultValue.basisPoints,
          'minimumBasisPoints': minimum.basisPoints,
          'maximumBasisPoints': maximum.basisPoints,
        },
      OneRepMaxPercentageLoad(:final percentage) => {
        'type': 'one_rep_max_percentage',
        'basisPoints': percentage.basisPoints,
      },
      FixedLoad(:final weight) => {
        'type': 'fixed',
        'centiUnits': weight.centiUnits,
        'unit': weight.unit.name,
      },
      RelativeSetLoad(:final position, :final multiplierBasisPoints) => {
        'type': 'relative_set',
        'position': position.name,
        'multiplierBasisPoints': multiplierBasisPoints,
      },
      BodyweightLoad() => {'type': 'bodyweight'},
      Unloaded() => {'type': 'unloaded'},
      UnconfiguredLoad() => {'type': 'unconfigured'},
    };

final class _CanonicalSelection {
  const _CanonicalSelection(
    this.templateId,
    this.variantId,
    this.optionOverrides,
  );

  final String templateId;
  final String variantId;
  final Map<String, Object?> optionOverrides;
}

Future<SqliteTrainingCatalog> openCatalogDatabase({
  required DatabaseFactory factory,
  required String path,
  String? seedJson,
}) async {
  final database = await factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: SqliteTrainingCatalog.databaseSchemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
      onCreate: (db, _) => SqliteTrainingCatalog.createSchema(db),
      onUpgrade: SqliteTrainingCatalog.upgradeSchema,
    ),
  );
  final repository = SqliteTrainingCatalog(database);
  if (seedJson != null) {
    final existing = _firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM catalog_versions'),
    );
    if (existing == 0) await repository.installSeed(seedJson);
  }
  return repository;
}

int? _firstIntValue(List<Map<String, Object?>> rows) {
  if (rows.isEmpty || rows.first.isEmpty) return null;
  return rows.first.values.first as int?;
}
