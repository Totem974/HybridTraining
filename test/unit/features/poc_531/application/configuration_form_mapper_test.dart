import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/application/configuration_form_mapper.dart';
import 'package:hybrid_training/features/poc_531/domain/core.dart';

void main() {
  test('maps the exact validated Core configuration without recalculation', () {
    final configuration = ProgramConfiguration(
      programId: 'beyond-six-week-cycle-v1',
      generation: Generation.beyond,
      unit: WeightUnit.pounds,
      lifts: {
        for (final lift in MainLift.values)
          lift: LiftInput(
            lift: lift,
            kind: LiftInputKind.repetitionMax,
            weight: 200 + lift.index.toDouble(),
            repetitions: 5,
          ),
      },
      trainingMaxRatio: .85,
      daysPerWeek: 3,
      trainingWeekdays: const [1, 3, 5],
      startDate: DateTime.utc(2026, 7, 20),
    );

    final form = programConfigurationToForm(configuration);
    expect(form['programId'], configuration.programId);
    expect(form['generation'], 'beyond');
    expect(form['unit'], 'lb');
    expect(form['inputMode'], 'Rep max');
    expect(form['trainingMaxRatio'], 85);
    expect((form['lifts'] as Map)['Squat'], 200);
    expect((form['repetitions'] as Map)['Deadlift'], 5);
  });
}
