import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  group('cycle option normalization', () {
    test('removes inactive and inapplicable values', () {
      const options = CycleExecutionOptions(
        warmUp: WarmUpExecutionOptions(
          enabled: false,
          type: WarmUpType.beyond,
          upperBodyBaseWeight: Weight(1000, WeightUnit.kg),
          lowerBodyBaseWeight: Weight(2000, WeightUnit.kg),
        ),
        joker: JokerExecutionOptions(enabled: false, ceilingBasisPoints: 3000),
        deload: DeloadExecutionOptions(
          enabled: true,
          type: DeloadType.highIntensity,
          skipWarmUp: true,
        ),
      );

      final normalized = options.normalized();
      expect(normalized.warmUp.type, isNull);
      expect(normalized.warmUp.upperBodyBaseWeight, isNull);
      expect(normalized.joker.ceilingBasisPoints, isNull);
      expect(normalized.deload.skipWarmUp, isFalse);
    });
  });

  group('catalog-driven warm-up', () {
    for (final unit in WeightUnit.values) {
      test('Beyond consumes upper/lower bases in ${unit.name}', () {
        final upper = Weight(unit == WeightUnit.kg ? 2000 : 4500, unit);
        final lower = Weight(unit == WeightUnit.kg ? 3000 : 6500, unit);
        final cycle = _compile(
          unit: unit,
          definition: _definition(
            warmUp: {
              WarmUpType.beyond: _recipe(unit, [
                _block(
                  'upper',
                  'warm_up',
                  const WarmUpBaseLoad(WarmUpBodyRegion.upperBody),
                ),
                _block(
                  'lower',
                  'warm_up',
                  const WarmUpBaseLoad(WarmUpBodyRegion.lowerBody),
                ),
              ]),
            },
          ),
          options: CycleExecutionOptions(
            warmUp: WarmUpExecutionOptions(
              enabled: true,
              type: WarmUpType.beyond,
              upperBodyBaseWeight: upper,
              lowerBodyBaseWeight: lower,
            ),
          ),
        );

        final loads = cycle.weeks.single.sessions.single.blocks
            .where((block) => block.role == 'warm_up')
            .map((block) => block.sets.single.plannedLoad!.centiUnits);
        expect(loads, [upper.centiUnits, lower.centiUnits]);
      });
    }

    test('Original is selected solely from its resolved recipe', () {
      final cycle = _compile(
        definition: _definition(
          warmUp: {
            WarmUpType.original: _recipe(WeightUnit.kg, [
              _block('original', 'warm_up', const Unloaded(), repetitions: 7),
            ]),
          },
        ),
        options: const CycleExecutionOptions(
          warmUp: WarmUpExecutionOptions(
            enabled: true,
            type: WarmUpType.original,
          ),
        ),
      );
      expect(cycle.weeks.single.sessions.single.blocks.first.id, 'original');
      expect(
        cycle
            .weeks
            .single
            .sessions
            .single
            .blocks
            .first
            .sets
            .single
            .repetitions['count'],
        7,
      );
    });

    test('Beyond rejects absent, non-positive, and mixed-unit bases', () {
      final definition = _definition(
        warmUp: {WarmUpType.beyond: _recipe(WeightUnit.kg, const [])},
      );
      for (final bases in [
        const [null, Weight(1000, WeightUnit.kg)],
        const [Weight(0, WeightUnit.kg), Weight(1000, WeightUnit.kg)],
        const [Weight(1000, WeightUnit.lb), Weight(1000, WeightUnit.kg)],
      ]) {
        expect(
          () => _compile(
            definition: definition,
            options: CycleExecutionOptions(
              warmUp: WarmUpExecutionOptions(
                enabled: true,
                type: WarmUpType.beyond,
                upperBodyBaseWeight: bases[0],
                lowerBodyBaseWeight: bases[1],
              ),
            ),
          ),
          throwsA(isA<CycleGenerationException>()),
        );
      }
    });
  });

  group('catalog-driven Joker Sets', () {
    for (var ceiling = 500; ceiling <= 3000; ceiling += 500) {
      test(
        '${ceiling ~/ 100}% ceiling emits ${ceiling ~/ 500} declared steps',
        () {
          final cycle = _compile(
            definition: _definition(joker: _jokerRecipe()),
            options: CycleExecutionOptions(
              joker: JokerExecutionOptions(
                enabled: true,
                ceilingBasisPoints: ceiling,
              ),
            ),
          );
          final joker = cycle.weeks.single.sessions.single.blocks.singleWhere(
            (block) => block.role == 'joker',
          );
          expect(joker.sets, hasLength(ceiling ~/ 500));
          expect(joker.sets.map((set) => set.percentageBasisPoints), [
            for (var value = 9000; value <= 8500 + ceiling; value += 500) value,
          ]);
          expect(joker.sets.map((set) => set.repetitions['count']), [
            for (var rank = 1; rank <= ceiling ~/ 500; rank++) rank,
          ]);
        },
      );
    }

    test('rejects ceilings outside 5..30 or outside 5-point increments', () {
      for (final ceiling in [0, 499, 501, 3500]) {
        expect(
          () => _compile(
            definition: _definition(joker: _jokerRecipe()),
            options: CycleExecutionOptions(
              joker: JokerExecutionOptions(
                enabled: true,
                ceilingBasisPoints: ceiling,
              ),
            ),
          ),
          throwsA(isA<CycleGenerationException>()),
        );
      }
    });
  });

  group('catalog-driven deload', () {
    for (final type in DeloadType.values) {
      test('${type.name} applies its resolved prescription', () {
        final prescription = _deloadPrescription(type);
        final cycle = _compile(
          definition: _definition(
            deloadBase: true,
            deload: {
              type: _recipe(WeightUnit.kg, [
                BlockDefinition(
                  id: 'selected-${type.name}',
                  role: 'deload',
                  sets: [
                    for (final item in prescription)
                      PrescribedSetDefinition(
                        repetitions: FixedRepetitions(item.$2),
                        load: TrainingMaxPercentageLoad(Percentage(item.$1)),
                      ),
                  ],
                ),
              ]),
            },
          ),
          options: CycleExecutionOptions(
            deload: DeloadExecutionOptions(enabled: true, type: type),
          ),
        );
        final block = cycle.weeks.single.sessions.single.blocks.single;
        expect(block.id, 'selected-${type.name}');
        expect(
          block.sets.map((set) => set.percentageBasisPoints),
          prescription.map((item) => item.$1),
        );
        expect(
          block.sets.map((set) => set.repetitions['count']),
          prescription.map((item) => item.$2),
        );
      });
    }

    test('skipWarmUp applies to types 1..5, never highIntensity', () {
      for (final type in DeloadType.values) {
        final cycle = _compile(
          definition: _definition(
            deloadBase: true,
            warmUp: {
              WarmUpType.original: _recipe(WeightUnit.kg, [
                _block('warm', 'warm_up', const Unloaded()),
              ]),
            },
            deload: {
              type: _recipe(WeightUnit.kg, [
                _block('deload', 'deload', const Unloaded()),
              ]),
            },
          ),
          options: CycleExecutionOptions(
            warmUp: const WarmUpExecutionOptions(
              enabled: true,
              type: WarmUpType.original,
            ),
            deload: DeloadExecutionOptions(
              enabled: true,
              type: type,
              skipWarmUp: true,
            ),
          ),
        );
        final roles = cycle.weeks.single.sessions.single.blocks.map(
          (block) => block.role,
        );
        expect(roles.contains('warm_up'), type == DeloadType.highIntensity);
      }
    });

    test('does not emit empty weeks or sessions', () {
      final cycle = _compile(
        definition: _definition(
          deloadBase: true,
          deload: {DeloadType.type1: _recipe(WeightUnit.kg, const [])},
        ),
        options: const CycleExecutionOptions(
          deload: DeloadExecutionOptions(enabled: false),
        ),
      );
      expect(cycle.weeks, isEmpty);
    });
  });
}

List<(int, int)> _deloadPrescription(DeloadType type) => switch (type) {
  DeloadType.type1 => const [(4000, 5), (5000, 5), (6000, 5)],
  DeloadType.type2 => const [(5000, 5), (6000, 5), (7000, 5)],
  DeloadType.type3 => const [(6500, 3), (7600, 3), (8500, 3)],
  DeloadType.type4 => const [(4000, 10), (5000, 8), (6000, 6)],
  DeloadType.type5 => const [(5000, 10), (6000, 8), (7000, 6)],
  DeloadType.highIntensity => const [(9000, 1)],
};

const _movement = MovementId('movement');

ResolvedCycleDefinition _definition({
  Map<WarmUpType, ResolvedBlockRecipe> warmUp = const {},
  ResolvedJokerRecipe? joker,
  Map<DeloadType, ResolvedBlockRecipe> deload = const {},
  bool deloadBase = false,
}) => ResolvedCycleDefinition(
  catalogVersion: 1,
  templateId: 'template',
  variantId: 'variant',
  sessionMovementIds: const [_movement],
  sourceReference: 'test',
  weeks: [
    WeekDefinition(
      number: 1,
      blocks: [
        if (deloadBase)
          _block('base-deload', 'deload', const Unloaded())
        else
          _block(
            'main',
            'main_work',
            const TrainingMaxPercentageLoad(Percentage(8500)),
          ),
      ],
    ),
  ],
  optionRecipes: ResolvedCycleOptionRecipes(
    warmUp: warmUp,
    joker: joker,
    deload: deload,
  ),
);

ResolvedBlockRecipe _recipe(WeightUnit unit, List<BlockDefinition> blocks) =>
    ResolvedBlockRecipe(
      byUnit: {
        unit: [
          ResolvedBlockOverlay(
            weekNumber: 1,
            sessionId: _movement,
            blocks: blocks,
          ),
        ],
      },
    );

ResolvedJokerRecipe _jokerRecipe() => ResolvedJokerRecipe(
  blockId: 'joker',
  steps: [
    for (var rank = 1; rank <= 6; rank++)
      JokerRecipeStep(
        cumulativeIncreaseBasisPoints: rank * 500,
        repetitions: FixedRepetitions(rank),
      ),
  ],
);

BlockDefinition _block(
  String id,
  String role,
  LoadPrescription load, {
  int repetitions = 5,
}) => BlockDefinition(
  id: id,
  role: role,
  sets: [
    PrescribedSetDefinition(
      repetitions: FixedRepetitions(repetitions),
      load: load,
    ),
  ],
);

GeneratedCycle _compile({
  ResolvedCycleDefinition? definition,
  WeightUnit unit = WeightUnit.kg,
  CycleExecutionOptions options = const CycleExecutionOptions(),
}) => const CycleCompilerImpl().compile(
  definition ?? _definition(),
  CycleRequest(
    cycleId: 'cycle',
    startDate: DateTime(2026, 1, 5),
    trainingDays: const [1],
    sessionOrder: const [_movement],
    maxInputs: {_movement: DirectTrainingMaxInput(Weight(10000, unit))},
    globalTrainingMaxRatio: const Percentage(10000),
    unit: unit,
    roundingIncrement: Weight(100, unit),
    barProfile: BarProfile(
      weight: Weight(0, unit),
      platesPerSide: [
        for (final value in const [50, 100, 200, 400, 800, 1600, 3200])
          Weight(value, unit),
      ],
    ),
    cycleOptions: options,
  ),
);
