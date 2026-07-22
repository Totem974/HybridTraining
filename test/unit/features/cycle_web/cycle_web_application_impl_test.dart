import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_option_schema.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_application_impl.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_contract.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_draft_repository.dart';
import 'package:hybrid_training/features/training_catalog/application/catalog_repository.dart';
import 'package:hybrid_training/features/training_catalog/domain/catalog_index.dart';
import 'package:hybrid_training/features/training_log/application/training_snapshot_repository.dart';
import 'package:hybrid_training/features/training_log/domain/training_snapshot.dart';

void main() {
  test(
    'delegates dynamic catalogue data, compiles and saves the snapshot',
    () async {
      final catalog = _Catalog();
      final compiler = _Compiler();
      final snapshots = _Snapshots();
      final drafts = _Drafts();
      final application = CycleWebApplicationImpl(
        catalogVersion: 7,
        catalogQuery: catalog,
        catalogRepository: catalog,
        draftRepository: drafts,
        snapshotRepository: snapshots,
        compiler: compiler,
        generationContext: CycleWebGenerationContext(
          cycleId: 'web-cycle',
          startDate: DateTime(2026, 7, 21),
          trainingDays: const [2],
          maxInputs: const {
            MovementId('squat'): DirectTrainingMaxInput(
              Weight(10000, WeightUnit.kg),
            ),
          },
          globalTrainingMaxRatio: const Percentage(9000),
          unit: WeightUnit.kg,
          roundingIncrement: const Weight(250, WeightUnit.kg),
          barProfile: const BarProfile(
            weight: Weight(2000, WeightUnit.kg),
            platesPerSide: [Weight(2000, WeightUnit.kg)],
          ),
        ),
      );

      expect((await application.loadIndex()).catalogVersion, 7);
      final state = CycleEditorState(
        templateId: 'data_driven',
        variantId: 'only_variant',
        values: const {
          'training_max_ratio': 8500,
          'supplemental_percentage': 5000,
          'include_deload': false,
        },
        startDate: DateTime(2026, 8, 1),
        trainingDays: const [1, 4],
        sessionOrder: const ['squat'],
        maxInputs: const {
          'squat': CycleMovementMaxInput(
            kind: CycleMaxInputKind.repMax,
            weightCentiUnits: 12000,
            repetitions: 5,
          ),
        },
        globalTrainingMaxRatioBasisPoints: 8800,
        trainingMaxRatioByMovementBasisPoints: const {'squat': 8700},
        unit: WeightUnit.lb,
        roundingIncrementCentiUnits: 500,
        barWeightCentiUnits: 4500,
        platesPerSideCentiUnits: const [4500, 2500],
        cycleId: 'state-cycle',
      );
      await application.saveDraft(state);
      expect(await application.loadDraft(), same(state));
      final view = await application.generate(state);

      expect(view.cycle.id, 'state-cycle');
      expect(compiler.request!.startDate, DateTime(2026, 8, 1));
      expect(compiler.request!.trainingDays, [1, 4]);
      expect(compiler.request!.sessionOrder, const [MovementId('squat')]);
      expect(compiler.request!.globalTrainingMaxRatio.basisPoints, 8800);
      expect(
        compiler
            .request!
            .percentageParameters['training_max_ratio']!
            .basisPoints,
        8500,
      );
      expect(
        compiler
            .request!
            .trainingMaxRatioByMovement[const MovementId('squat')]!
            .basisPoints,
        8700,
      );
      expect(
        compiler.request!.maxInputs[const MovementId('squat')],
        isA<RepMaxInput>(),
      );
      expect(compiler.request!.unit, WeightUnit.lb);
      expect(
        compiler.request!.roundingIncrement.centiUnits,
        5000,
        reason: 'rounding follows the smallest available plate per side',
      );
      expect(compiler.request!.barProfile.weight.centiUnits, 4500);
      expect(
        compiler
            .request!
            .percentageParameters['supplemental_percentage']!
            .basisPoints,
        5000,
      );
      expect(compiler.request!.includeDeload, isFalse);
      expect(snapshots.saved, same(view.cycle));
      expect(view.persistedSnapshot!.cycleId, 'state-cycle');
    },
  );

  test(
    'rejects unknown or out-of-range editor values before resolving',
    () async {
      final catalog = _Catalog();
      final application = CycleWebApplicationImpl(
        catalogVersion: 7,
        catalogQuery: catalog,
        catalogRepository: catalog,
        draftRepository: _Drafts(),
        snapshotRepository: _Snapshots(),
        compiler: _Compiler(),
        generationContext: CycleWebGenerationContext(
          cycleId: 'invalid',
          startDate: DateTime(2026, 7, 21),
          trainingDays: const [2],
          maxInputs: const {},
          globalTrainingMaxRatio: const Percentage(9000),
          unit: WeightUnit.kg,
          roundingIncrement: const Weight(250, WeightUnit.kg),
          barProfile: const BarProfile(
            weight: Weight(2000, WeightUnit.kg),
            platesPerSide: [],
          ),
        ),
      );

      await expectLater(
        application.generate(
          const CycleEditorState(
            templateId: 'data_driven',
            variantId: 'only_variant',
            values: {'supplemental_percentage': 7000},
          ),
        ),
        throwsFormatException,
      );
      expect(catalog.resolveCalls, 0);
    },
  );
}

final class _Catalog implements CycleCatalogQuery, TrainingCatalogRepository {
  var resolveCalls = 0;

  @override
  Future<CycleCatalogIndex> loadIndex({required int catalogVersion}) async =>
      CycleCatalogIndex(
        catalogVersion: catalogVersion,
        templates: const [
          CycleTemplateSummary(
            id: 'data_driven',
            revision: 1,
            labelEn: 'Data driven',
            labelFr: 'Data driven',
            variantIds: ['only_variant'],
          ),
        ],
      );

  @override
  Future<CycleEditorSchema> loadEditorSchema({
    required int catalogVersion,
    required String templateId,
    required String variantId,
  }) async => const CycleEditorSchema(
    id: 'schema',
    templateId: 'data_driven',
    variantId: 'only_variant',
    options: [
      CycleOptionDefinition(
        id: 'training_max_ratio',
        type: CycleOptionType.percentage,
        scope: CycleOptionScope.global,
        defaultValue: 9000,
        minimum: 1,
        maximum: 10000,
      ),
      CycleOptionDefinition(
        id: 'supplemental_percentage',
        type: CycleOptionType.percentage,
        scope: CycleOptionScope.global,
        defaultValue: 5000,
        minimum: 4000,
        maximum: 6000,
      ),
      CycleOptionDefinition(
        id: 'include_deload',
        type: CycleOptionType.boolean,
        scope: CycleOptionScope.global,
        defaultValue: true,
      ),
    ],
  );

  @override
  Future<ResolvedCycleDefinition> resolve({
    required int catalogVersion,
    required String templateId,
    required String variantId,
  }) async {
    resolveCalls++;
    return const ResolvedCycleDefinition(
      catalogVersion: 7,
      templateId: 'data_driven',
      variantId: 'only_variant',
      sessionMovementIds: [MovementId('squat')],
      weeks: [],
      sourceReference: 'test',
    );
  }

  @override
  Future<void> validateMovementReferences({
    required int catalogVersion,
    required Set<MovementId> movementIds,
  }) async {}
}

final class _Compiler implements CycleCompiler {
  CycleRequest? request;

  @override
  GeneratedCycle compile(
    ResolvedCycleDefinition definition,
    CycleRequest request,
  ) {
    this.request = request;
    return GeneratedCycle(
      id: request.cycleId,
      catalogVersion: definition.catalogVersion,
      templateId: definition.templateId,
      variantId: definition.variantId,
      effectiveTrainingMaxes: const {},
      weeks: const [],
    );
  }
}

final class _Drafts implements CycleWebDraftRepository {
  CycleEditorState? state;
  @override
  Future<CycleEditorState?> load() async => state;
  @override
  Future<void> save(CycleEditorState state) async => this.state = state;
}

final class _Snapshots implements TrainingSnapshotRepository {
  GeneratedCycle? saved;
  @override
  Future<void> save(GeneratedCycle cycle) async => saved = cycle;
  @override
  Future<StoredTrainingSnapshot> load(String cycleId) async =>
      StoredTrainingSnapshot(cycleId: cycleId, resolvedCycleJson: const {});
  @override
  Future<ActualSetResult> loadSetResult(String setId) =>
      throw UnimplementedError();
  @override
  Future<void> recordSetResult(String setId, ActualSetResult result) =>
      throw UnimplementedError();
}
