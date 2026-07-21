import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_calculations.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_compiler_impl.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_generation_error.dart';

void main() {
  const squat = MovementId('squat');
  const press = MovementId('press');

  ResolvedCycleDefinition definition({
    List<MovementId> movements = const [squat, press],
  }) => ResolvedCycleDefinition(
    catalogVersion: 3,
    templateId: 'standard',
    variantId: 'four-day',
    sessionMovementIds: movements,
    sourceReference: 'fixture',
    weeks: const [
      WeekDefinition(
        number: 1,
        blocks: [
          BlockDefinition(
            id: 'warmup',
            role: 'warm-up',
            sets: [
              PrescribedSetDefinition(
                repetitions: FixedRepetitions(5),
                load: TrainingMaxPercentageLoad(Percentage(4000)),
              ),
            ],
          ),
          BlockDefinition(
            id: 'main',
            role: 'main work',
            sets: [
              PrescribedSetDefinition(
                repetitions: AmrapRepetitions(minimum: 5),
                load: TrainingMaxPercentageLoad(Percentage(8500)),
              ),
            ],
          ),
          BlockDefinition(
            id: 'deload',
            role: 'deload',
            sets: [
              PrescribedSetDefinition(
                repetitions: FixedRepetitions(5),
                load: TrainingMaxPercentageLoad(Percentage(5000)),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  CycleRequest request({
    List<int> days = const [1, 4],
    List<MovementId> order = const [squat, press],
    Map<MovementId, TrainingMaxInput>? inputs,
    Percentage ratio = const Percentage(9000),
    Map<MovementId, Percentage> ratios = const {},
    BarProfile? equipment,
    bool includeDeload = true,
  }) => CycleRequest(
    cycleId: 'cycle-1',
    startDate: DateTime(2026, 7, 21),
    trainingDays: days,
    sessionOrder: order,
    maxInputs:
        inputs ??
        const {
          squat: OneRepMaxInput(Weight(10000, WeightUnit.kg)),
          press: RepMaxInput(Weight(5000, WeightUnit.kg), 6),
        },
    globalTrainingMaxRatio: ratio,
    trainingMaxRatioByMovement: ratios,
    unit: WeightUnit.kg,
    roundingIncrement: const Weight(250, WeightUnit.kg),
    barProfile:
        equipment ??
        const BarProfile(
          weight: Weight(2000, WeightUnit.kg),
          platesPerSide: [
            Weight(2000, WeightUnit.kg),
            Weight(1000, WeightUnit.kg),
            Weight(500, WeightUnit.kg),
            Weight(250, WeightUnit.kg),
            Weight(125, WeightUnit.kg),
          ],
        ),
    includeDeload: includeDeload,
  );

  test('Epley is named and uses deterministic centi-unit rounding', () {
    const formula = EpleyRepMaxFormula();
    expect(
      formula.estimate(const Weight(5000, WeightUnit.kg), 6).centiUnits,
      6000,
    );
  });

  test('resolves global and per-movement TM ratios', () {
    final result = const CycleCompilerImpl().compile(
      definition(),
      request(ratios: const {press: Percentage(8000)}),
    );
    expect(result.effectiveTrainingMaxes['squat']!.centiUnits, 9000);
    expect(result.effectiveTrainingMaxes['press']!.centiUnits, 4800);
  });

  test('compiles generic blocks, plating and real calendar dates', () {
    final result = const CycleCompilerImpl().compile(definition(), request());
    final squatSession = result.weeks.single.sessions.first;
    final pressSession = result.weeks.single.sessions.last;

    expect(squatSession.date, DateTime(2026, 7, 27));
    expect(pressSession.date, DateTime(2026, 7, 30));
    expect(squatSession.blocks.map((block) => block.role), [
      'warm-up',
      'main work',
      'deload',
    ]);
    expect(squatSession.blocks[1].sets.single.plannedLoad!.centiUnits, 7750);
    expect(
      squatSession.blocks[1].sets.single.platesPerSide.map(
        (plate) => plate.centiUnits,
      ),
      [2000, 500, 250, 125],
    );
  });

  test('can omit deload blocks without template-specific branching', () {
    final result = const CycleCompilerImpl().compile(
      definition(),
      request(includeDeload: false),
    );
    expect(
      result.weeks.single.sessions.first.blocks.map((block) => block.role),
      ['warm-up', 'main work'],
    );
  });

  test('warns when exact load is unavailable', () {
    final result = const CycleCompilerImpl().compile(
      definition(movements: const [squat]),
      request(
        order: const [squat],
        days: const [2],
        inputs: const {
          squat: DirectTrainingMaxInput(Weight(9000, WeightUnit.kg)),
        },
        equipment: const BarProfile(
          weight: Weight(2000, WeightUnit.kg),
          platesPerSide: [Weight(2000, WeightUnit.kg)],
        ),
      ),
    );
    expect(
      result.weeks.single.sessions.single.blocks[1].sets.single.warning!.code,
      GenerationWarningCode.insufficientEquipment,
    );
  });

  test('rejects missing maximum', () {
    expect(
      () => const CycleCompilerImpl().compile(
        definition(),
        request(
          inputs: const {squat: OneRepMaxInput(Weight(10000, WeightUnit.kg))},
        ),
      ),
      throwsCode(CycleGenerationErrorCode.missingMaximum),
    );
  });

  test('rejects invalid ratio', () {
    expect(
      () => const CycleCompilerImpl().compile(
        definition(),
        request(ratio: const Percentage(0)),
      ),
      throwsCode(CycleGenerationErrorCode.invalidTrainingMaxRatio),
    );
  });

  test('rejects duplicate weekdays', () {
    expect(
      () => const CycleCompilerImpl().compile(
        definition(),
        request(days: const [1, 1]),
      ),
      throwsCode(CycleGenerationErrorCode.duplicateTrainingDays),
    );
  });

  test('rejects unsupported movement', () {
    const row = MovementId('row');
    expect(
      () => const CycleCompilerImpl().compile(
        definition(),
        request(
          order: const [squat, row],
          inputs: const {
            squat: OneRepMaxInput(Weight(10000, WeightUnit.kg)),
            row: OneRepMaxInput(Weight(8000, WeightUnit.kg)),
          },
        ),
      ),
      throwsCode(CycleGenerationErrorCode.unsupportedMovement),
    );
  });

  test('rejects a session order that truncates the definition', () {
    expect(
      () => const CycleCompilerImpl().compile(
        definition(),
        request(order: const [squat], days: const [1]),
      ),
      throwsCode(CycleGenerationErrorCode.unsupportedMovement),
    );
  });

  test('rejects invalid equipment units', () {
    expect(
      () => const CycleCompilerImpl().compile(
        definition(),
        request(
          equipment: const BarProfile(
            weight: Weight(4500, WeightUnit.lb),
            platesPerSide: [Weight(2000, WeightUnit.kg)],
          ),
        ),
      ),
      throwsCode(CycleGenerationErrorCode.invalidEquipment),
    );
  });

  test('resolves a bounded generic percentage parameter per movement', () {
    const parameterized = ResolvedCycleDefinition(
      catalogVersion: 3,
      templateId: 'parameter-fixture',
      variantId: 'one-session',
      sessionMovementIds: [squat],
      sourceReference: 'fixture',
      weeks: [
        WeekDefinition(
          number: 1,
          blocks: [
            BlockDefinition(
              id: 'supplemental',
              role: 'supplemental',
              sets: [
                PrescribedSetDefinition(
                  repetitions: FixedRepetitions(10),
                  load: ParameterizedTrainingMaxPercentageLoad(
                    parameterId: 'supplementalPercentage',
                    defaultValue: Percentage(5000),
                    minimum: Percentage(4000),
                    maximum: Percentage(6000),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final result = const CycleCompilerImpl().compile(
      parameterized,
      request(
        order: const [squat],
        days: const [2],
        inputs: const {
          squat: DirectTrainingMaxInput(Weight(10000, WeightUnit.kg)),
        },
      ).copyWithPercentageParameter(
        movement: squat,
        parameterId: 'supplementalPercentage',
        value: const Percentage(6000),
      ),
    );
    expect(
      result
          .weeks
          .single
          .sessions
          .single
          .blocks
          .single
          .sets
          .single
          .percentageBasisPoints,
      6000,
    );
  });
}

extension on CycleRequest {
  CycleRequest copyWithPercentageParameter({
    required MovementId movement,
    required String parameterId,
    required Percentage value,
  }) => CycleRequest(
    cycleId: cycleId,
    startDate: startDate,
    trainingDays: trainingDays,
    sessionOrder: sessionOrder,
    maxInputs: maxInputs,
    globalTrainingMaxRatio: globalTrainingMaxRatio,
    trainingMaxRatioByMovement: trainingMaxRatioByMovement,
    percentageParametersByMovement: {
      movement: {parameterId: value},
    },
    unit: unit,
    roundingIncrement: roundingIncrement,
    barProfile: barProfile,
    includeDeload: includeDeload,
  );
}

Matcher throwsCode(CycleGenerationErrorCode code) => throwsA(
  isA<CycleGenerationException>().having((error) => error.code, 'code', code),
);
