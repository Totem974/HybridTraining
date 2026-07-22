import 'package:training_engine/features/cycle_generation/domain/cycle_contract.dart';
import 'package:training_engine/features/cycle_generation/domain/cycle_option_schema.dart';
import 'package:training_engine/features/training_catalog/domain/catalog_index.dart';

abstract interface class CatalogMovementReferenceValidator {
  Future<void> validateMovementReferences({
    required int catalogVersion,
    required Set<MovementId> movementIds,
  });
}

abstract interface class TrainingCatalogRepository
    implements CatalogMovementReferenceValidator {
  Future<ResolvedCycleDefinition> resolve({
    required int catalogVersion,
    required String templateId,
    required String variantId,
  });
}

abstract interface class CycleCatalogQuery {
  Future<CycleCatalogIndex> loadIndex({required int catalogVersion});
  Future<CycleEditorSchema> loadEditorSchema({
    required int catalogVersion,
    required String templateId,
    required String variantId,
  });
}
