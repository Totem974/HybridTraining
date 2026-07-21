import '../../training_catalog/application/catalog_repository.dart';
import '../domain/cycle_contract.dart';
import 'workspace_program_repository.dart';

sealed class CycleDefinitionReference {
  const CycleDefinitionReference();
}

final class CatalogCycleDefinitionReference extends CycleDefinitionReference {
  const CatalogCycleDefinitionReference({
    required this.catalogVersion,
    required this.templateId,
    required this.variantId,
  });
  final int catalogVersion;
  final String templateId;
  final String variantId;
}

final class WorkspaceCycleDefinitionReference extends CycleDefinitionReference {
  const WorkspaceCycleDefinitionReference(this.programId);
  final String programId;
}

final class DefinitionResolver {
  const DefinitionResolver({
    required this.catalog,
    required this.workspacePrograms,
  });

  final TrainingCatalogRepository catalog;
  final WorkspaceProgramRepository workspacePrograms;

  Future<ResolvedCycleDefinition> resolve(
    CycleDefinitionReference reference,
  ) async {
    switch (reference) {
      case CatalogCycleDefinitionReference(
        :final catalogVersion,
        :final templateId,
        :final variantId,
      ):
        return catalog.resolve(
          catalogVersion: catalogVersion,
          templateId: templateId,
          variantId: variantId,
        );
      case WorkspaceCycleDefinitionReference(:final programId):
        final program = await workspacePrograms.load(programId);
        await catalog.validateMovementReferences(
          catalogVersion: program.catalogVersion,
          movementIds: program.catalogMovementReferences,
        );
        final sessionIds = program.weeks.first.sessions
            .map((session) => session.id)
            .toList(growable: false);
        for (final week in program.weeks.skip(1)) {
          final ids = week.sessions.map((session) => session.id).toList();
          if (ids.length != sessionIds.length ||
              !ids.asMap().entries.every(
                (entry) => entry.value == sessionIds[entry.key],
              )) {
            throw StateError(
              'Workspace program session order must be stable across weeks.',
            );
          }
        }
        return ResolvedCycleDefinition(
          catalogVersion: program.catalogVersion,
          templateId: program.id,
          variantId: 'workspace-r${program.revision}',
          sessionMovementIds: sessionIds,
          weeks: program.weeks,
          sourceReference: 'userDefined:${program.id}:r${program.revision}',
        );
    }
  }
}
