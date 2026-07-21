import '../../cycle_generation/domain/cycle_contract.dart';

abstract interface class TrainingCatalogRepository {
  Future<ResolvedCycleDefinition> resolve({
    required int catalogVersion,
    required String templateId,
    required String variantId,
  });
}
