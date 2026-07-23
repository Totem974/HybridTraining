import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _sessionIds = ['A', 'B', 'C', 'D'];
const _movementIds = ['a', 'b', 'c', 'd'];

void main() {
  const compiler = CycleCompilerImpl();

  test('rotating three days preserves the source wave for every token', () {
    final definition = _fourLiftDefinition(CycleScheduleMode.rotating);
    final schedule = _fourLiftSchedule(CycleScheduleMode.rotating, const {3});
    final request = _request(const [1, 3, 5]);
    final cycle = compiler.compileScheduled(
      definition: definition,
      schedule: schedule,
      selection: _selection(const [1, 3, 5]),
      request: request,
    );

    expect(cycle.weeks, hasLength(5));
    expect(_sessionSequence(cycle.weeks.take(4)), [
      ['A', 'B', 'C'],
      ['D', 'A', 'B'],
      ['C', 'D', 'A'],
      ['B', 'C', 'D'],
    ]);
    expect(
      cycle.weeks[1].sessions
          .map(
            (session) =>
                session.blocks.single.sets.single.percentageBasisPoints,
          )
          .toList(),
      [6500, 7500, 7500],
      reason: 'D remains on wave 1 while A and B have advanced to wave 2.',
    );
    expect(
      cycle.weeks[2].sessions
          .map(
            (session) =>
                session.blocks.single.sets.single.percentageBasisPoints,
          )
          .toList(),
      [7500, 7500, 8500],
    );
    expect(
      cycle.weeks.last.sessions
          .map(
            (session) =>
                session.blocks.map((block) => block.movementId.value).toList(),
          )
          .toList(),
      [
        ['a', 'b'],
        ['c'],
        ['d'],
      ],
    );
    expect(cycle.weeks.last.sessions.map((session) => session.date).toList(), [
      DateTime(2026, 2, 9),
      DateTime(2026, 2, 11),
      DateTime(2026, 2, 13),
    ]);
  });

  test('rotating two days groups deload as AB then CD', () {
    final definition = _fourLiftDefinition(CycleScheduleMode.rotating);
    final schedule = _fourLiftSchedule(CycleScheduleMode.rotating, const {2});
    final cycle = compiler.compileScheduled(
      definition: definition,
      schedule: schedule,
      selection: _selection(const [1, 4]),
      request: _request(const [1, 4]),
    );

    expect(cycle.weeks, hasLength(7));
    expect(_sessionSequence(cycle.weeks.take(6)), [
      ['A', 'B'],
      ['C', 'D'],
      ['A', 'B'],
      ['C', 'D'],
      ['A', 'B'],
      ['C', 'D'],
    ]);
    expect(
      cycle.weeks.last.sessions
          .map(
            (session) =>
                session.blocks.map((block) => block.movementId.value).toList(),
          )
          .toList(),
      [
        ['a', 'b'],
        ['c', 'd'],
      ],
    );
    expect(cycle.weeks.last.sessions.map((session) => session.date).toList(), [
      DateTime(2026, 2, 23),
      DateTime(2026, 2, 26),
    ]);
  });

  test('disabled deload removes the complete structural week', () {
    for (final entry in const [
      (days: [1, 3, 5], expectedWeeks: 4),
      (days: [1, 4], expectedWeeks: 6),
    ]) {
      final schedule = _fourLiftSchedule(CycleScheduleMode.rotating, {
        entry.days.length,
      });
      final cycle = compiler.compileScheduled(
        definition: _fourLiftDefinition(CycleScheduleMode.rotating),
        schedule: schedule,
        selection: _selection(entry.days),
        request: _request(entry.days, includeDeload: false),
      );
      expect(cycle.weeks, hasLength(entry.expectedWeeks));
      expect(
        cycle.weeks
            .expand((week) => week.sessions)
            .expand((session) => session.blocks)
            .where((block) => block.role == 'deload'),
        isEmpty,
      );
    }
  });

  test('assistance follows existing sessions, including deload', () {
    const assistance = ResolvedAssistancePlan(
      id: 'test_assistance',
      revision: 1,
      slots: [
        AssistanceSessionSlot(
          id: 'a_assistance',
          sessionRole: 'a',
          prescriptions: [
            AssistanceExercisePrescription(
              exerciseId: 'pull_up',
              volume: FixedAssistanceVolume(setCount: 2, repetitions: 10),
              load: AssistanceLoadKind.bodyweight,
            ),
          ],
        ),
      ],
    );
    GeneratedCycle compile({required bool includeDeload}) =>
        compiler.compileScheduled(
          definition: _fourLiftDefinition(CycleScheduleMode.fixed),
          schedule: _fourLiftSchedule(CycleScheduleMode.fixed, const {4}),
          selection: _selection(const [1, 2, 4, 5]),
          request: _request(const [1, 2, 4, 5], includeDeload: includeDeload),
          assistancePlans: const [assistance],
        );

    final withDeload = compile(includeDeload: true);
    final withoutDeload = compile(includeDeload: false);
    List<GeneratedBlock> assistanceBlocks(GeneratedCycle cycle) => cycle.weeks
        .expand((week) => week.sessions)
        .expand((session) => session.blocks)
        .where((block) => block.role == 'assistance')
        .toList();

    expect(withDeload.weeks, hasLength(4));
    expect(assistanceBlocks(withDeload), hasLength(4));
    expect(
      assistanceBlocks(
        withDeload,
      ).last.sets.map((set) => set.repetitions['count']),
      [10, 10],
      reason: 'assistance remains on an existing deload session',
    );
    expect(withoutDeload.weeks, hasLength(3));
    expect(assistanceBlocks(withoutDeload), hasLength(3));
  });

  test('fixed schedule keeps one source wave per displayed week', () {
    final cycle = compiler.compileScheduled(
      definition: _fourLiftDefinition(CycleScheduleMode.fixed),
      schedule: _fourLiftSchedule(CycleScheduleMode.fixed, const {4}),
      selection: _selection(const [1, 2, 4, 5]),
      request: _request(const [1, 2, 4, 5]),
    );

    expect(cycle.weeks, hasLength(4));
    expect(cycle.weeks.last.sessions.map((session) => session.date).toList(), [
      DateTime(2026, 2, 2),
      DateTime(2026, 2, 3),
      DateTime(2026, 2, 5),
      DateTime(2026, 2, 6),
    ]);
  });

  test('multi-movement templates remain one generated session per date', () {
    final definition = _pairedDefinition();
    final schedule = ResolvedCycleSchedule(
      id: 'paired_schedule',
      mode: CycleScheduleMode.multiMovement,
      sessions: const [
        ScheduleSessionTemplate(
          id: SessionId('AB'),
          role: 'multiLift',
          movementIds: [MovementId('a'), MovementId('b')],
        ),
        ScheduleSessionTemplate(
          id: SessionId('CD'),
          role: 'multiLift',
          movementIds: [MovementId('c'), MovementId('d')],
        ),
      ],
      allowedFrequencies: const {2},
    );
    final request = _request(const [1, 4], sessionIds: const ['AB', 'CD']);
    final cycle = compiler.compileScheduled(
      definition: definition,
      schedule: schedule,
      selection: const CycleScheduleSelection(
        trainingDays: [1, 4],
        sessionOrder: [SessionId('AB'), SessionId('CD')],
      ),
      request: request,
    );

    expect(cycle.weeks.single.sessions, hasLength(2));
    expect(
      cycle.weeks.single.sessions.first.blocks
          .map((block) => block.movementId.value)
          .toList(),
      ['a', 'b'],
    );
    expect(cycle.weeks.single.sessions.first.movementId.value, 'AB');
  });

  test(
    'movement-major order groups complete lift work after joker overlays',
    () {
      ResolvedCycleSchedule schedule(SessionBlockOrder order) =>
          ResolvedCycleSchedule(
            id: 'paired_schedule',
            mode: CycleScheduleMode.multiMovement,
            sessionBlockOrder: order,
            sessions: const [
              ScheduleSessionTemplate(
                id: SessionId('AB'),
                role: 'multiLift',
                movementIds: [MovementId('a'), MovementId('b')],
              ),
              ScheduleSessionTemplate(
                id: SessionId('CD'),
                role: 'multiLift',
                movementIds: [MovementId('c'), MovementId('d')],
              ),
            ],
            allowedFrequencies: const {2},
          );
      GeneratedCycle compile(SessionBlockOrder order) =>
          compiler.compileScheduled(
            definition: _interleavedPairedDefinition(),
            schedule: schedule(order),
            selection: const CycleScheduleSelection(
              trainingDays: [1, 4],
              sessionOrder: [SessionId('AB'), SessionId('CD')],
            ),
            request: _request(
              const [1, 4],
              sessionIds: const ['AB', 'CD'],
              cycleOptions: const CycleExecutionOptions(
                joker: JokerExecutionOptions(
                  enabled: true,
                  ceilingBasisPoints: 500,
                ),
              ),
            ),
          );
      List<String> firstSession(GeneratedCycle cycle) => cycle
          .weeks
          .single
          .sessions
          .first
          .blocks
          .map((block) => '${block.movementId.value}:${block.role}')
          .toList(growable: false);

      expect(firstSession(compile(SessionBlockOrder.componentMajor)), [
        'a:warm_up',
        'b:warm_up',
        'a:main_work',
        'a:joker',
        'b:main_work',
        'b:joker',
        'accessory:assistance',
      ]);
      expect(firstSession(compile(SessionBlockOrder.movementMajor)), [
        'a:warm_up',
        'a:main_work',
        'a:joker',
        'b:warm_up',
        'b:main_work',
        'b:joker',
        'accessory:assistance',
      ]);
    },
  );

  test('invalid frequency and session order are rejected structurally', () {
    final definition = _fourLiftDefinition(CycleScheduleMode.rotating);
    final schedule = _fourLiftSchedule(CycleScheduleMode.rotating, const {3});

    expect(
      () => compiler.compileScheduled(
        definition: definition,
        schedule: schedule,
        selection: _selection(const [1, 4]),
        request: _request(const [1, 4]),
      ),
      throwsA(
        isA<CycleGenerationException>().having(
          (error) => error.code,
          'code',
          CycleGenerationErrorCode.invalidScheduleFrequency,
        ),
      ),
    );
    expect(
      () => compiler.compileScheduled(
        definition: definition,
        schedule: schedule,
        selection: const CycleScheduleSelection(
          trainingDays: [1, 3, 5],
          sessionOrder: [
            SessionId('A'),
            SessionId('B'),
            SessionId('C'),
            SessionId('C'),
          ],
        ),
        request: _request(
          const [1, 3, 5],
          sessionIds: const ['A', 'B', 'C', 'C'],
        ),
      ),
      throwsA(
        isA<CycleGenerationException>().having(
          (error) => error.code,
          'code',
          CycleGenerationErrorCode.invalidSessionOrder,
        ),
      ),
    );
  });
}

List<List<String>> _sessionSequence(Iterable<GeneratedWeek> weeks) => [
  for (final week in weeks)
    [for (final session in week.sessions) session.movementId.value],
];

CycleScheduleSelection _selection(List<int> days) => CycleScheduleSelection(
  trainingDays: days,
  sessionOrder: const [
    SessionId('A'),
    SessionId('B'),
    SessionId('C'),
    SessionId('D'),
  ],
);

ResolvedCycleSchedule _fourLiftSchedule(
  CycleScheduleMode mode,
  Set<int> frequencies,
) => ResolvedCycleSchedule(
  id: 'schedule',
  mode: mode,
  sessions: [
    for (var index = 0; index < _sessionIds.length; index++)
      ScheduleSessionTemplate(
        id: SessionId(_sessionIds[index]),
        role: 'mainLift',
        movementIds: [MovementId(_movementIds[index])],
      ),
  ],
  allowedFrequencies: frequencies,
);

ResolvedCycleDefinition _fourLiftDefinition(CycleScheduleMode mode) =>
    ResolvedCycleDefinition(
      catalogVersion: 2,
      templateId: 'test',
      variantId: mode.name,
      sessionMovementIds: [for (final id in _sessionIds) MovementId(id)],
      sourceReference: 'test',
      scheduleReference: const ComponentReference('schedule', 1),
      scheduleMode: mode,
      weeks: [
        for (var wave = 1; wave <= 4; wave++)
          WeekDefinition(
            number: wave,
            sessions: [
              for (var index = 0; index < _sessionIds.length; index++)
                SessionDefinition(
                  id: MovementId(_sessionIds[index]),
                  role: _sessionIds[index],
                  sourceRole: 'mainLift',
                  blocks: [
                    BlockDefinition(
                      id: 'w$wave-${_sessionIds[index]}',
                      role: wave == 4 ? 'deload' : 'main_work',
                      movementId: MovementId(_movementIds[index]),
                      sets: [
                        PrescribedSetDefinition(
                          repetitions: const FixedRepetitions(5),
                          load: TrainingMaxPercentageLoad(
                            Percentage([0, 6500, 7500, 8500, 4000][wave]),
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

ResolvedCycleDefinition _pairedDefinition() => ResolvedCycleDefinition(
  catalogVersion: 2,
  templateId: 'paired',
  variantId: 'paired',
  sessionMovementIds: const [MovementId('AB'), MovementId('CD')],
  sourceReference: 'test',
  scheduleReference: const ComponentReference('paired_schedule', 1),
  scheduleMode: CycleScheduleMode.multiMovement,
  weeks: [
    WeekDefinition(
      number: 1,
      sessions: [
        for (final pair in const [
          (session: 'AB', movements: ['a', 'b']),
          (session: 'CD', movements: ['c', 'd']),
        ])
          SessionDefinition(
            id: MovementId(pair.session),
            role: pair.session,
            sourceRole: 'multiLift',
            blocks: [
              for (final movement in pair.movements)
                BlockDefinition(
                  id: 'main-$movement',
                  role: 'main_work',
                  movementId: MovementId(movement),
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

ResolvedCycleDefinition _interleavedPairedDefinition() =>
    ResolvedCycleDefinition(
      catalogVersion: 2,
      templateId: 'paired',
      variantId: 'ordered-paired',
      sessionMovementIds: const [MovementId('AB'), MovementId('CD')],
      sourceReference: 'test',
      scheduleReference: const ComponentReference('paired_schedule', 1),
      scheduleMode: CycleScheduleMode.multiMovement,
      optionRecipes: const ResolvedCycleOptionRecipes(
        joker: ResolvedJokerRecipe(
          blockId: 'joker',
          steps: [
            JokerRecipeStep(
              cumulativeIncreaseBasisPoints: 500,
              repetitions: FixedRepetitions(5),
            ),
          ],
        ),
      ),
      weeks: [
        WeekDefinition(
          number: 1,
          sessions: [
            SessionDefinition(
              id: const MovementId('AB'),
              role: 'AB',
              sourceRole: 'multiLift',
              blocks: [
                for (final entry in const [
                  (id: 'warm-a', role: 'warm_up', movement: 'a'),
                  (id: 'warm-b', role: 'warm_up', movement: 'b'),
                  (id: 'main-a', role: 'main_work', movement: 'a'),
                  (id: 'main-b', role: 'main_work', movement: 'b'),
                ])
                  BlockDefinition(
                    id: entry.id,
                    role: entry.role,
                    movementId: MovementId(entry.movement),
                    sets: const [
                      PrescribedSetDefinition(
                        repetitions: FixedRepetitions(5),
                        load: TrainingMaxPercentageLoad(Percentage(5000)),
                      ),
                    ],
                  ),
                const BlockDefinition(
                  id: 'accessory',
                  role: 'assistance',
                  movementId: MovementId('accessory'),
                  sets: [
                    PrescribedSetDefinition(
                      repetitions: FixedRepetitions(10),
                      load: Unloaded(),
                    ),
                  ],
                ),
              ],
            ),
            SessionDefinition(
              id: const MovementId('CD'),
              role: 'CD',
              sourceRole: 'multiLift',
              blocks: [
                for (final movement in const ['c', 'd'])
                  BlockDefinition(
                    id: 'main-$movement',
                    role: 'main_work',
                    movementId: MovementId(movement),
                    sets: const [
                      PrescribedSetDefinition(
                        repetitions: FixedRepetitions(5),
                        load: TrainingMaxPercentageLoad(Percentage(5000)),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ],
    );

CycleRequest _request(
  List<int> days, {
  bool includeDeload = true,
  List<String> sessionIds = _sessionIds,
  CycleExecutionOptions cycleOptions = const CycleExecutionOptions(),
}) => CycleRequest(
  cycleId: 'scheduled',
  startDate: DateTime(2026, 1, 10),
  trainingDays: days,
  sessionOrder: [for (final id in sessionIds) MovementId(id)],
  maxInputs: const {
    MovementId('a'): DirectTrainingMaxInput(Weight(10000, WeightUnit.kg)),
    MovementId('b'): DirectTrainingMaxInput(Weight(10000, WeightUnit.kg)),
    MovementId('c'): DirectTrainingMaxInput(Weight(10000, WeightUnit.kg)),
    MovementId('d'): DirectTrainingMaxInput(Weight(10000, WeightUnit.kg)),
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
  includeDeload: includeDeload,
  cycleOptions: cycleOptions,
);
