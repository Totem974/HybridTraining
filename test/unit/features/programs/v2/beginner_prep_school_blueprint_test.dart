import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/beginner_prep_school_blueprint.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/forever_macrocycle_generator.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain_validator.dart';

void main() {
  const ratios = {
    MainLift.squat: .85,
    MainLift.benchPress: .90,
    MainLift.deadlift: .85,
    MainLift.overheadPress: .90,
  };

  test('blueprint Beginner Prep School v1 is complete and valid', () {
    final snapshot = BeginnerPrepSchoolBlueprint.create(
      trainingMaxRatios: ratios,
    );
    expect(snapshot.blueprint.id.value, beginnerPrepSchoolPresetId);
    final validation = const ProgramDomainValidator().validate(
      ComposableProgramDomain(
        concepts: const [
          ProgramConcept(
            id: ProgramConceptId('program.beginner-prep-school'),
            titleKey: 'program.beginner_prep_school',
            origin: MethodGeneration.forever,
          ),
        ],
        revisions: const [
          ProgramRevision(
            id: ProgramRevisionId('forever-beginner-prep-school-v1'),
            conceptId: ProgramConceptId('program.beginner-prep-school'),
            generation: MethodGeneration.forever,
            version: ProgramVersion(1),
            ruleStatus: RuleStatus.verified,
          ),
        ],
        blueprints: [snapshot.blueprint],
      ),
    );
    expect(validation.issues, isEmpty);
    expect(snapshot.blueprint.schedulePolicy!.mainMovementsPerSession, 2);
    expect(snapshot.blueprint.implementationStatus.name, 'available');
  });

  test('generates exact A/B plan, 5s Pro, FSL/SSL and every session block', () {
    final plan = const ForeverMacrocycleGenerator().generate(
      snapshot: BeginnerPrepSchoolBlueprint.create(trainingMaxRatios: ratios),
      athlete: AthletePlanConfiguration(
        trainingMaxes: const {
          MainLift.squat: 100,
          MainLift.benchPress: 100,
          MainLift.deadlift: 100,
          MainLift.overheadPress: 100,
        },
        unit: WeightUnit.kilograms,
        trainingWeekdays: const [1, 3, 5],
        startDate: const LocalDate(2026, 7, 20),
        rounder: const LoadRounder(increment: 2.5),
      ),
    );
    final weeks = plan.blocks.single.cycles.single.weeks;
    expect(
      weeks
          .expand((week) => week.sessions)
          .map((session) => session.date.iso8601),
      [
        '2026-07-20',
        '2026-07-22',
        '2026-07-24',
        '2026-07-27',
        '2026-07-29',
        '2026-07-31',
        '2026-08-03',
        '2026-08-05',
        '2026-08-07',
      ],
    );
    expect(_mainLifts(weeks[0].sessions[0]), [
      MainLift.squat,
      MainLift.benchPress,
    ]);
    expect(_mainLifts(weeks[0].sessions[1]), [
      MainLift.deadlift,
      MainLift.overheadPress,
    ]);
    expect(_mainLifts(weeks[1].sessions[0]), [
      MainLift.deadlift,
      MainLift.overheadPress,
    ]);
    expect(
      weeks.first.sessions.first.blocks.map((block) => block.kind).toSet(),
      GeneratedSessionBlockKind.values.toSet(),
    );
    expect(
      _sets(
        weeks[0].sessions[0],
        MainLift.squat,
        SetKind.main,
      ).map((set) => set.repetitions),
      [5, 5, 5],
    );
    expect(
      _sets(
        weeks[0].sessions[0],
        MainLift.squat,
        SetKind.supplemental,
      ).map((set) => set.percentage),
      [.80, .80, .80, .80, .80],
    );
    expect(
      _sets(
        weeks[0].sessions[0],
        MainLift.benchPress,
        SetKind.supplemental,
      ).map((set) => set.percentage),
      [.70, .70, .70, .70, .70],
    );
    expect(plan.events.single.kind, PlannedEventKind.trainingMaxProgression);
    final firstRule = weeks.first.sessions.first.blocks
        .expand((block) => block.prescriptions)
        .first
        .rule;
    expect(firstRule.document, '5/3/1 Forever');
    expect(firstRule.location, contains('BPS-MAIN-001'));
  });

  test('every executable prescription carries a RuleId and source pages', () {
    final plan = const ForeverMacrocycleGenerator().generate(
      snapshot: BeginnerPrepSchoolBlueprint.create(trainingMaxRatios: ratios),
      athlete: AthletePlanConfiguration(
        trainingMaxes: const {
          MainLift.squat: 100,
          MainLift.benchPress: 100,
          MainLift.deadlift: 100,
          MainLift.overheadPress: 100,
        },
        unit: WeightUnit.kilograms,
        trainingWeekdays: const [1, 3, 5],
        startDate: const LocalDate(2026, 7, 20),
        rounder: const LoadRounder(increment: 2.5),
      ),
    );
    final rules = plan.blocks
        .expand((block) => block.cycles)
        .expand((cycle) => cycle.weeks)
        .expand((week) => week.sessions)
        .expand((session) => session.blocks)
        .expand((block) => block.prescriptions)
        .map((set) => set.rule);
    expect(rules, isNotEmpty);
    for (final rule in rules) {
      expect(rule.document, '5/3/1 Forever');
      expect(rule.location, contains(RegExp(r'BPS-[A-Z]+-\d{3}')));
      expect(rule.location, contains('PDF'));
    }
  });

  test('warm-up, jumps, assistance and conditioning are executable', () {
    final plan = const ForeverMacrocycleGenerator().generate(
      snapshot: BeginnerPrepSchoolBlueprint.create(trainingMaxRatios: ratios),
      athlete: AthletePlanConfiguration(
        trainingMaxes: const {
          MainLift.squat: 100,
          MainLift.benchPress: 100,
          MainLift.deadlift: 100,
          MainLift.overheadPress: 100,
        },
        unit: WeightUnit.kilograms,
        trainingWeekdays: const [1, 3, 5],
        startDate: const LocalDate(2026, 7, 20),
        rounder: const LoadRounder(increment: 2.5),
      ),
    );
    final activities = plan.blocks
        .expand((block) => block.cycles)
        .expand((cycle) => cycle.weeks)
        .expand((week) => week.sessions)
        .expand((session) => session.blocks)
        .expand((block) => block.activities)
        .toList();
    expect(activities, hasLength(81));
    expect(activities.map((activity) => activity.kind).toSet(), {
      PrescriptionKind.warmUp,
      PrescriptionKind.jumpsOrThrows,
      PrescriptionKind.assistance,
      PrescriptionKind.easyConditioning,
    });
    for (final activity in activities) {
      expect(
        const ProgramDomainValidator().validatePrescription(activity).isValid,
        isTrue,
        reason: activity.id.value,
      );
    }
  });

  test('uses the injected rounding policy for kg and lb', () {
    for (final data in [
      (WeightUnit.kilograms, 2.5),
      (WeightUnit.pounds, 5.0),
    ]) {
      final plan = const ForeverMacrocycleGenerator().generate(
        snapshot: BeginnerPrepSchoolBlueprint.create(trainingMaxRatios: ratios),
        athlete: AthletePlanConfiguration(
          trainingMaxes: const {
            MainLift.squat: 101,
            MainLift.benchPress: 101,
            MainLift.deadlift: 101,
            MainLift.overheadPress: 101,
          },
          unit: data.$1,
          trainingWeekdays: const [1, 3, 5],
          startDate: const LocalDate(2026, 7, 20),
          rounder: LoadRounder(increment: data.$2),
        ),
      );
      expect(
        plan
            .blocks
            .single
            .cycles
            .single
            .weeks
            .first
            .sessions
            .first
            .blocks[2]
            .prescriptions
            .first
            .roundingIncrement,
        data.$2,
      );
    }
  });

  test('rejects an undocumented TM ratio', () {
    expect(
      () => BeginnerPrepSchoolBlueprint.create(
        trainingMaxRatios: {...ratios, MainLift.squat: .80},
      ),
      throwsArgumentError,
    );
  });
}

List<MainLift> _mainLifts(GeneratedSession session) => session.blocks
    .where((block) => block.kind == GeneratedSessionBlockKind.mainWork)
    .expand((block) => block.prescriptions)
    .map((set) => set.movement)
    .toSet()
    .toList();

List<GeneratedPrescription> _sets(
  GeneratedSession session,
  MainLift lift,
  SetKind kind,
) => session.blocks
    .expand((block) => block.prescriptions)
    .where((set) => set.movement == lift && set.setKind == kind)
    .toList();
