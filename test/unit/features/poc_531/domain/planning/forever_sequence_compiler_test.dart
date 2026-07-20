import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/domain/planning/planning.dart';

void main() {
  CommonTrainingProfile profile({int days = 4}) => CommonTrainingProfile(
    trainingDaysPerWeek: days,
    trainingMaxes: const {'press': 50, 'squat': 100},
    progressionIncrements: const {'press': 2.5, 'squat': 5},
  );

  ForeverPlanningConfiguration configuration({
    CommonTrainingProfile? trainingProfile,
    CycleRevision secondLeader = foreverOriginalFslCycleRevision,
  }) => ForeverPlanningConfiguration(
    profile: trainingProfile ?? profile(),
    kind: ForeverPlanKind.macrocycle,
    firstLeader: foreverOriginalFslCycleRevision,
    secondLeader: secondLeader,
    anchor: foreverOriginalFslCycleRevision,
  );

  group('ForeverSequenceCompiler', () {
    test('compiles the single sourced 2L/1A recipe', () {
      final result = const ForeverSequenceCompiler().compile(configuration());

      expect(result.nodes.map((node) => node.nodeId), [
        'C1',
        'C2',
        'P1',
        'C3',
        'P2',
      ]);
      expect(
        result.nodes.whereType<ForeverCycleNode>().map((node) => node.role),
        [CycleRole.leader, CycleRole.leader, CycleRole.anchor],
      );
      expect(
        result.nodes.whereType<ForeverProtocolNode>().map(
          (node) => node.purpose,
        ),
        [
          ProtocolPurpose.seventhWeekDeload,
          ProtocolPurpose.seventhWeekTrainingMaxTest,
        ],
      );
    });

    test('auto-inserted protocols reference the preceding cycle instance', () {
      final result = const ForeverSequenceCompiler().compile(configuration());
      final protocols = result.nodes.whereType<ForeverProtocolNode>().toList();

      expect(protocols[0].afterCycleInstanceId, 'leader-2');
      expect(protocols[1].afterCycleInstanceId, 'anchor-1');
      expect(protocols.every((node) => node.autoInserted), isTrue);
    });

    test('TM projections are tied to node and cycle instance identifiers', () {
      final result = const ForeverSequenceCompiler().compile(configuration());

      expect(result.trainingMaxDecisions.map((item) => item.nodeId), [
        'C1',
        'C2',
        'C3',
      ]);
      expect(result.trainingMaxDecisions.map((item) => item.cycleInstanceId), [
        'leader-1',
        'leader-2',
        'anchor-1',
      ]);
      expect(result.trainingMaxDecisions[0].proposedTrainingMaxes, {
        'press': 52.5,
        'squat': 105,
      });
      expect(result.trainingMaxDecisions[2].proposedTrainingMaxes, {
        'press': 57.5,
        'squat': 115,
      });
    });

    test('rejects a different C2 revision', () {
      const otherSecondLeader = CycleRevision(
        id: 'different-c2',
        version: 1,
        mainWork: foreverOriginalMainWorkRevision,
        supplementalWork: foreverFirstSetLastRevision,
      );
      final compiler = const ForeverSequenceCompiler();
      final validation = compiler.validate(
        configuration(secondLeader: otherSecondLeader),
      );

      expect(validation.isValid, isFalse);
      expect(
        validation.issues.map((issue) => issue.code),
        contains('forever.second_leader_revision_mismatch'),
      );
      expect(
        () => compiler.compile(configuration(secondLeader: otherSecondLeader)),
        throwsA(isA<ForeverCompilationException>()),
      );
    });

    test('pairing rejects any unsourced supplemental revision', () {
      const unsupported = CycleRevision(
        id: 'original-plus-unknown',
        version: 1,
        mainWork: foreverOriginalMainWorkRevision,
        supplementalWork: ProgramRevision(
          id: 'unknown',
          version: 1,
          source: RuleSource(document: 'unknown', location: 'unknown'),
        ),
      );

      final compatibility = foreverOriginalFslPairing.evaluate(unsupported);
      expect(compatibility.isCompatible, isFalse);
      expect(
        compatibility.issues.single.code,
        'pairing.supplemental_not_supported',
      );
    });

    test('returns structured profile validation issues', () {
      final invalidProfile = CommonTrainingProfile(
        trainingDaysPerWeek: 3,
        trainingMaxes: const {'press': 0, 'squat': 100},
        progressionIncrements: const {'press': 0},
      );
      final result = const ForeverSequenceCompiler().validate(
        configuration(trainingProfile: invalidProfile),
      );

      expect(result.isValid, isFalse);
      expect(
        result.issues.map((issue) => issue.code),
        containsAll({
          'profile.frequency_not_supported',
          'profile.training_max_invalid',
          'profile.progression_increment_invalid',
        }),
      );
      expect(result.issues.every((issue) => issue.path.isNotEmpty), isTrue);
    });

    test('configuration modes are explicit and typed', () {
      final common = profile();
      final cycle = CyclePlanningConfiguration(
        profile: common,
        revision: foreverOriginalFslCycleRevision,
      );
      final forever = configuration(trainingProfile: common);

      expect(cycle.mode, PlanningMode.cycle);
      expect(forever.mode, PlanningMode.forever);
      expect(forever.kind, ForeverPlanKind.macrocycle);
    });
  });
}
