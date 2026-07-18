import '../../program_catalog.dart';
import '../../training_models.dart';
import '../program_domain.dart';
import '../program_v1_adapter.dart';
import 'forever_macrocycle_generator.dart';
import 'generated_training_plan.dart';

class OriginalFslMacrocycleAdapter {
  const OriginalFslMacrocycleAdapter();

  GeneratedTrainingPlan generate({
    required AthletePlanConfiguration athlete,
    required List<MainLift> movementOrder,
    int supplementalSets = 5,
  }) {
    if (supplementalSets != 3 && supplementalSets != 5) {
      throw ArgumentError.value(supplementalSets, 'supplementalSets');
    }
    if (movementOrder.length != athlete.trainingWeekdays.length) {
      throw ArgumentError(
        'movementOrder doit reproduire la fréquence historique.',
      );
    }
    final blueprint = const ProgramV1Adapter()
        .convert(const ProgramCatalog())
        .blueprints
        .singleWhere((item) => item.id.value == 'forever-original-fsl-v1');
    const mainRule = ReviewedRule(
      id: 'ORIGINAL-FSL-MAIN-001',
      status: RuleStatus.verified,
      source: RuleReference(
        document: 'forever-original-fsl-v1',
        location: 'historical compatibility contract',
      ),
    );
    const supplementalRule = ReviewedRule(
      id: 'ORIGINAL-FSL-SUPPLEMENTAL-001',
      status: RuleStatus.verified,
      source: RuleReference(
        document: 'forever-original-fsl-v1',
        location: 'historical compatibility contract',
      ),
    );
    final weeks = <WeekTemplate>[];
    for (var week = 1; week <= 3; week++) {
      final ratios = switch (week) {
        1 => const [(0.70, 3), (0.80, 3), (0.90, 3)],
        2 => const [(0.65, 5), (0.75, 5), (0.85, 5)],
        _ => const [(0.75, 5), (0.85, 3), (0.95, 1)],
      };
      final fsl = ratios.first.$1;
      weeks.add(
        WeekTemplate(
          sessions: [
            for (final movement in movementOrder)
              SessionTemplate(
                blocks: [
                  SessionBlockTemplate(
                    kind: GeneratedSessionBlockKind.mainWork,
                    movements: [
                      MovementTemplate(
                        movement: movement,
                        sets: [
                          for (var index = 0; index < ratios.length; index++)
                            SetTemplate(
                              percentage: ratios[index].$1,
                              repetitions: ratios[index].$2,
                              kind: SetKind.main,
                              rule: mainRule,
                              isPerformanceSet:
                                  week != 2 && index == ratios.length - 1,
                            ),
                        ],
                      ),
                    ],
                  ),
                  SessionBlockTemplate(
                    kind: GeneratedSessionBlockKind.supplemental,
                    movements: [
                      MovementTemplate(
                        movement: movement,
                        sets: [
                          for (var index = 0; index < supplementalSets; index++)
                            SetTemplate(
                              percentage: fsl,
                              repetitions: 5,
                              kind: SetKind.supplemental,
                              rule: supplementalRule,
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      );
    }
    final snapshot = ProgramBlueprintSnapshot(
      blueprint: blueprint,
      blocks: [
        MacrocycleBlockDefinition(
          templateId: const BlockTemplateId('legacy-cycle'),
          role: BlockRole.leader,
          cycleCount: 1,
          weeks: weeks,
          rule: mainRule,
        ),
      ],
      canonicalJson: {
        'id': blueprint.id.value,
        'version': blueprint.version.value,
        'generatorId': blueprint.generatorId,
        'supplementalSets': supplementalSets,
        'movementOrder': movementOrder.map((e) => e.name).toList(),
      },
    );
    return const ForeverMacrocycleGenerator().generate(
      snapshot: snapshot,
      athlete: athlete,
    );
  }
}
