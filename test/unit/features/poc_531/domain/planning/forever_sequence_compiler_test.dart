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
    series: createForeverOriginalFslSeries(
      profile: trainingProfile ?? profile(),
      secondLeader: secondLeader,
    ),
  );

  group('ForeverSequenceCompiler', () {
    test('compiles the single sourced 2L/1A recipe', () {
      final result = const ForeverSequenceCompiler().compile(configuration());

      expect(result.nodes.map((node) => node.nodeId), [
        'M1-C1',
        'M1-C2',
        'M1-P1',
        'M1-C3',
        'M1-P2',
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

      expect(protocols[0].afterCycleInstanceId, 'M1-leader-2');
      expect(protocols[1].afterCycleInstanceId, 'M1-anchor-1');
      expect(protocols.every((node) => node.autoInserted), isTrue);
    });

    test('TM projections are tied to node and cycle instance identifiers', () {
      final result = const ForeverSequenceCompiler().compile(configuration());

      expect(result.trainingMaxDecisions.map((item) => item.nodeId), ['M1-C3']);
      expect(result.trainingMaxDecisions.map((item) => item.cycleInstanceId), [
        'M1',
      ]);
      expect(result.trainingMaxDecisions[0].proposedTrainingMaxes, {
        'press': 50,
        'squat': 100,
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

    test('productive transition rejects an unsupported frequency', () {
      final compatibility = foreverOriginalFslPairing.evaluate(frequency: 3);
      expect(compatibility.isCompatible, isFalse);
      expect(
        compatibility.issues.single.code,
        'transition.frequency_not_allowed',
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
