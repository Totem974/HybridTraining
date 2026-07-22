import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/storage/platform_database_factory.dart';
import '../../core/storage/sqlite_database_file.dart';
import '../../features/cycle_generation/data/workspace_database_schema.dart';
import '../../features/cycle_generation/domain/cycle_compiler_impl.dart';
import '../../features/cycle_generation/domain/cycle_contract.dart';
import '../../features/cycle_web/application/cycle_web_application_impl.dart';
import '../../features/cycle_web/application/cycle_web_contract.dart';
import '../../features/cycle_web/data/sqlite_cycle_web_draft_repository.dart';
import '../../features/training_catalog/data/runtime_catalog_publisher.dart';
import '../../features/training_catalog/data/sqlite_training_catalog.dart';
import '../../features/training_log/data/sqlite_training_snapshot_repository.dart';
import '../../features/training_log/data/training_database_schema.dart';

Future<CycleWebApplication> createCycleWebApplication() async {
  final decoded = jsonDecode(
    await rootBundle.loadString('assets/catalog/catalog_seed.v2.json'),
  );
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Invalid published Cycle catalogue seed.');
  }
  final factory = platformDatabaseFactory;
  final catalogFile = SqliteDatabaseFile(
    fileName: 'catalog.db',
    databasePath: 'catalog.db',
    factory: factory,
    version: SqliteTrainingCatalog.databaseSchemaVersion,
    onCreate: (database, _) async {
      await SqliteTrainingCatalog.createSchema(database);
    },
    onUpgrade: SqliteTrainingCatalog.upgradeSchema,
  );
  final workspaceFile = SqliteDatabaseFile(
    fileName: 'workspace.db',
    databasePath: 'workspace.db',
    factory: factory,
    version: WorkspaceDatabaseSchema.version,
    onCreate: WorkspaceDatabaseSchema.create,
    onUpgrade: WorkspaceDatabaseSchema.upgrade,
  );
  final trainingFile = SqliteDatabaseFile(
    fileName: 'training.db',
    databasePath: 'training.db',
    factory: factory,
    version: TrainingDatabaseSchema.version,
    onCreate: TrainingDatabaseSchema.create,
    onUpgrade: TrainingDatabaseSchema.upgrade,
  );

  final catalogDatabase = await catalogFile.open();
  final publishedVersions = await catalogDatabase.query(
    'catalog_versions',
    columns: ['version'],
    where: 'version = ?',
    whereArgs: const [2],
    limit: 1,
  );
  if (publishedVersions.isEmpty) {
    await const RuntimeCatalogPublisher().publish(
      aggregate: decoded,
      database: catalogDatabase,
    );
  }
  final workspaceDatabase = await workspaceFile.open();
  await trainingFile.open();
  await workspaceDatabase.insert('profiles', {
    'id': 'cycle-web-profile',
    'display_name': 'Cycle Web',
    'unit': 'kg',
    'global_tm_ratio_basis_points': 9000,
    'rounding_increment_centi_units': 250,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  final catalog = SqliteTrainingCatalog(catalogDatabase);
  return CycleWebApplicationImpl(
    catalogVersion: 2,
    catalogQuery: catalog,
    catalogRepository: catalog,
    draftRepository: SqliteCycleWebDraftRepository(
      databaseFile: workspaceFile,
      draftId: 'cycle-web-draft',
      profileId: 'cycle-web-profile',
      now: DateTime.now,
    ),
    snapshotRepository: SqliteTrainingSnapshotRepository(trainingFile),
    compiler: const CycleCompilerImpl(),
    generationContext: CycleWebGenerationContext(
      startDate: DateTime.now(),
      trainingDays: const [1, 3, 5],
      maxInputs: const {},
      globalTrainingMaxRatio: const Percentage(9000),
      unit: WeightUnit.kg,
      roundingIncrement: const Weight(250, WeightUnit.kg),
      barProfile: const BarProfile(
        weight: Weight(2000, WeightUnit.kg),
        platesPerSide: [
          Weight(2500, WeightUnit.kg),
          Weight(2000, WeightUnit.kg),
          Weight(1500, WeightUnit.kg),
          Weight(1000, WeightUnit.kg),
          Weight(500, WeightUnit.kg),
          Weight(250, WeightUnit.kg),
          Weight(125, WeightUnit.kg),
        ],
      ),
      cycleId: 'cycle-web',
    ),
  );
}
