import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/domain/calculator/calculator.dart';

CalculatorConfiguration configuration({
  MainWorkOrder order = MainWorkOrder.fiveThreeOne,
  DeloadOption deload = DeloadOption.deload1,
  CalculatorTemplateId template = CalculatorTemplateId.standard,
  String variant = 'standard',
  int days = 4,
  CalculatorOptions? options,
}) => CalculatorConfiguration(
  template: template,
  variantId: variant,
  trainingMaxes: const {
    'press': 50,
    'deadlift': 150,
    'bench': 100,
    'squat': 125,
  },
  daysPerWeek: days,
  options: options ?? CalculatorOptions(order: order, deload: deload),
);

void main() {
  const engine = ClassicCalculatorEngine();
  test(
    'catalog exposes all requested classic families and eight BBB variants',
    () {
      expect(
        calculatorTemplates.where(
          (item) => item.id != CalculatorTemplateId.standard,
        ),
        hasLength(13),
      );
      expect(
        calculatorTemplates.map((item) => item.id),
        contains(CalculatorTemplateId.standard),
      );
      expect(
        calculatorTemplate(CalculatorTemplateId.boringButBig).variants,
        hasLength(8),
      );
      expect(
        calculatorTemplate(
          CalculatorTemplateId.firstSetLast,
        ).variants.map((v) => v.id),
        containsAll(['amrap', 'multiple-sets']),
      );
      expect(
        calculatorTemplates
            .expand((t) => t.variants)
            .every((v) => v.sources.isNotEmpty),
        isTrue,
      );
    },
  );

  test('generates verified 5/3/1 main work and standard deload', () {
    final program = engine.generate(configuration());
    expect(program.weeks, hasLength(4));
    expect(program.weeks.first.sessions.first.sets.map((s) => s.percent), [
      65,
      75,
      85,
    ]);
    expect(program.weeks.first.sessions.first.sets.map((s) => s.weight), [
      32.5,
      37.5,
      42.5,
    ]);
    expect(program.weeks.last.sessions.first.sets.map((s) => s.percent), [
      40,
      50,
      60,
    ]);
    expect(program.weeks.last.sessions.first.sets.any((s) => s.amrap), isFalse);
  });

  test('3/5/1 reorders weeks and suppresses AMRAP on the 5s week', () {
    final program = engine.generate(
      configuration(order: MainWorkOrder.threeFiveOne),
    );
    expect(program.weeks.first.sessions.first.sets.map((s) => s.percent), [
      70,
      80,
      90,
    ]);
    expect(program.weeks[1].sessions.first.sets.map((s) => s.percent), [
      65,
      75,
      85,
    ]);
    expect(program.weeks[1].sessions.first.sets.any((s) => s.amrap), isFalse);
  });

  test('generation is deterministic and configuration round-trips', () {
    final input = configuration(deload: DeloadOption.none);
    expect(engine.generate(input).toJson(), engine.generate(input).toJson());
    final restored = engine.deserializeConfiguration(
      engine.serializeConfiguration(input),
    );
    expect(restored.toJson(), input.toJson());
  });

  test('generates audited BBB original supplemental work', () {
    final input = configuration(
      template: CalculatorTemplateId.boringButBig,
      variant: 'original-5x10',
    );
    final sets = engine.generate(input).weeks.first.sessions.first.sets;
    expect(sets.where((set) => set.kind == 'supplemental'), hasLength(5));
    expect(sets.last.repetitions, 10);
  });

  test('Pyramid, FSL and 5s Progression alter the generated prescription', () {
    final pyramid = engine
        .generate(
          configuration(
            template: CalculatorTemplateId.pyramid,
            variant: 'pyramid',
          ),
        )
        .weeks
        .first
        .sessions
        .first
        .sets;
    expect(pyramid.map((set) => set.percent), [65, 75, 85, 75, 65]);
    final fsl = engine
        .generate(
          configuration(
            template: CalculatorTemplateId.firstSetLast,
            variant: 'amrap',
          ),
        )
        .weeks
        .first
        .sessions
        .first
        .sets;
    expect(fsl.last.kind, 'supplemental');
    expect(fsl.last.amrap, isTrue);
    final fives = engine
        .generate(
          configuration(
            template: CalculatorTemplateId.fivesProgression,
            variant: 'fives-progression',
          ),
        )
        .weeks[1]
        .sessions
        .first
        .sets;
    expect(fives.map((set) => set.repetitions), [5, 5, 5]);
    expect(fives.any((set) => set.amrap), isFalse);
  });

  test('BBB two-day variant enforces its schedule', () {
    final invalid = configuration(
      template: CalculatorTemplateId.boringButBig,
      variant: 'two-days',
      days: 4,
    );
    expect(
      engine.validate(invalid).map((issue) => issue.code),
      contains('unsupported_schedule'),
    );
  });

  test('joker increments and explicit UI cap are validated', () {
    final options = CalculatorOptions(
      jokersEnabled: true,
      jokerIncrementPercent: 15,
      jokerCapPercent: 35,
      deload: DeloadOption.none,
    );
    final issues = engine.validate(configuration(options: options));
    expect(
      issues.map((issue) => issue.code),
      containsAll([
        'unsupported_joker_increment',
        'invalid_joker_cap',
        'joker_runtime_decision',
      ]),
    );
  });

  test('Beyond warmup and high-intensity deload are generated from bases', () {
    const options = CalculatorOptions(
      warmup: WarmupOption.beyond,
      deload: DeloadOption.highIntensity,
    );
    final program = engine.generate(configuration(options: options));
    expect(program.weeks.first.sessions.first.sets.first.kind, 'warmup');
    expect(program.weeks.last.sessions.first.sets.last.repetitions, 1);
    expect(program.weeks.last.sessions.first.sets.last.percent, 100);
  });

  test('deload options two through five have distinct prescriptions', () {
    final d2 = engine
        .generate(
          configuration(
            options: const CalculatorOptions(deload: DeloadOption.deload2),
          ),
        )
        .weeks
        .last
        .sessions
        .first
        .sets;
    final d5 = engine
        .generate(
          configuration(
            options: const CalculatorOptions(deload: DeloadOption.deload5),
          ),
        )
        .weeks
        .last
        .sessions
        .first
        .sets;
    expect(d2.map((set) => set.percent), [50, 60, 70]);
    expect(d2.map((set) => set.repetitions), [5, 5, 5]);
    expect(d5.map((set) => set.repetitions), [10, 8, 6]);
  });

  test('Simplest Strength uses its reviewed weekly supplemental waves', () {
    final program = engine.generate(
      configuration(
        template: CalculatorTemplateId.simplestStrength,
        variant: 'original',
      ),
    );
    final supplemental = program.weeks.first.sessions.first.sets.where(
      (set) => set.kind == 'supplemental',
    );
    expect(supplemental.map((set) => set.percent), [50, 60, 70]);
    expect(supplemental.map((set) => set.repetitions), [10, 10, 10]);
  });

  test('Triumvirate and Periodization Bible generate sourced assistance', () {
    final triumvirate = engine.generate(
      configuration(
        template: CalculatorTemplateId.triumvirate,
        variant: 'original',
      ),
    );
    final triAssistance = triumvirate.weeks.first.sessions.first.sets.where(
      (set) => set.kind == 'assistance',
    );
    expect(triAssistance.where((set) => set.exercise == 'Dips'), hasLength(5));
    expect(
      triAssistance.where((set) => set.exercise == 'Pull-up'),
      hasLength(5),
    );
    final periodization = engine.generate(
      configuration(
        template: CalculatorTemplateId.periodizationBible,
        variant: 'original',
      ),
    );
    expect(
      periodization.weeks.first.sessions.first.sets.where(
        (set) => set.kind == 'assistance',
      ),
      hasLength(15),
    );
  });

  test('Bodyweight distributes the target across the selected set count', () {
    final input = CalculatorConfiguration(
      template: CalculatorTemplateId.bodyweight,
      variantId: 'original',
      trainingMaxes: const {
        'press': 50,
        'deadlift': 150,
        'bench': 100,
        'squat': 125,
      },
      daysPerWeek: 4,
      bodyweightTotalReps: 77,
      bodyweightSetCount: 5,
    );
    final assistance = engine
        .generate(input)
        .weeks
        .first
        .sessions
        .first
        .sets
        .where((set) => set.exercise == 'Pull-up');
    expect(
      assistance.map((set) => set.repetitions).reduce((a, b) => a + b),
      77,
    );
    expect(assistance, hasLength(5));
  });

  test(
    'three-day schedules rotate the four lifts without adding a fourth session',
    () {
      final program = engine.generate(configuration(days: 3));
      expect(program.weeks.every((week) => week.sessions.length == 3), isTrue);
      expect(program.weeks.first.sessions.map((session) => session.lift), [
        'press',
        'deadlift',
        'bench',
      ]);
      expect(program.weeks[1].sessions.map((session) => session.lift), [
        'squat',
        'press',
        'deadlift',
      ]);
    },
  );

  test('joker policy generates optional 5 percent targets up to the cap', () {
    final program = engine.generate(
      configuration(
        options: const CalculatorOptions(
          jokersEnabled: true,
          jokerIncrementPercent: 5,
          jokerCapPercent: 20,
          deload: DeloadOption.none,
        ),
      ),
    );
    expect(program.warnings.single, contains('capped at +20%'));
    final jokers = program.weeks.first.sessions.first.sets.where(
      (set) => set.kind == 'joker',
    );
    expect(jokers.map((set) => set.percent), [90, 95, 100, 105]);
  });

  test('Less Boring uses the opposite lift Training Max', () {
    final sets = engine
        .generate(
          configuration(
            template: CalculatorTemplateId.boringButBig,
            variant: 'less-boring',
          ),
        )
        .weeks
        .first
        .sessions
        .first
        .sets;
    expect(sets.last.weight, 50); // Press day uses 50% of the 100 kg bench TM.
  });

  test('rejects arbitrary lift identifiers', () {
    final invalid = CalculatorConfiguration(
      template: CalculatorTemplateId.standard,
      variantId: 'standard',
      trainingMaxes: const {'curl': 10, 'row': 20, 'dip': 30, 'clean': 40},
      daysPerWeek: 4,
      liftOrder: const ['curl', 'row', 'dip', 'clean'],
    );
    expect(
      engine.validate(invalid).map((issue) => issue.code),
      contains('invalid_lifts'),
    );
  });

  test('kg and lb use distinct load increments', () {
    final input = CalculatorConfiguration(
      template: CalculatorTemplateId.standard,
      variantId: 'standard',
      trainingMaxes: const {
        'press': 51,
        'deadlift': 153,
        'bench': 103,
        'squat': 128,
      },
      daysPerWeek: 4,
    );
    final kg = const ClassicCalculatorEngine(
      roundingIncrement: 2.5,
    ).generate(input).weeks.first.sessions.first.sets.first.weight;
    final lb = const ClassicCalculatorEngine(
      roundingIncrement: 5,
    ).generate(input).weeks.first.sessions.first.sets.first.weight;
    expect(kg, 32.5);
    expect(lb, 35);
    final kgSecond = const ClassicCalculatorEngine(
      roundingIncrement: 2.5,
    ).generate(input).weeks.first.sessions.first.sets[1].weight;
    final lbSecond = const ClassicCalculatorEngine(
      roundingIncrement: 5,
    ).generate(input).weeks.first.sessions.first.sets[1].weight;
    expect(kgSecond, 37.5);
    expect(lbSecond, 40);
  });

  test('FSL Multiple Sets honors selected sets and repetitions', () {
    final input = CalculatorConfiguration(
      template: CalculatorTemplateId.firstSetLast,
      variantId: 'multiple-sets',
      trainingMaxes: const {
        'press': 50,
        'deadlift': 150,
        'bench': 100,
        'squat': 125,
      },
      daysPerWeek: 4,
      fslSetCount: 4,
      fslRepCount: 7,
    );
    final supplemental = engine
        .generate(input)
        .weeks
        .first
        .sessions
        .first
        .sets
        .where((set) => set.kind == 'supplemental');
    expect(supplemental, hasLength(4));
    expect(supplemental.every((set) => set.repetitions == 7), isTrue);
  });

  test('GVT generates sourced 10x10 work and lift-specific assistance', () {
    final input = CalculatorConfiguration(
      template: CalculatorTemplateId.germanVolumeTraining,
      variantId: '10x10',
      trainingMaxes: const {
        'press': 50,
        'deadlift': 150,
        'bench': 100,
        'squat': 125,
      },
      daysPerWeek: 4,
      gvtPercent: 40,
    );
    final sets = engine.generate(input).weeks.first.sessions.first.sets;
    expect(sets.where((set) => set.kind == 'supplemental'), hasLength(10));
    expect(sets.where((set) => set.exercise == 'Lat Pulldown'), hasLength(10));
  });
}
