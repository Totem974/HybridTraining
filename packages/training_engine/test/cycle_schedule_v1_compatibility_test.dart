import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  test('fixed scheduled compilation preserves the v1 JSON projection', () {
    final definition = _definition();
    final request = _request();
    final legacy = const CycleCompilerImpl().compile(definition, request);
    final selection = const CycleV1ScheduleSelectionAdapter().adapt(request);
    final scheduled = const CycleCompilerImpl().compileScheduled(
      definition: definition,
      schedule: const ResolvedCycleSchedule(
        id: 'fixed',
        mode: CycleScheduleMode.fixed,
        sessions: [
          ScheduleSessionTemplate(
            id: SessionId('A'),
            role: 'mainLift',
            movementIds: [MovementId('a')],
          ),
          ScheduleSessionTemplate(
            id: SessionId('B'),
            role: 'mainLift',
            movementIds: [MovementId('b')],
          ),
        ],
        allowedFrequencies: {2},
      ),
      selection: selection,
      request: request,
    );

    expect(scheduled.toJson(), legacy.toJson());
    expect(scheduled.toJson().keys, {
      'schemaVersion',
      'id',
      'catalogVersion',
      'templateId',
      'variantId',
      'effectiveTrainingMaxes',
      'weeks',
    });
  });
}

ResolvedCycleDefinition _definition() => ResolvedCycleDefinition(
  catalogVersion: 2,
  templateId: 'fixed',
  variantId: 'fixed',
  sessionMovementIds: const [MovementId('A'), MovementId('B')],
  sourceReference: 'test',
  scheduleReference: const ComponentReference('fixed', 1),
  scheduleMode: CycleScheduleMode.fixed,
  weeks: [
    WeekDefinition(
      number: 1,
      sessions: [
        for (final item in const [('A', 'a'), ('B', 'b')])
          SessionDefinition(
            id: MovementId(item.$1),
            role: item.$1,
            blocks: [
              BlockDefinition(
                id: 'main-${item.$1}',
                role: 'main_work',
                movementId: MovementId(item.$2),
                sets: const [
                  PrescribedSetDefinition(
                    repetitions: FixedRepetitions(5),
                    load: TrainingMaxPercentageLoad(Percentage(6500)),
                  ),
                ],
              ),
            ],
          ),
      ],
    ),
  ],
);

CycleRequest _request() => CycleRequest(
  cycleId: 'fixed',
  startDate: DateTime(2026, 1, 5),
  trainingDays: const [1, 4],
  sessionOrder: const [MovementId('A'), MovementId('B')],
  maxInputs: const {
    MovementId('a'): DirectTrainingMaxInput(Weight(10000, WeightUnit.kg)),
    MovementId('b'): DirectTrainingMaxInput(Weight(10000, WeightUnit.kg)),
  },
  globalTrainingMaxRatio: const Percentage(10000),
  unit: WeightUnit.kg,
  roundingIncrement: const Weight(100, WeightUnit.kg),
  barProfile: const BarProfile(
    weight: Weight(0, WeightUnit.kg),
    platesPerSide: [
      Weight(50, WeightUnit.kg),
      Weight(100, WeightUnit.kg),
      Weight(200, WeightUnit.kg),
      Weight(400, WeightUnit.kg),
      Weight(800, WeightUnit.kg),
      Weight(1600, WeightUnit.kg),
      Weight(3200, WeightUnit.kg),
    ],
  ),
);
