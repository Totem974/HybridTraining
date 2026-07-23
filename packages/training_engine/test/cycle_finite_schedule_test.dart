import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  const compiler = CycleCompilerImpl();

  test('finite sequence is consumed once and keeps its final partial week', () {
    final cycle = compiler.compileScheduled(
      definition: _definition(),
      schedule: _schedule(),
      selection: _selection,
      request: _request(),
    );

    expect(cycle.weeks, hasLength(2));
    expect(cycle.weeks.first.sessions.map((item) => item.movementId.value), [
      'A',
      'B',
    ]);
    expect(cycle.weeks.last.sessions, hasLength(1));
    expect(
      cycle.weeks.last.sessions.single.blocks
          .map((block) => block.movementId.value)
          .toList(),
      ['a', 'b'],
      reason: 'The final finite slot groups two sources on the same date.',
    );
    expect(
      cycle.weeks
          .expand((week) => week.sessions)
          .map((session) => session.date)
          .toList(),
      [DateTime(2026, 1, 12), DateTime(2026, 1, 15), DateTime(2026, 1, 19)],
    );
  });

  test('finite schedule requires a resolved sequence', () {
    final invalid = ResolvedCycleSchedule(
      id: 'finite',
      mode: CycleScheduleMode.finite,
      sessions: _templates,
      allowedFrequencies: const {2},
    );

    expect(
      () => compiler.compileScheduled(
        definition: _definition(),
        schedule: invalid,
        selection: _selection,
        request: _request(),
      ),
      throwsA(
        isA<CycleGenerationException>().having(
          (error) => error.code,
          'code',
          CycleGenerationErrorCode.invalidScheduleDefinition,
        ),
      ),
    );
  });

  test('finite schedule rejects an unknown source week', () {
    final invalid = ResolvedCycleSchedule(
      id: 'finite',
      mode: CycleScheduleMode.finite,
      sessions: _templates,
      allowedFrequencies: const {2},
      finiteSlots: const [
        FiniteScheduleSlot(
          sources: [
            FiniteScheduleSource(
              definitionWeekNumber: 99,
              sessionId: SessionId('A'),
            ),
          ],
        ),
      ],
    );

    expect(
      () => compiler.compileScheduled(
        definition: _definition(),
        schedule: invalid,
        selection: _selection,
        request: _request(),
      ),
      throwsA(
        isA<CycleGenerationException>().having(
          (error) => error.code,
          'code',
          CycleGenerationErrorCode.invalidScheduleDefinition,
        ),
      ),
    );
  });
}

const _selection = CycleScheduleSelection(
  trainingDays: [1, 4],
  sessionOrder: [SessionId('A'), SessionId('B')],
);

const _templates = [
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
];

ResolvedCycleSchedule _schedule() => const ResolvedCycleSchedule(
  id: 'finite',
  mode: CycleScheduleMode.finite,
  sessions: _templates,
  allowedFrequencies: {2},
  finiteSlots: [
    FiniteScheduleSlot(
      sources: [
        FiniteScheduleSource(
          definitionWeekNumber: 1,
          sessionId: SessionId('A'),
        ),
      ],
    ),
    FiniteScheduleSlot(
      sources: [
        FiniteScheduleSource(
          definitionWeekNumber: 1,
          sessionId: SessionId('B'),
        ),
      ],
    ),
    FiniteScheduleSlot(
      sources: [
        FiniteScheduleSource(
          definitionWeekNumber: 2,
          sessionId: SessionId('A'),
        ),
        FiniteScheduleSource(
          definitionWeekNumber: 2,
          sessionId: SessionId('B'),
        ),
      ],
    ),
  ],
);

ResolvedCycleDefinition _definition() => ResolvedCycleDefinition(
  catalogVersion: 2,
  templateId: 'finite',
  variantId: 'finite',
  sessionMovementIds: const [MovementId('A'), MovementId('B')],
  sourceReference: 'test',
  scheduleReference: const ComponentReference('finite', 1),
  scheduleMode: CycleScheduleMode.finite,
  weeks: [
    for (var week = 1; week <= 2; week++)
      WeekDefinition(
        number: week,
        sessions: [
          for (final item in const [('A', 'a'), ('B', 'b')])
            SessionDefinition(
              id: MovementId(item.$1),
              role: item.$1,
              blocks: [
                BlockDefinition(
                  id: 'w$week-${item.$1}',
                  role: 'main_work',
                  movementId: MovementId(item.$2),
                  sets: [
                    PrescribedSetDefinition(
                      repetitions: const FixedRepetitions(5),
                      load: TrainingMaxPercentageLoad(
                        Percentage(week == 1 ? 6500 : 7500),
                      ),
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
  cycleId: 'finite',
  startDate: DateTime(2026, 1, 10),
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
