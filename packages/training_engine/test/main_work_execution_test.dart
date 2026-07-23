import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _press = MovementId('press');

void main() {
  const compiler = CycleCompilerImpl();

  test('1+ set input resolves TM from the canonical 95 percent top set', () {
    const resolver = TrainingMaxResolver();

    final resolved = resolver.resolve(
      const OnePlusSetInput(Weight(9500, WeightUnit.kg)),
      const Percentage(5000),
    );

    expect(resolved.centiUnits, 10000);
    expect(resolved.unit, WeightUnit.kg);
  });

  test('3/5/1 changes wave content while keeping displayed week numbers', () {
    final cycle = compiler.compile(
      _definition(weekCount: 3),
      _request(
        const MainWorkExecutionOptions(
          weekOrder: WorkWeekOrder.threeFiveOne,
          plusSet: PlusSetMode.enabled,
        ),
      ),
    );

    expect(cycle.weeks.map((week) => week.number), [1, 2, 3]);
    expect(
      cycle.weeks
          .map(
            (week) => week
                .sessions
                .single
                .blocks
                .first
                .sets
                .first
                .percentageBasisPoints,
          )
          .toList(),
      [7000, 6500, 7500],
    );
    expect(
      cycle.weeks
          .map(
            (week) =>
                week.sessions.single.blocks.first.sets.last.repetitions['type'],
          )
          .toList(),
      ['plus_set', 'plus_set', 'plus_set'],
      reason: 'The source calculator keeps the plus set on every work wave.',
    );
  });

  test('5/3/1 normalizes a catalog declared in native 3/5/1 order', () {
    final cycle = compiler.compile(
      _definition(
        weekCount: 3,
        sourceWaveOrder: const [
          MainWorkWaveRole.three,
          MainWorkWaveRole.five,
          MainWorkWaveRole.fiveThreeOne,
        ],
      ),
      _request(
        const MainWorkExecutionOptions(weekOrder: WorkWeekOrder.fiveThreeOne),
      ),
    );

    expect(
      cycle.weeks
          .map(
            (week) => week
                .sessions
                .single
                .blocks
                .first
                .sets
                .first
                .percentageBasisPoints,
          )
          .toList(),
      [6500, 7000, 7500],
    );
  });

  test('bastard order reverses main sets but not the FSL semantic target', () {
    final cycle = compiler.compile(
      _definition(weekCount: 1, includeRelativeSupplemental: true),
      _request(const MainWorkExecutionOptions(setOrder: WorkSetOrder.bastard)),
    );
    final blocks = cycle.weeks.single.sessions.single.blocks;

    expect(blocks.first.sets.map((set) => set.percentageBasisPoints).toList(), [
      8500,
      7500,
      6500,
    ]);
    expect(blocks.first.sets.first.repetitions['type'], 'amrap');
    expect(
      blocks.last.sets.single.percentageBasisPoints,
      6500,
      reason: 'First Set Last still targets the catalog first work set.',
    );
  });

  test('plus-set mode preserves catalog eligibility', () {
    final disabled = compiler.compile(
      _definition(weekCount: 1),
      _request(const MainWorkExecutionOptions(plusSet: PlusSetMode.disabled)),
    );
    final enabled = compiler.compile(
      _definition(weekCount: 1),
      _request(const MainWorkExecutionOptions(plusSet: PlusSetMode.enabled)),
    );
    final ineligible = compiler.compile(
      _definition(weekCount: 1, fixedTopSet: true),
      _request(const MainWorkExecutionOptions(plusSet: PlusSetMode.enabled)),
    );

    expect(
      disabled.weeks.single.sessions.single.blocks.first.sets.last.repetitions,
      {'type': 'fixed', 'count': 5},
    );
    expect(
      enabled.weeks.single.sessions.single.blocks.first.sets.last.repetitions,
      {'type': 'plus_set', 'minimum': 5},
    );
    expect(
      ineligible
          .weeks
          .single
          .sessions
          .single
          .blocks
          .first
          .sets
          .last
          .repetitions,
      {'type': 'fixed', 'count': 5},
      reason: '5s Pro and other fixed prescriptions must stay non-AMRAP.',
    );
  });

  test(
    'heavy singles stay after Bastard work sets and never become relative targets',
    () {
      final cycle = compiler.compile(
        _definition(
          weekCount: 1,
          includeRelativeSupplemental: true,
          includeHeavySingle: true,
          includeJoker: true,
        ),
        _request(
          const MainWorkExecutionOptions(
            setOrder: WorkSetOrder.bastard,
            plusSet: PlusSetMode.enabled,
          ),
        ),
      );
      final blocks = cycle.weeks.single.sessions.single.blocks;
      final main = blocks.singleWhere((block) => block.role == 'main_work');
      final fsl = blocks.singleWhere((block) => block.role == 'supplemental');
      final joker = blocks.singleWhere((block) => block.role == 'joker');

      expect(main.sets.map((set) => set.percentageBasisPoints).toList(), [
        8500,
        7500,
        6500,
        10000,
      ]);
      expect(main.sets.first.repetitions, {'type': 'plus_set', 'minimum': 5});
      expect(main.sets.last.repetitions, {'type': 'fixed', 'count': 1});
      expect(
        fsl.sets.single.percentageBasisPoints,
        6500,
        reason: 'FSL follows the semantic first set.',
      );
      expect(
        joker.sets.single.percentageBasisPoints,
        9000,
        reason:
            'Joker loading follows the semantic top set, not a heavy single.',
      );
    },
  );
}

ResolvedCycleDefinition _definition({
  required int weekCount,
  bool fixedTopSet = false,
  bool includeRelativeSupplemental = false,
  bool includeHeavySingle = false,
  bool includeJoker = false,
  List<MainWorkWaveRole> sourceWaveOrder = const [
    MainWorkWaveRole.five,
    MainWorkWaveRole.three,
    MainWorkWaveRole.fiveThreeOne,
  ],
}) => ResolvedCycleDefinition(
  catalogVersion: 2,
  templateId: 'main-work',
  variantId: 'test',
  sessionMovementIds: const [_press],
  sourceReference: 'test',
  weeks: [
    for (var week = 1; week <= weekCount; week++)
      WeekDefinition(
        number: week,
        origin: CatalogWeekOrigin(
          phaseId: 'cycle',
          phaseIteration: 1,
          sourceWeekNumber: week,
        ),
        sessions: [
          SessionDefinition(
            id: _press,
            role: 'mainLift',
            blocks: [
              BlockDefinition(
                id: 'main-$week',
                role: 'main_work',
                movementId: _press,
                mainWorkSemantics: MainWorkSemantics(
                  waveRole: sourceWaveOrder[week - 1],
                  lastSetPolicy: fixedTopSet
                      ? MainWorkLastSetPolicy.fixed
                      : MainWorkLastSetPolicy.amrapPermitted,
                  setRoles: [
                    MainWorkSetRole.first,
                    MainWorkSetRole.second,
                    MainWorkSetRole.top,
                    if (includeHeavySingle) MainWorkSetRole.heavySingle,
                  ],
                ),
                sets: [
                  for (var index = 0; index < 3; index++)
                    PrescribedSetDefinition(
                      repetitions: index == 2 && !fixedTopSet
                          ? const AmrapRepetitions(minimum: 5)
                          : const FixedRepetitions(5),
                      load: TrainingMaxPercentageLoad(
                        Percentage(
                          _wavePercentages(sourceWaveOrder[week - 1])[index],
                        ),
                      ),
                    ),
                  if (includeHeavySingle)
                    const PrescribedSetDefinition(
                      repetitions: FixedRepetitions(1),
                      load: TrainingMaxPercentageLoad(Percentage(10000)),
                    ),
                ],
              ),
              if (includeRelativeSupplemental)
                const BlockDefinition(
                  id: 'fsl',
                  role: 'supplemental',
                  movementId: _press,
                  sets: [
                    PrescribedSetDefinition(
                      repetitions: FixedRepetitions(5),
                      load: RelativeSetLoad(
                        position: RelativeSetPosition.first,
                      ),
                    ),
                  ],
                ),
              if (includeJoker)
                const BlockDefinition(
                  id: 'joker',
                  role: 'joker',
                  movementId: _press,
                  sets: [
                    PrescribedSetDefinition(
                      repetitions: FixedRepetitions(1),
                      load: MainWorkSetPlusLoad(500),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
  ],
);

List<int> _wavePercentages(MainWorkWaveRole role) => switch (role) {
  MainWorkWaveRole.five => const [6500, 7500, 8500],
  MainWorkWaveRole.three => const [7000, 8000, 9000],
  MainWorkWaveRole.fiveThreeOne => const [7500, 8500, 9500],
  MainWorkWaveRole.deload => const [4000, 5000, 6000],
  MainWorkWaveRole.test => const [7000, 8000, 9000],
};

CycleRequest _request(MainWorkExecutionOptions mainWork) => CycleRequest(
  cycleId: 'main-work',
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
  cycleOptions: CycleExecutionOptions(mainWork: mainWork),
);
