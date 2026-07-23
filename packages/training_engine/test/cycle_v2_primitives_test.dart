import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _press = MovementId('overhead_press');
const _deadlift = MovementId('deadlift');

void main() {
  test(
    'v2 identifiers and schedule models distinguish sessions from movements',
    () {
      const sessionId = SessionId('day_a');
      const exerciseId = ExerciseId('pull_up');
      final session = ScheduleSessionTemplate(
        id: sessionId,
        role: 'main',
        movementIds: [_press, _deadlift],
      );
      final schedule = ResolvedCycleSchedule(
        id: 'rotating_three_day',
        mode: CycleScheduleMode.rotating,
        sessions: [session],
        allowedFrequencies: {2, 3},
      );
      final selection = CycleScheduleSelection(
        trainingDays: [1, 3, 5],
        sessionOrder: [sessionId],
      );

      expect(sessionId.value, 'day_a');
      expect(exerciseId.value, 'pull_up');
      expect(CycleScheduleMode.values, [
        CycleScheduleMode.fixed,
        CycleScheduleMode.rotating,
        CycleScheduleMode.multiMovement,
      ]);
      expect(schedule.sessions.single.movementIds, [_press, _deadlift]);
      expect(schedule.allowedFrequencies, {2, 3});
      expect(selection.sessionOrder.single, isA<SessionId>());
    },
  );

  test('main-work execution options default to catalog policy', () {
    const defaults = MainWorkExecutionOptions();
    expect(defaults.weekOrder, WorkWeekOrder.catalog);
    expect(defaults.setOrder, WorkSetOrder.catalog);
    expect(defaults.plusSet, PlusSetMode.catalog);
    expect(defaults.plusSetMode, PlusSetMode.catalog);

    const selected = MainWorkExecutionOptions(
      weekOrder: WorkWeekOrder.threeFiveOne,
      setOrder: WorkSetOrder.bastard,
      plusSet: PlusSetMode.disabled,
    );
    expect(selected.weekOrder, WorkWeekOrder.threeFiveOne);
    expect(selected.setOrder, WorkSetOrder.bastard);
    expect(selected.plusSet, PlusSetMode.disabled);
  });

  test('v2 prescriptions and scoped option values are explicit', () {
    const sessionId = SessionId('day_a');
    const repetitions = PlusSetRepetitions(1);
    const fixed = FixedSetMultiplicity(5);
    const parameterized = ParameterizedSetMultiplicity(
      parameterId: 'set_count',
      defaultValue: 3,
      minimum: 1,
      maximum: 5,
    );
    const values = CycleOptionValues(
      global: {'ratio': 5000},
      byMovement: {
        _press: {'ratio': 5500},
      },
      bySession: {
        sessionId: {'ratio': 6000},
      },
    );

    expect(repetitions.toJson(), {'type': 'plus_set', 'minimum': 1});
    expect(fixed.count, 5);
    expect(parameterized.parameterId, 'set_count');
    expect(parameterized.defaultValue, 3);
    expect(values.global['ratio'], 5000);
    expect(values.byMovement[_press]?['ratio'], 5500);
    expect(values.bySession[sessionId]?['ratio'], 6000);
    expect(const UnconfiguredLoad(), isA<LoadPrescription>());
    expect(const UnconfiguredLoad(), isNot(isA<Unloaded>()));
  });

  test('compiler rejects a load that still requires user configuration', () {
    const definition = ResolvedCycleDefinition(
      catalogVersion: 2,
      templateId: 'test',
      variantId: 'unconfigured',
      sessionMovementIds: [_press],
      sourceReference: 'test',
      weeks: [
        WeekDefinition(
          number: 1,
          sessions: [
            SessionDefinition(
              id: _press,
              role: 'main',
              blocks: [
                BlockDefinition(
                  id: 'unconfigured',
                  role: 'assistance',
                  sets: [
                    PrescribedSetDefinition(
                      repetitions: FixedRepetitions(5),
                      load: UnconfiguredLoad(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final request = CycleRequest(
      cycleId: 'unconfigured',
      startDate: DateTime(2026, 1, 5),
      trainingDays: const [1],
      sessionOrder: const [_press],
      maxInputs: const {
        _press: DirectTrainingMaxInput(Weight(10000, WeightUnit.kg)),
      },
      globalTrainingMaxRatio: const Percentage(10000),
      unit: WeightUnit.kg,
      roundingIncrement: const Weight(100, WeightUnit.kg),
      barProfile: const BarProfile(
        weight: Weight(0, WeightUnit.kg),
        platesPerSide: [Weight(100, WeightUnit.kg)],
      ),
    );

    expect(
      () => const CycleCompilerImpl().compile(definition, request),
      throwsA(
        isA<CycleGenerationException>().having(
          (error) => error.code,
          'code',
          CycleGenerationErrorCode.invalidCycleOptions,
        ),
      ),
    );
  });
}
