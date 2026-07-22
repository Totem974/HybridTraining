import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/storage/platform_database_factory.dart';
import '../../core/storage/sqlite_database_file.dart';
import '../../features/cycle_generation/data/workspace_database_schema.dart';
import '../../features/cycle_generation/domain/cycle_compiler_impl.dart';
import '../../features/forever/application/forever_composer_impl.dart';
import '../../features/forever/application/forever_web_application_impl.dart';
import '../../features/forever/data/sqlite_forever_definition_repository.dart';
import '../../features/forever/data/sqlite_forever_draft_repository.dart';
import '../../features/forever/data/sqlite_forever_macrocycle_repository.dart';
import '../../features/forever/presentation/forever_web_contract.dart';
import '../../features/training_catalog/data/runtime_catalog_publisher.dart';
import '../../features/training_catalog/data/sqlite_training_catalog.dart';
import '../../features/training_log/data/training_database_schema.dart';

Future<ForeverWebApplication> createForeverWebApplication() async {
  final decoded = jsonDecode(
    await rootBundle.loadString('assets/catalog/catalog_seed.v2.json'),
  );
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Invalid published catalogue seed.');
  }

  final factory = platformDatabaseFactory;
  final catalogFile = SqliteDatabaseFile(
    fileName: 'catalog.db',
    databasePath: 'catalog.db',
    factory: factory,
    version: SqliteTrainingCatalog.databaseSchemaVersion,
    onCreate: (database, _) => SqliteTrainingCatalog.createSchema(database),
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
  await workspaceFile.open();
  await trainingFile.open();

  final catalog = SqliteTrainingCatalog(catalogDatabase);
  final cycleResolver = CatalogForeverCycleResolver(catalog, 2);
  return ForeverWebApplicationImpl(
    catalogVersion: 2,
    definitionRepository: SqliteForeverDefinitionRepository(catalogDatabase),
    catalogQuery: catalog,
    cycleResolver: cycleResolver,
    composer: ForeverComposerImpl(
      cycleDefinitionResolver: cycleResolver,
      cycleCompiler: const CycleCompilerImpl(),
    ),
    draftRepository: SqliteForeverDraftRepository(workspaceFile),
    macrocycleRepository: SqliteForeverMacrocycleRepository(trainingFile),
    now: DateTime.now,
  );
}
