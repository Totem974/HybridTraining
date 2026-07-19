import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';

void main() {
  const rule = RuleReference(document: 'verified', location: 'page');

  test('LocalDate uses calendar arithmetic and stable ordering', () {
    final date = LocalDate.fromDateTime(DateTime.utc(2026, 12, 31, 23));
    expect(date.addDays(1), const LocalDate(2027, 1, 1));
    expect(date.compareTo(const LocalDate(2027, 1, 1)), lessThan(0));
    expect(date.weekday, DateTime.thursday);
    expect(date.hashCode, const LocalDate(2026, 12, 31).hashCode);
  });

  test('serializes every generated nesting and planned event field', () {
    const prescription = GeneratedPrescription(
      movement: MainLift.squat,
      setKind: SetKind.main,
      percentage: .7,
      repetitions: 5,
      trainingMax: 100,
      unroundedLoad: 70,
      load: 70,
      roundingIncrement: 2.5,
      rule: rule,
      isPerformanceSet: true,
    );
    final session = GeneratedSession(
      id: 'session',
      date: const LocalDate(2026, 7, 20),
      blocks: [
        GeneratedSessionBlock(
          kind: GeneratedSessionBlockKind.mainWork,
          prescriptions: const [prescription],
          instructions: const ['reviewed instruction'],
        ),
      ],
    );
    final block = GeneratedPlanBlock(
      id: 'leader',
      role: BlockRole.leader,
      rule: rule,
      cycles: [
        GeneratedCycle(
          number: 1,
          weeks: [
            GeneratedProgrammingWeek(number: 1, sessions: [session]),
          ],
        ),
      ],
    );
    const transition = GeneratedTransition(
      fromBlockId: 'leader',
      toBlockId: 'anchor',
      rule: rule,
    );
    const event = PlannedTrainingEvent(
      kind: PlannedEventKind.trainingMaxProgression,
      afterBlockId: 'leader',
      afterCycleNumber: 1,
      rule: rule,
    );
    final json = GeneratedTrainingPlan(
      schemaVersion: 1,
      blueprintId: const ProgramBlueprintId('blueprint'),
      blueprintVersion: const ProgramVersion(1),
      blueprintSnapshot: '{}',
      unit: WeightUnit.kilograms,
      seed: 531,
      blocks: [block],
      transitions: const [transition],
      events: const [event],
    ).toJson();
    expect(json['seed'], 531);
    expect((json['blocks']! as List).single, containsPair('role', 'leader'));
    expect(
      (json['events']! as List).single,
      containsPair('afterCycleNumber', 1),
    );
    expect(transition.toJson()['toBlockId'], 'anchor');
    expect(event.toJson()['kind'], 'trainingMaxProgression');
  });
}
