import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/domain/planning/planning.dart';

void main() {
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
  });
}
