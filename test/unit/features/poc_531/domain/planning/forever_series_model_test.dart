import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/domain/planning/planning.dart';

List<(double, int, ForeverPrescriptionKind, String, String, String)>
_expectedLeaderWeek(
  int week,
  List<double> percentages,
  List<int> repetitions,
  bool performance,
  double fslPercentage,
) => [
  for (var index = 0; index < percentages.length; index++)
    (
      percentages[index],
      repetitions[index],
      performance && index == percentages.length - 1
          ? ForeverPrescriptionKind.performanceSet
          : ForeverPrescriptionKind.mainWork,
      'FOREVER-ORIGINAL-FSL-L-W$week-M${index + 1}',
      '5/3/1 Forever',
      'PDF pages 180-182',
    ),
  for (var set = 1; set <= 5; set++)
    (
      fslPercentage,
      5,
      ForeverPrescriptionKind.supplemental,
      'FOREVER-ORIGINAL-FSL-L-W$week-FSL-$set',
      '5/3/1 Forever',
      'PDF pages 180-182',
    ),
];

void main() {
  ForeverMacrocycle macrocycle({
    required String id,
    MacrocycleIntent intent = MacrocycleIntent.active,
    MacrocycleStatus status = MacrocycleStatus.completed,
    MacrocycleRecipeRevision recipe = foreverTwoLeadersOneAnchorRecipe,
    MacrocycleOutcome? outcome,
    Map<String, double> trainingMaxChoices = const {},
  }) => ForeverMacrocycle(
    instanceId: id,
    intent: intent,
    status: status,
    recipe: recipe,
    outcome: outcome,
    trainingMaxChoices: trainingMaxChoices,
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

    test('productive Original transitions describe both cycle boundaries', () {
      expect(
        foreverOriginalFslLeaderTransition.evaluate(frequency: 4).isCompatible,
        isTrue,
      );
      expect(
        foreverOriginalFslAnchorTransition.evaluate(frequency: 4).isCompatible,
        isTrue,
      );
      expect(
        foreverOriginalFslAnchorTransition.toTemplateRevisionId,
        foreverOriginalPrSetAnchorRevision.id,
      );
      expect(
        foreverOriginalFslPairing,
        same(foreverOriginalFslLeaderTransition),
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

    test('validator accepts history followed by active and planned states', () {
      final series = ForeverProgramSeries(
        id: 'valid-lifecycle',
        macrocycles: [
          macrocycle(id: 'M1'),
          macrocycle(id: 'M2', status: MacrocycleStatus.cancelled),
          macrocycle(id: 'M3', status: MacrocycleStatus.active),
          macrocycle(
            id: 'M4',
            intent: MacrocycleIntent.projected,
            status: MacrocycleStatus.planned,
          ),
        ],
      );

      expect(
        const MacrocycleSeriesValidator().validate(series).isValid,
        isTrue,
      );
    });

    test('validator rejects incoherent intent and status pairs', () {
      final invalid = ForeverProgramSeries(
        id: 'invalid-pairs',
        macrocycles: [
          macrocycle(
            id: 'M1',
            intent: MacrocycleIntent.projected,
            status: MacrocycleStatus.completed,
          ),
          macrocycle(
            id: 'M2',
            intent: MacrocycleIntent.projected,
            status: MacrocycleStatus.active,
          ),
          macrocycle(id: 'M3', status: MacrocycleStatus.planned),
        ],
      );

      final codes = const MacrocycleSeriesValidator()
          .validate(invalid)
          .issues
          .map((issue) => issue.code);
      expect(
        codes,
        containsAll({
          'series.history_must_be_active_intent',
          'series.active_status_must_be_active_intent',
          'series.planned_status_must_be_projected_intent',
          'series.projected_intent_must_be_planned',
        }),
      );
    });

    test('validator rejects multiple current or future macrocycles', () {
      final invalid = ForeverProgramSeries(
        id: 'too-many-current',
        macrocycles: [
          macrocycle(id: 'M1', status: MacrocycleStatus.active),
          macrocycle(id: 'M2', status: MacrocycleStatus.active),
          macrocycle(
            id: 'M3',
            intent: MacrocycleIntent.projected,
            status: MacrocycleStatus.planned,
          ),
          macrocycle(
            id: 'M4',
            intent: MacrocycleIntent.projected,
            status: MacrocycleStatus.planned,
          ),
        ],
      );

      final codes = const MacrocycleSeriesValidator()
          .validate(invalid)
          .issues
          .map((issue) => issue.code);
      expect(codes, contains('series.multiple_active'));
      expect(codes, contains('series.multiple_planned'));
    });

    test('validator rejects history or active after future', () {
      final invalid = ForeverProgramSeries(
        id: 'invalid-order',
        macrocycles: [
          macrocycle(
            id: 'M1',
            intent: MacrocycleIntent.projected,
            status: MacrocycleStatus.planned,
          ),
          macrocycle(id: 'M2', status: MacrocycleStatus.active),
          macrocycle(id: 'M3'),
        ],
      );

      final codes = const MacrocycleSeriesValidator()
          .validate(invalid)
          .issues
          .map((issue) => issue.code);
      expect(codes, contains('series.active_after_planned'));
      expect(codes, contains('series.history_after_current_or_future'));
    });

    test(
      'generic compiler inserts mandatory protocols for every macrocycle',
      () {
        final series = ForeverProgramSeries(
          id: 'series',
          profile: profile(),
          macrocycles: [
            macrocycle(
              id: 'M1',
              outcome: MacrocycleOutcome(
                macrocycleInstanceId: 'M1',
                trainingMaxStates: const {
                  'press': TrainingMaxDecisionState.confirmed,
                  'squat': TrainingMaxDecisionState.confirmed,
                },
              ),
              trainingMaxChoices: const {'press': 52.5, 'squat': 105},
            ),
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
          hasLength(1),
        );
        expect(result.trainingMaxDecisions, hasLength(2));
        expect(
          result.trainingMaxDecisions[0].state,
          TrainingMaxDecisionState.confirmed,
        );
        expect(result.trainingMaxDecisions[1].previousTrainingMaxes, {
          'press': 52.5,
          'squat': 105,
        });
        expect(result.trainingMaxDecisions[1].proposedTrainingMaxes, {
          'press': 55,
          'squat': 110,
        });
      },
    );

    test('compiler reports an unknown slot instead of throwing StateError', () {
      final invalid = ForeverProgramSeries(
        id: 'unknown-slot',
        profile: profile(),
        macrocycles: [
          ForeverMacrocycle(
            instanceId: 'M1',
            intent: MacrocycleIntent.active,
            status: MacrocycleStatus.active,
            recipe: foreverTwoLeadersOneAnchorRecipe,
            cycleSelections: [
              ...macrocycle(id: 'M1').cycleSelections,
              const CycleSlotSelection(
                slotId: 'intruder',
                cycleInstanceId: 'M1-intruder',
                revision: foreverOriginalFslLeaderRevision,
              ),
            ],
          ),
        ],
      );

      expect(
        () => const ForeverSequenceCompiler().compileSeries(invalid),
        throwsA(
          isA<ForeverCompilationException>().having(
            (error) => error.validation.issues.map((issue) => issue.code),
            'issue codes',
            contains('macrocycle.unknown_slot'),
          ),
        ),
      );
    });

    test(
      'compiler rejects a protocol purpose mismatched with its strategy',
      () {
        const mismatched = ProtocolTemplateRevision(
          id: 'forever-seventh-week-deload-v1',
          version: 1,
          purpose: ProtocolPurpose.seventhWeekTrainingMaxTest,
          source: RuleSource(
            document: '5/3/1 Forever',
            location: 'PDF pages 31 and 33',
          ),
        );
        const recipe = MacrocycleRecipeRevision(
          id: 'mismatched-protocol',
          version: 1,
          kind: ForeverPlanKind.macrocycle,
          source: RuleSource(
            document: '5/3/1 Forever',
            location: 'PDF pages 29-33 and 180-182',
          ),
          status: CompatibilityStatus.recommended,
          slots: [
            MacrocycleSlotDefinition(
              slotId: 'leader-1',
              role: CycleRole.leader,
            ),
          ],
          boundaryProtocols: [
            BoundaryProtocolRule(
              boundaryId: 'bad',
              afterSlotId: 'leader-1',
              protocol: mismatched,
              required: true,
              source: RuleSource(
                document: '5/3/1 Forever',
                location: 'PDF pages 31 and 33',
              ),
            ),
          ],
        );
        final series = ForeverProgramSeries(
          id: 'mismatch',
          profile: profile(),
          macrocycles: [
            ForeverMacrocycle(
              instanceId: 'M1',
              intent: MacrocycleIntent.active,
              status: MacrocycleStatus.active,
              recipe: recipe,
              cycleSelections: const [
                CycleSlotSelection(
                  slotId: 'leader-1',
                  cycleInstanceId: 'M1-leader-1',
                  revision: foreverOriginalFslLeaderRevision,
                ),
              ],
            ),
          ],
        );

        expect(
          () => const ForeverSequenceCompiler().compileSeries(series),
          throwsA(
            isA<ForeverCompilationException>().having(
              (error) => error.validation.issues.map((issue) => issue.code),
              'issue codes',
              contains('strategy.protocol_not_registered'),
            ),
          ),
        );
      },
    );

    test('compiler preserves a distinct Training Max state for every lift', () {
      final series = ForeverProgramSeries(
        id: 'mixed-tm-states',
        profile: profile(),
        macrocycles: [
          macrocycle(
            id: 'M1',
            outcome: MacrocycleOutcome(
              macrocycleInstanceId: 'M1',
              trainingMaxStates: const {
                'press': TrainingMaxDecisionState.held,
                'squat': TrainingMaxDecisionState.reset,
              },
            ),
            trainingMaxChoices: const {'press': 50, 'squat': 90},
          ),
        ],
      );

      final decision = const ForeverSequenceCompiler()
          .compileSeries(series)
          .trainingMaxDecisions
          .single;

      expect(decision.states, const {
        'press': TrainingMaxDecisionState.held,
        'squat': TrainingMaxDecisionState.reset,
      });
      expect(() => decision.state, throwsStateError);
    });

    test('only sourced cycle and protocol revisions resolve', () {
      const cycles = CycleStrategyRegistry();
      const protocols = ProtocolStrategyRegistry();
      expect(
        cycles.resolve(foreverOriginalFslLeaderRevision.id),
        same(foreverOriginalFslLeaderRevision),
      );
      expect(
        cycles.resolve(foreverOriginalPrSetAnchorRevision.id),
        same(foreverOriginalPrSetAnchorRevision),
      );
      expect(cycles.resolve('NEEDS_REVIEW'), isNull);
      expect(
        cycles
            .resolveStrategy(
              foreverOriginalFslLeaderRevision.id,
              role: CycleRole.leader,
            )!
            .weeks
            .first
            .where((set) => set.kind == ForeverPrescriptionKind.supplemental),
        hasLength(5),
      );
      expect(
        protocols.resolve(foreverSeventhWeekDeloadRevision.id),
        same(foreverSeventhWeekDeloadRevision),
      );
      expect(protocols.resolve('forbidden'), isNull);
      expect(
        protocols
            .resolveStrategy(foreverSeventhWeekTrainingMaxTestRevision.id)!
            .prescriptions
            .every(
              (set) => set.kind == ForeverPrescriptionKind.trainingMaxTest,
            ),
        isTrue,
      );
    });

    test('registered prescriptions are exact and deeply immutable', () {
      final leader = const CycleStrategyRegistry().resolveStrategy(
        foreverOriginalFslLeaderRevision.id,
        role: CycleRole.leader,
      )!;
      expect(
        leader.weeks
            .map(
              (week) => week
                  .map(
                    (set) => (
                      set.percentage,
                      set.repetitions,
                      set.kind,
                      set.ruleId,
                      set.source.document,
                      set.source.location,
                    ),
                  )
                  .toList(),
            )
            .toList(),
        [
          _expectedLeaderWeek(1, [.70, .80, .90], [3, 3, 3], true, .70),
          _expectedLeaderWeek(2, [.65, .75, .85], [5, 5, 5], false, .65),
          _expectedLeaderWeek(3, [.75, .85, .95], [5, 3, 1], true, .75),
        ],
      );
      expect(() => leader.weeks.add(const []), throwsUnsupportedError);
      expect(
        () => leader.weeks.first.add(leader.weeks.first.first),
        throwsUnsupportedError,
      );
      final anchor = const CycleStrategyRegistry().resolveStrategy(
        foreverOriginalPrSetAnchorRevision.id,
        role: CycleRole.anchor,
      )!;
      expect(
        anchor.weeks
            .map(
              (week) => week
                  .map(
                    (set) => (
                      set.percentage,
                      set.repetitions,
                      set.kind,
                      set.ruleId,
                      set.source.document,
                      set.source.location,
                    ),
                  )
                  .toList(),
            )
            .toList(),
        [
          for (final week in const [
            (1, [.65, .75, .85], [5, 5, 5]),
            (2, [.70, .80, .90], [3, 3, 3]),
            (3, [.75, .85, .95], [5, 3, 1]),
          ])
            [
              for (var index = 0; index < 3; index++)
                (
                  week.$2[index],
                  week.$3[index],
                  index == 2
                      ? ForeverPrescriptionKind.performanceSet
                      : ForeverPrescriptionKind.mainWork,
                  'FOREVER-ORIGINAL-FSL-A-W${week.$1}-M${index + 1}',
                  '5/3/1 Forever',
                  'PDF pages 180-182',
                ),
            ],
        ],
      );

      final deload = const ProtocolStrategyRegistry().resolveStrategy(
        foreverSeventhWeekDeloadRevision.id,
      )!;
      expect(
        deload.prescriptions
            .map(
              (set) => (
                set.percentage,
                set.repetitions,
                set.kind,
                set.ruleId,
                set.source.document,
                set.source.location,
              ),
            )
            .toList(),
        const [
          (
            .70,
            5,
            ForeverPrescriptionKind.mainWork,
            'FOREVER-7W-DELOAD-70',
            '5/3/1 Forever',
            'PDF pages 31 and 33',
          ),
          (
            .80,
            3,
            ForeverPrescriptionKind.mainWork,
            'FOREVER-7W-DELOAD-80',
            '5/3/1 Forever',
            'PDF pages 31 and 33',
          ),
          (
            .90,
            1,
            ForeverPrescriptionKind.mainWork,
            'FOREVER-7W-DELOAD-90',
            '5/3/1 Forever',
            'PDF pages 31 and 33',
          ),
          (
            1.0,
            1,
            ForeverPrescriptionKind.mainWork,
            'FOREVER-7W-DELOAD-TM',
            '5/3/1 Forever',
            'PDF pages 31 and 33',
          ),
        ],
      );

      final test = const ProtocolStrategyRegistry().resolveStrategy(
        foreverSeventhWeekTrainingMaxTestRevision.id,
      )!;
      expect(
        test.prescriptions
            .map(
              (set) => (
                set.percentage,
                set.repetitions,
                set.kind,
                set.ruleId,
                set.source.document,
                set.source.location,
              ),
            )
            .toList(),
        [
          for (final item in const [
            (.70, 5, '70'),
            (.80, 5, '80'),
            (.90, 5, '90'),
            (1.0, 3, 'TM'),
          ])
            (
              item.$1,
              item.$2,
              ForeverPrescriptionKind.trainingMaxTest,
              'FOREVER-7W-TMTEST-${item.$3}',
              '5/3/1 Forever',
              'PDF pages 31-33',
            ),
        ],
      );
      expect(
        () => test.prescriptions.add(test.prescriptions.first),
        throwsUnsupportedError,
      );
    });

    test(
      'future regeneration preserves completed and cancelled instances exactly',
      () {
        final completed = macrocycle(id: 'M1');
        final cancelled = macrocycle(
          id: 'M-cancelled',
          status: MacrocycleStatus.cancelled,
        );
        final oldFuture = macrocycle(
          id: 'M2-old',
          intent: MacrocycleIntent.projected,
          status: MacrocycleStatus.planned,
        );
        final replacement = macrocycle(
          id: 'M2',
          intent: MacrocycleIntent.projected,
          status: MacrocycleStatus.planned,
        );
        final series = ForeverProgramSeries(
          id: 'series',
          profile: profile(),
          macrocycles: [completed, cancelled, oldFuture],
        );

        final regenerated = const ForeverSequenceCompiler().regenerateFuture(
          series: series,
          future: [replacement],
        );
        expect(regenerated.macrocycles, hasLength(3));
        expect(regenerated.macrocycles[0], same(completed));
        expect(regenerated.macrocycles[1], same(cancelled));
        expect(regenerated.macrocycles[2], same(replacement));
        expect(regenerated.macrocycles, isNot(contains(same(oldFuture))));
      },
    );

    test('configuration kind must agree with its xor payload', () {
      final series = ForeverProgramSeries(
        id: 'series',
        profile: profile(),
        macrocycles: [macrocycle(id: 'M1')],
      );
      final invalid = ForeverPlanningConfiguration(
        profile: profile(),
        kind: ForeverPlanKind.standaloneProgram,
        series: series,
      );
      final result = const ForeverSequenceCompiler().validate(invalid);
      expect(result.isValid, isFalse);
      expect(
        result.issues.map((issue) => issue.code),
        contains('forever.kind_requires_standalone'),
      );
    });

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
