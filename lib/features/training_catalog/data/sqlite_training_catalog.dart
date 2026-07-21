import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../cycle_generation/domain/cycle_contract.dart';
import '../application/catalog_repository.dart';
import '../domain/catalog_codec.dart';
import '../domain/catalog_models.dart';

final class SqliteTrainingCatalog implements TrainingCatalogRepository {
  SqliteTrainingCatalog(this.database);

  static const schemaVersion = 1;
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
    ]) {
      await db.execute(
        '''CREATE TRIGGER ${table}_published_insert BEFORE INSERT ON $table
        WHEN (SELECT status FROM catalog_versions WHERE version=NEW.version)='published'
        BEGIN SELECT RAISE(ABORT, 'published catalog version is immutable'); END''',
      );
    }
  }

  Future<void> installSeed(String json) async {
    final seed = const CatalogCodec().decode(json);
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
                  'load_json': jsonEncode(_loadJson(block.sets[s].load)),
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
  Future<ResolvedCycleDefinition> resolve({
    required int catalogVersion,
    required String templateId,
    required String variantId,
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

  static PrescribedSetDefinition _decodeSet(Map<String, Object?> row) {
    final wrapper = jsonEncode({
      'schemaVersion': 1,
      'catalogVersion': 1,
      'status': 'draft',
      'sourceReference': 'decoder',
      'movements': [],
      'templates': [
        {
          'id': 't',
          'name': 't',
          'variants': [
            {
              'id': 'v',
              'name': 'v',
              'schedule': {'type': 'ordered_sessions', 'movementIds': []},
              'weeks': [
                {
                  'number': 1,
                  'blocks': [
                    {
                      'id': 'b',
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
                  ],
                },
              ],
            },
          ],
        },
      ],
    });
    return const CatalogCodec()
        .decode(wrapper)
        .templates
        .single
        .variants
        .single
        .weeks
        .single
        .blocks
        .single
        .sets
        .single;
  }

  static Map<String, Object> _loadJson(LoadPrescription load) => switch (load) {
    TrainingMaxPercentageLoad(:final percentage) => {
      'type': 'training_max_percentage',
      'basisPoints': percentage.basisPoints,
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
    BodyweightLoad() => {'type': 'bodyweight'},
    Unloaded() => {'type': 'unloaded'},
  };
}

Future<SqliteTrainingCatalog> openCatalogDatabase({
  required DatabaseFactory factory,
  required String path,
  String? seedJson,
}) async {
  final database = await factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: SqliteTrainingCatalog.schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
      onCreate: (db, _) => SqliteTrainingCatalog.createSchema(db),
    ),
  );
  final repository = SqliteTrainingCatalog(database);
  if (seedJson != null) {
    final existing = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM catalog_versions'),
    );
    if (existing == 0) await repository.installSeed(seedJson);
  }
  return repository;
}
