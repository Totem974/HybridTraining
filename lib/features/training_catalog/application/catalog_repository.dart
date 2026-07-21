import '../../cycle_generation/domain/cycle_contract.dart';

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
