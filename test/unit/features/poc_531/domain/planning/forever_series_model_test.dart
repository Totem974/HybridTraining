import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/domain/planning/planning.dart';

void main() {
  ForeverMacrocycle macrocycle({
    required String id,
    MacrocycleIntent intent = MacrocycleIntent.active,
    MacrocycleStatus status = MacrocycleStatus.completed,
    MacrocycleRecipeRevision recipe = foreverTwoLeadersOneAnchorRecipe,
  }) => ForeverMacrocycle(
    instanceId: id,
    intent: intent,
    status: status,
    recipe: recipe,
    cycleSelections: [
      for (final slot in recipe.slots)
        CycleSlotSelection(
          slotId: slot.slotId,
          cycleInstanceId: '$id-${slot.slotId}',
          revision: slot.role == CycleRole.leader
              ? foreverOriginalFslLeaderRevision
              : foreverOriginalPrSetAnchorRevision,
        ),
    ],
  );

  CommonTrainingProfile profile() => CommonTrainingProfile(
    trainingDaysPerWeek: 4,
    trainingMaxes: const {'press': 50, 'squat': 100},
    progressionIncrements: const {'press': 2.5, 'squat': 5},
  );

  group('Forever macrocycle series model', () {
    test(
      'the sourced 2L/1A recipe describes slots and mandatory protocols',
      () {
        expect(foreverTwoLeadersOneAnchorRecipe.id, 'forever-2l1a-v2');
        expect(foreverTwoLeadersOneAnchorRecipe.isExecutable, isTrue);
        expect(
          foreverTwoLeadersOneAnchorRecipe.slots.map((slot) => slot.role),
          [CycleRole.leader, CycleRole.leader, CycleRole.anchor],
        );
        expect(
          foreverTwoLeadersOneAnchorRecipe.slots[1].defaultsToSlotId,
          'leader-1',
        );
        expect(
          foreverTwoLeadersOneAnchorRecipe.boundaryProtocols.every(
            (rule) => rule.required,
          ),
          isTrue,
        );
        expect(
          foreverTwoLeadersOneAnchorRecipe.boundaryProtocols.map(
            (rule) => rule.protocol.id,
          ),
          ['forever-seventh-week-deload-v1', 'forever-seventh-week-tm-test-v1'],
        );
      },
    );

    test('unsourced recipe structures cannot become executable', () {
      expect(foreverTwoLeadersTwoAnchorsRecipe.isExecutable, isFalse);
      expect(foreverThreeLeadersTwoAnchorsRecipe.isExecutable, isFalse);
      expect(
        foreverTwoLeadersTwoAnchorsRecipe.status,
        CompatibilityStatus.needsReview,
      );
    });

    test('needsReview transitions are incompatible by construction', () {
      const transition = CycleTransitionRule(
        fromTemplateRevisionId: 'leader-a',
        fromRole: CycleRole.leader,
        toTemplateRevisionId: 'anchor-a',
        toRole: CycleRole.anchor,
        status: CompatibilityStatus.needsReview,
        allowedFrequencies: [4],
        trainingMaxCompatibility: 'projected',
        requiredEquipment: [],
        source: RuleSource(document: 'NEEDS_REVIEW', location: 'NEEDS_REVIEW'),
      );

      final result = transition.evaluate(frequency: 4);

      expect(result.isCompatible, isFalse);
      expect(
        result.issues.map((issue) => issue.code),
        contains('transition.needs_review'),
      );
    });

    test('a series is finite and preserves macrocycle order', () {
      final first = ForeverMacrocycle(
        instanceId: 'M1',
        intent: MacrocycleIntent.active,
        status: MacrocycleStatus.active,
        recipe: foreverTwoLeadersOneAnchorRecipe,
        cycleSelections: const [],
      );
      final second = ForeverMacrocycle(
        instanceId: 'M2',
        intent: MacrocycleIntent.projected,
        status: MacrocycleStatus.planned,
        recipe: foreverTwoLeadersOneAnchorRecipe,
        cycleSelections: const [],
      );

      final series = ForeverProgramSeries(
        id: 'series-1',
        macrocycles: [first, second],
      );

      expect(series.macrocycles.map((item) => item.instanceId), ['M1', 'M2']);
      expect(series.macrocycles, hasLength(2));
      expect(series.terminated, isFalse);
    });

    test('validator rejects missing slots and non executable recipes', () {
      final invalid = ForeverProgramSeries(
        id: 'invalid',
        macrocycles: [
          ForeverMacrocycle(
            instanceId: 'M1',
            intent: MacrocycleIntent.active,
            status: MacrocycleStatus.active,
            recipe: foreverTwoLeadersOneAnchorRecipe,
            cycleSelections: const [],
          ),
          macrocycle(id: 'M2', recipe: foreverTwoLeadersTwoAnchorsRecipe),
        ],
      );

      final result = const MacrocycleSeriesValidator().validate(invalid);
      expect(result.isValid, isFalse);
      expect(
        result.issues.map((issue) => issue.code),
        containsAll({'macrocycle.slot_missing', 'recipe.needs_review'}),
      );
    });

    test(
      'generic compiler inserts mandatory protocols for every macrocycle',
      () {
        final series = ForeverProgramSeries(
          id: 'series',
          profile: profile(),
          macrocycles: [
            macrocycle(id: 'M1'),
            macrocycle(
              id: 'M2',
              intent: MacrocycleIntent.projected,
              status: MacrocycleStatus.planned,
            ),
          ],
        );

        final result = const ForeverSequenceCompiler().compileSeries(series);
        expect(result.nodes.whereType<ForeverCycleNode>(), hasLength(6));
        expect(result.nodes.whereType<ForeverProtocolNode>(), hasLength(4));
        expect(
          result.trainingMaxDecisions.where(
            (item) => item.state == TrainingMaxDecisionState.projected,
          ),
          hasLength(3),
        );
        expect(result.trainingMaxDecisions[3].previousTrainingMaxes, {
          'press': 57.5,
          'squat': 115,
        });
      },
    );

    test(
      'continuation is explicit, finite and leaves completed history unchanged',
      () {
        final completed = macrocycle(id: 'M1');
        final series = ForeverProgramSeries(
          id: 'series',
          profile: profile(),
          macrocycles: [completed],
        );
        final compiler = const ForeverSequenceCompiler();

        expect(
          () => compiler.proposeNextMacrocycle(
            series: series,
            mode: ContinuationMode.repeatSame,
          ),
          throwsA(isA<ForeverCompilationException>()),
        );
        final proposal = compiler.proposeNextMacrocycle(
          series: series,
          mode: ContinuationMode.repeatSame,
          incrementConfirmed: true,
        );
        expect(proposal.macrocycle!.instanceId, 'M2');
        expect(proposal.macrocycle!.intent, MacrocycleIntent.projected);
        expect(series.macrocycles, same(series.macrocycles));
        expect(series.macrocycles.single, same(completed));
      },
    );

    test('manual continuation does not materialize an infinite future', () {
      final series = ForeverProgramSeries(
        id: 'series',
        profile: profile(),
        macrocycles: [macrocycle(id: 'M1')],
      );
      final proposal = const ForeverSequenceCompiler().proposeNextMacrocycle(
        series: series,
        mode: ContinuationMode.manual,
      );
      expect(proposal.macrocycle, isNull);
    });

    test(
      'TM confirmation allows hold or lower increase but rejects excess',
      () {
        final compiler = const ForeverSequenceCompiler();
        final resolved = compiler.confirmTrainingMaxes(
          profile: profile(),
          currentTrainingMaxes: const {'press': 50, 'squat': 100},
          choices: const {
            'press': TrainingMaxChoice(
              state: TrainingMaxDecisionState.held,
              value: 50,
            ),
            'squat': TrainingMaxChoice(
              state: TrainingMaxDecisionState.confirmed,
              value: 102.5,
            ),
          },
        );
        expect(resolved, {'press': 50, 'squat': 102.5});

        expect(
          () => compiler.confirmTrainingMaxes(
            profile: profile(),
            currentTrainingMaxes: const {'press': 50, 'squat': 100},
            choices: const {
              'press': TrainingMaxChoice(
                state: TrainingMaxDecisionState.confirmed,
                value: 55,
              ),
              'squat': TrainingMaxChoice(
                state: TrainingMaxDecisionState.held,
                value: 100,
              ),
            },
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
