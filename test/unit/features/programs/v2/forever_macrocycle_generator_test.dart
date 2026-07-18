import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/original_fsl_program.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/forever_macrocycle_generator.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/original_fsl_macrocycle_adapter.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';

void main() {
  group('ForeverMacrocycleGenerator', () {
    test('génère 2 Leaders, Deload, Anchor et TM Test avec transitions', () {
      final plan = _generate([
        _block('l1', BlockRole.leader),
        _block('l2', BlockRole.leader),
        _block(
          'deload',
          BlockRole.seventhWeek,
          purpose: SeventhWeekPurpose.deload,
        ),
        _block('anchor', BlockRole.anchor),
        _block(
          'tm-test',
          BlockRole.seventhWeek,
          purpose: SeventhWeekPurpose.trainingMaxTest,
        ),
      ]);

      expect(
        plan.blocks.map((block) => block.role),
        orderedEquals([
          BlockRole.leader,
          BlockRole.leader,
          BlockRole.seventhWeek,
          BlockRole.anchor,
          BlockRole.seventhWeek,
        ]),
      );
      expect(plan.transitions, hasLength(4));
      expect(plan.blocks[2].seventhWeekPurpose, SeventhWeekPurpose.deload);
      expect(
        plan.events.map((event) => event.kind),
        contains(PlannedEventKind.trainingMaxTest),
      );
    });

    test('ne crée aucun défaut universel pour 1 Leader + 1 Anchor', () {
      final plan = _generate([
        _block('leader', BlockRole.leader),
        _block('anchor', BlockRole.anchor),
      ]);
      expect(plan.blocks, hasLength(2));
      expect(
        plan.blocks.any((block) => block.role == BlockRole.seventhWeek),
        isFalse,
      );
    });

    test('refuse une 7th Week non typée', () {
      expect(
        () => _generate([_block('seventh-week', BlockRole.seventhWeek)]),
        throwsA(isA<MacrocycleGenerationException>()),
      );
    });

    test('supporte Prep et plusieurs cycles définis par le blueprint', () {
      final plan = _generate([
        _block('prep', BlockRole.prep),
        _block('leader', BlockRole.leader, cycleCount: 3),
      ]);
      expect(plan.blocks.first.role, BlockRole.prep);
      expect(plan.blocks.last.cycles, hasLength(3));
    });

    test('supporte plusieurs mouvements et blocs hétérogènes par séance', () {
      final main = _movementBlock(GeneratedSessionBlockKind.mainWork, [
        MainLift.squat,
        MainLift.benchPress,
      ]);
      final assistance = SessionBlockTemplate(
        kind: GeneratedSessionBlockKind.assistance,
        movements: [_movement(MainLift.overheadPress)],
      );
      final plan = _generate([
        _block('leader', BlockRole.leader, sessionBlocks: [main, assistance]),
      ]);
      final blocks =
          plan.blocks.single.cycles.single.weeks.single.sessions.single.blocks;
      expect(blocks.map((block) => block.kind), [
        GeneratedSessionBlockKind.mainWork,
        GeneratedSessionBlockKind.assistance,
      ]);
      expect(blocks.first.prescriptions.map((set) => set.movement).toSet(), {
        MainLift.squat,
        MainLift.benchPress,
      });
    });

    test(
      'planifie 3 et 4 jours sans dérive UTC, y compris fin de mois/année',
      () {
        final threeDays = _generate(
          [_block('leader', BlockRole.leader, sessionsPerWeek: 3)],
          weekdays: const [1, 3, 5],
          start: const LocalDate(2026, 12, 30),
        );
        expect(_dates(threeDays), ['2026-12-30', '2027-01-01', '2027-01-04']);

        final fourDays = _generate(
          [_block('leader', BlockRole.leader, sessionsPerWeek: 4)],
          weekdays: const [1, 2, 4, 5],
          start: const LocalDate(2026, 1, 30),
        );
        expect(_dates(fourDays), [
          '2026-01-30',
          '2026-02-02',
          '2026-02-03',
          '2026-02-05',
        ]);
      },
    );

    test('applique le rounder fourni en kg et lb', () {
      final kg = _generate([
        _block('leader', BlockRole.leader),
      ], rounder: const LoadRounder(increment: 2.5));
      final lb = _generate(
        [_block('leader', BlockRole.leader)],
        unit: WeightUnit.pounds,
        rounder: const LoadRounder(increment: 5),
        trainingMax: 401,
      );
      expect(_firstSet(kg).load, 70);
      expect(_firstSet(lb).load, 280);
      expect(_firstSet(lb).roundingIncrement, 5);
    });

    test('conserve la source de chaque règle et refuse NEEDS_REVIEW', () {
      final plan = _generate([_block('leader', BlockRole.leader)]);
      expect(_firstSet(plan).rule.document, 'MAIN-ORDER-001');
      expect(plan.blocks.single.rule.document, 'LIFE-PHASE-001');

      expect(
        () => _generate([
          _block('leader', BlockRole.leader, status: RuleStatus.needsReview),
        ]),
        throwsA(isA<MacrocycleGenerationException>()),
      );
    });

    test(
      'le snapshot est canonique, stable et indépendant des mutations source',
      () {
        final canonical = <String, Object?>{
          'z': 1,
          'a': <String, Object?>{'y': 2, 'b': 3},
        };
        final snapshot = _snapshot([
          _block('leader', BlockRole.leader),
        ], canonical);
        final before = snapshot.stableJson();
        canonical['z'] = 99;
        expect(
          () => (snapshot.canonicalJson['a'] as Map<String, Object?>)['b'] = 4,
          throwsUnsupportedError,
        );
        final after = snapshot.stableJson();
        expect(before, '{"a":{"b":3,"y":2},"z":1}');
        expect(after, before);
      },
    );

    test('le JSON généré correspond au golden', () {
      final plan = _generate(
        [_block('leader', BlockRole.leader)],
        weekdays: const [1, 3, 5],
        start: const LocalDate(2026, 7, 20),
      );
      final actual = const JsonEncoder.withIndent('  ').convert(plan.toJson());
      final expected = File(
        'test/fixtures/forever_macrocycle_plan.golden.json',
      ).readAsStringSync();
      expect(actual.trim(), expected.trim());
    });
  });

  test('adapter reproduit exactement forever-original-fsl-v1', () {
    const rounder = LoadRounder(increment: 2.5);
    final athlete = AthletePlanConfiguration(
      trainingMaxes: const {
        MainLift.squat: 180,
        MainLift.benchPress: 120,
        MainLift.deadlift: 200,
        MainLift.overheadPress: 80,
      },
      unit: WeightUnit.kilograms,
      trainingWeekdays: const [1, 2, 4, 5],
      startDate: const LocalDate(2026, 7, 20),
      rounder: rounder,
    );
    final plan = const OriginalFslMacrocycleAdapter().generate(
      athlete: athlete,
      movementOrder: const [
        MainLift.squat,
        MainLift.benchPress,
        MainLift.deadlift,
        MainLift.overheadPress,
      ],
    );
    final weeks = plan.blocks.single.cycles.single.weeks;
    for (var week = 1; week <= 3; week++) {
      for (var movementIndex = 0; movementIndex < 4; movementIndex++) {
        final movement = athlete.trainingMaxes.keys.elementAt(movementIndex);
        final historical = const OriginalFslProgram().buildSession(
          week: week,
          liftMax: LiftMax(
            lift: movement,
            oneRepMax: athlete.trainingMaxes[movement]! / 0.9,
            trainingMaxRatio: 0.9,
            unit: WeightUnit.kilograms,
          ),
          rounder: rounder,
        );
        final generated = weeks[week - 1].sessions[movementIndex].blocks
            .expand((block) => block.prescriptions)
            .toList();
        expect(
          generated.map((set) => set.percentage),
          historical.sets.map((set) => set.percentage),
        );
        expect(
          generated.map((set) => set.repetitions),
          historical.sets.map((set) => set.repetitions),
        );
        expect(
          generated.map((set) => set.load),
          historical.sets.map((set) => set.load),
        );
        expect(
          generated.map((set) => set.isPerformanceSet),
          historical.sets.map((set) => set.isPerformanceSet),
        );
      }
    }
  });
}

const _verifiedMain = ReviewedRule(
  id: 'MAIN-ORDER-001',
  status: RuleStatus.verified,
  source: RuleReference(
    document: 'MAIN-ORDER-001',
    location: 'main-work-specification.md',
  ),
);

MovementTemplate _movement(MainLift movement) => MovementTemplate(
  movement: movement,
  sets: const [
    SetTemplate(
      percentage: 0.70,
      repetitions: 5,
      kind: SetKind.main,
      rule: _verifiedMain,
    ),
  ],
);

SessionBlockTemplate _movementBlock(
  GeneratedSessionBlockKind kind,
  List<MainLift> movements,
) => SessionBlockTemplate(
  kind: kind,
  movements: movements.map(_movement).toList(),
);

MacrocycleBlockDefinition _block(
  String id,
  BlockRole role, {
  SeventhWeekPurpose? purpose,
  int cycleCount = 1,
  int sessionsPerWeek = 1,
  RuleStatus status = RuleStatus.verified,
  List<SessionBlockTemplate>? sessionBlocks,
}) => MacrocycleBlockDefinition(
  templateId: BlockTemplateId(id),
  role: role,
  seventhWeekPurpose: purpose,
  cycleCount: cycleCount,
  weeks: [
    WeekTemplate(
      sessions: [
        for (var index = 0; index < sessionsPerWeek; index++)
          SessionTemplate(
            blocks:
                sessionBlocks ??
                [
                  _movementBlock(GeneratedSessionBlockKind.mainWork, [
                    MainLift.squat,
                  ]),
                ],
          ),
      ],
    ),
  ],
  rule: ReviewedRule(
    id: 'LIFE-PHASE-001',
    status: status,
    source: const RuleReference(
      document: 'LIFE-PHASE-001',
      location: 'cycle-lifecycle-specification.md',
    ),
  ),
);

GeneratedTrainingPlan _generate(
  List<MacrocycleBlockDefinition> blocks, {
  List<int> weekdays = const [1, 3, 5],
  LocalDate start = const LocalDate(2026, 7, 20),
  WeightUnit unit = WeightUnit.kilograms,
  LoadRounder rounder = const LoadRounder(increment: 2.5),
  double trainingMax = 100,
}) => const ForeverMacrocycleGenerator().generate(
  snapshot: _snapshot(blocks),
  athlete: AthletePlanConfiguration(
    trainingMaxes: {
      MainLift.squat: trainingMax,
      MainLift.benchPress: trainingMax,
      MainLift.deadlift: trainingMax,
      MainLift.overheadPress: trainingMax,
    },
    unit: unit,
    trainingWeekdays: weekdays,
    startDate: start,
    rounder: rounder,
  ),
);

ProgramBlueprintSnapshot _snapshot(
  List<MacrocycleBlockDefinition> blocks, [
  Map<String, Object?>? canonical,
]) {
  final templates = [
    for (final block in blocks)
      BlockTemplate(
        id: block.templateId,
        role: block.role,
        seventhWeekPurpose: block.seventhWeekPurpose,
      ),
  ];
  final transitions = <BlockTransition>{
    for (var index = 1; index < blocks.length; index++)
      BlockTransition(blocks[index - 1].role, blocks[index].role),
  };
  final blueprint = ProgramBlueprint(
    id: const ProgramBlueprintId('test.forever.v1'),
    version: const ProgramVersion(1),
    revisionIds: const [ProgramRevisionId('test-revision')],
    capabilities: const {
      ProgramCapability.mainWork,
      ProgramCapability.multipleMainMovements,
    },
    trainingMaxPolicy: const TrainingMaxPolicy(
      PolicyId('tm'),
      ProgramVersion(1),
      ruleStatus: RuleStatus.verified,
    ),
    mainWorkPolicy: const MainWorkPolicy(
      PolicyId('main'),
      ProgramVersion(1),
      ruleStatus: RuleStatus.verified,
    ),
    schedulePolicy: const SchedulePolicy(
      PolicyId('schedule'),
      ProgramVersion(1),
      supportedFrequencies: {3, 4},
      recommendedFrequency: 3,
      mainMovementsPerSession: 2,
      ruleStatus: RuleStatus.verified,
    ),
    blockTemplates: templates,
    blockSequence: BlockSequence(
      blocks: [
        for (var index = 0; index < blocks.length; index++)
          BlockSequenceEntry(
            templateId: blocks[index].templateId,
            order: index,
          ),
      ],
    ),
    transitionPolicy: TransitionPolicy(
      const PolicyId('transition'),
      const ProgramVersion(1),
      allowedTransitions: transitions,
      ruleStatus: RuleStatus.verified,
    ),
    compatibility: const CompatibilityConstraint(supportedFrequencies: {3, 4}),
    implementationStatus: ImplementationStatus.available,
    generatorId: 'forever-macrocycle',
  );
  final immutableCanonical =
      jsonDecode(
            jsonEncode(canonical ?? {'version': 1, 'id': 'test.forever.v1'}),
          )
          as Map<String, Object?>;
  return ProgramBlueprintSnapshot(
    blueprint: blueprint,
    blocks: blocks,
    canonicalJson: immutableCanonical,
  );
}

List<String> _dates(GeneratedTrainingPlan plan) => plan
    .blocks
    .single
    .cycles
    .single
    .weeks
    .single
    .sessions
    .map((session) => session.date.iso8601)
    .toList();

GeneratedPrescription _firstSet(GeneratedTrainingPlan plan) => plan
    .blocks
    .first
    .cycles
    .first
    .weeks
    .first
    .sessions
    .first
    .blocks
    .first
    .prescriptions
    .first;
