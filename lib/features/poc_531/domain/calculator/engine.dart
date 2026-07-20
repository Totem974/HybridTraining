import 'dart:convert';

import 'catalog.dart';
import 'models.dart';

class ClassicCalculatorEngine {
  const ClassicCalculatorEngine({this.roundingIncrement = 2.5});
  final double roundingIncrement;

  List<CalculatorIssue> validate(CalculatorConfiguration configuration) {
    final issues = <CalculatorIssue>[];
    final template = calculatorTemplate(configuration.template);
    VariantDefinition? variant;
    for (final candidate in template.variants) {
      if (candidate.id == configuration.variantId) variant = candidate;
    }
    if (variant == null) {
      issues.add(
        const CalculatorIssue(
          'unknown_variant',
          'Variant is not part of the selected template.',
          field: 'variantId',
        ),
      );
    } else {
      if (!variant.allowedDays.contains(configuration.daysPerWeek)) {
        issues.add(
          const CalculatorIssue(
            'unsupported_schedule',
            'This variant does not support the selected days per week.',
            field: 'daysPerWeek',
          ),
        );
      }
      if (!variant.executable) {
        issues.add(
          CalculatorIssue(
            'needs_review',
            variant.blockedReason ?? 'This prescription is not verified.',
            field: 'variantId',
          ),
        );
      }
    }
    if (!template.allowedDays.contains(configuration.daysPerWeek)) {
      issues.add(
        const CalculatorIssue(
          'unsupported_schedule',
          'This template does not support the selected days per week.',
          field: 'daysPerWeek',
        ),
      );
    }
    if (configuration.trainingMaxes.length != 4 ||
        configuration.trainingMaxes.values.any(
          (value) => !value.isFinite || value <= 0,
        )) {
      issues.add(
        const CalculatorIssue(
          'invalid_training_maxes',
          'Four positive finite Training Max values are required.',
          field: 'trainingMaxes',
        ),
      );
    }
    const canonicalLifts = {'press', 'bench', 'squat', 'deadlift'};
    if (configuration.trainingMaxes.keys
            .toSet()
            .difference(canonicalLifts)
            .isNotEmpty ||
        canonicalLifts
            .difference(configuration.trainingMaxes.keys.toSet())
            .isNotEmpty) {
      issues.add(
        const CalculatorIssue(
          'invalid_lifts',
          'Training Maxes must contain exactly Press, Bench Press, Squat and Deadlift.',
          field: 'trainingMaxes',
        ),
      );
    }
    if (configuration.unit != 'kg' && configuration.unit != 'lb') {
      issues.add(
        const CalculatorIssue(
          'invalid_unit',
          'Unit must be kg or lb.',
          field: 'unit',
        ),
      );
    }
    if (configuration.supplementalPercent < 0 ||
        configuration.supplementalPercent > 100) {
      issues.add(
        const CalculatorIssue(
          'invalid_supplemental_percent',
          'Supplemental percentage must be between 0 and 100.',
          field: 'supplementalPercent',
        ),
      );
    }
    if (configuration.warmupBaseUpper < 0 ||
        configuration.warmupBaseLower < 0) {
      issues.add(
        const CalculatorIssue(
          'invalid_warmup_base',
          'Warm-up base weights cannot be negative.',
          field: 'warmupBase',
        ),
      );
    }
    if (configuration.template == CalculatorTemplateId.bodyweight &&
        (configuration.bodyweightTotalReps <= 0 ||
            configuration.bodyweightSetCount <= 0 ||
            configuration.bodyweightSetCount >
                configuration.bodyweightTotalReps)) {
      issues.add(
        const CalculatorIssue(
          'invalid_bodyweight_distribution',
          'Bodyweight requires a positive repetition target split across a valid number of sets.',
          field: 'bodyweight',
        ),
      );
    }
    if (configuration.template == CalculatorTemplateId.firstSetLast &&
        configuration.variantId == 'multiple-sets' &&
        (configuration.fslSetCount < 3 ||
            configuration.fslSetCount > 5 ||
            configuration.fslRepCount < 3 ||
            configuration.fslRepCount > 8)) {
      issues.add(
        const CalculatorIssue(
          'invalid_fsl_volume',
          'FSL Multiple Sets requires 3–5 sets of 3–8 repetitions.',
          field: 'fsl',
        ),
      );
    }
    if (configuration.template == CalculatorTemplateId.germanVolumeTraining &&
        [
          configuration.gvtPercent,
          ...configuration.gvtPercents.values,
        ].any((percent) => percent < 30 || percent > 75 || percent % 5 != 0)) {
      issues.add(
        const CalculatorIssue(
          'invalid_gvt_percent',
          'GVT requires an explicit 30–75% ratio in 5% steps.',
          field: 'gvtPercent',
        ),
      );
    }
    if (configuration.liftOrder.length != 4 ||
        configuration.liftOrder.toSet().length != 4 ||
        !configuration.trainingMaxes.keys.toSet().containsAll(
          configuration.liftOrder,
        )) {
      issues.add(
        const CalculatorIssue(
          'invalid_lift_order',
          'Lift order must contain each configured lift exactly once.',
          field: 'liftOrder',
        ),
      );
    }
    if (configuration.options.jokersEnabled) {
      if (configuration.options.jokerIncrementPercent != 5) {
        issues.add(
          const CalculatorIssue(
            'unsupported_joker_increment',
            'Joker targets use the source-defined 5% increments.',
            field: 'jokerIncrementPercent',
          ),
        );
      }
      if (configuration.options.jokerCapPercent <
              configuration.options.jokerIncrementPercent ||
          configuration.options.jokerCapPercent > 30 ||
          configuration.options.jokerCapPercent % 5 != 0) {
        issues.add(
          const CalculatorIssue(
            'invalid_joker_cap',
            'Joker cap must be an explicit 5% step up to 30%.',
            field: 'jokerCapPercent',
          ),
        );
      }
      issues.add(
        const CalculatorIssue(
          'joker_runtime_decision',
          'Joker sets are optional targets: only perform them after a successful performance set with sound bar speed.',
          field: 'jokersEnabled',
          blocking: false,
        ),
      );
    }
    return issues;
  }

  CalculatorProgram generate(CalculatorConfiguration configuration) {
    final issues = validate(configuration);
    if (issues.any((issue) => issue.blocking)) {
      throw CalculatorValidationException(issues);
    }
    final orders = configuration.options.order == MainWorkOrder.fiveThreeOne
        ? const [0, 1, 2]
        : const [1, 0, 2];
    const percentages = [
      [65, 75, 85],
      [70, 80, 90],
      [75, 85, 95],
    ];
    const reps = [
      [5, 5, 5],
      [3, 3, 3],
      [5, 3, 1],
    ];
    final weeks = <CalculatorWeek>[];
    for (var displayed = 0; displayed < orders.length; displayed++) {
      final sourceWeek = orders[displayed];
      final mainReps =
          configuration.template == CalculatorTemplateId.fivesProgression
          ? const [5, 5, 5]
          : reps[sourceWeek];
      weeks.add(
        CalculatorWeek(
          number: displayed + 1,
          sessions: _sessions(
            configuration,
            percentages[sourceWeek],
            mainReps,
            scheduleWeek: displayed,
            suppressAmrap:
                configuration.template ==
                    CalculatorTemplateId.fivesProgression ||
                (configuration.options.order == MainWorkOrder.threeFiveOne &&
                    sourceWeek == 0),
            sourceWeek: sourceWeek,
          ),
        ),
      );
    }
    if (configuration.options.deload != DeloadOption.none) {
      final prescription = _deloadPrescription(configuration.options.deload);
      weeks.add(
        CalculatorWeek(
          number: 4,
          deload: true,
          sessions: _sessions(
            configuration,
            prescription.$1,
            prescription.$2,
            scheduleWeek: 3,
            suppressAmrap: true,
            highIntensityDeload:
                configuration.options.deload == DeloadOption.highIntensity,
          ),
        ),
      );
    }
    return CalculatorProgram(
      schemaVersion: 1,
      configuration: configuration,
      weeks: List.unmodifiable(weeks),
      sources: calculatorTemplate(configuration.template).sources,
      warnings: configuration.options.jokersEnabled
          ? [
              'Joker policy: optional ${configuration.options.jokerIncrementPercent}% steps, capped at +${configuration.options.jokerCapPercent}%. Apply only after a successful performance set with sound bar speed.',
            ]
          : const [],
    );
  }

  List<CalculatorSession> _sessions(
    CalculatorConfiguration configuration,
    List<int> percentages,
    List<int> repetitions, {
    required int scheduleWeek,
    bool suppressAmrap = false,
    int? sourceWeek,
    bool highIntensityDeload = false,
  }) => _scheduledLifts(configuration, scheduleWeek)
      .map((lift) {
        final tm = configuration.trainingMaxes[lift]!;
        final sets = <CalculatorSet>[];
        final skipWarmup =
            sourceWeek == null && configuration.options.skipWarmupDuringDeload;
        if (!skipWarmup) {
          sets.addAll(
            _warmup(
              configuration,
              lift,
              tm,
              highIntensityDeload ? 100 : percentages.first,
            ),
          );
        }
        if (highIntensityDeload) {
          sets.addAll(_highIntensity(configuration, lift, tm));
        } else {
          sets.addAll(
            List.generate(
              3,
              (index) => CalculatorSet(
                repetitions: repetitions[index],
                percent: percentages[index],
                weight: _round(tm * percentages[index] / 100),
                amrap: index == 2 && !suppressAmrap,
              ),
            ),
          );
        }
        if (sourceWeek != null) {
          if (configuration.options.jokersEnabled) {
            for (
              var addition = 5;
              addition <= configuration.options.jokerCapPercent;
              addition += 5
            ) {
              final percent = percentages.last + addition;
              sets.add(
                CalculatorSet(
                  repetitions: 0,
                  percent: percent,
                  weight: _round(tm * percent / 100),
                  kind: 'joker',
                  exercise: lift,
                ),
              );
            }
          }
          _appendTemplateWork(
            sets,
            configuration,
            lift,
            tm,
            percentages,
            repetitions,
          );
        }
        return CalculatorSession(lift: lift, sets: List.unmodifiable(sets));
      })
      .toList(growable: false);

  List<String> _scheduledLifts(
    CalculatorConfiguration configuration,
    int weekIndex,
  ) {
    if (configuration.daysPerWeek >= configuration.liftOrder.length) {
      return configuration.liftOrder;
    }
    final start =
        (weekIndex * configuration.daysPerWeek) %
        configuration.liftOrder.length;
    return List.generate(
      configuration.daysPerWeek,
      (index) =>
          configuration.liftOrder[(start + index) %
              configuration.liftOrder.length],
      growable: false,
    );
  }

  (List<int>, List<int>) _deloadPrescription(DeloadOption option) =>
      switch (option) {
        DeloadOption.deload1 => (const [40, 50, 60], const [5, 5, 5]),
        DeloadOption.deload2 => (const [50, 60, 70], const [5, 5, 5]),
        DeloadOption.deload3 => (const [65, 75, 85], const [3, 3, 3]),
        DeloadOption.deload4 => (const [40, 50, 60], const [10, 8, 6]),
        DeloadOption.deload5 => (const [50, 60, 70], const [10, 8, 6]),
        DeloadOption.highIntensity => (const <int>[], const <int>[]),
        DeloadOption.none => throw StateError('No deload has no prescription.'),
      };

  List<CalculatorSet> _warmup(
    CalculatorConfiguration configuration,
    String lift,
    double tm,
    int firstWorkPercent,
  ) {
    if (configuration.options.warmup == WarmupOption.none) return const [];
    if (configuration.options.warmup == WarmupOption.original) {
      return const [(40, 5), (50, 5), (60, 3)]
          .map(
            (item) => CalculatorSet(
              repetitions: item.$2,
              percent: item.$1,
              weight: 0,
              kind: 'warmup',
            ),
          )
          .map(
            (set) => CalculatorSet(
              repetitions: set.repetitions,
              percent: set.percent,
              weight: _round(tm * set.percent / 100),
              kind: 'warmup',
            ),
          )
          .toList();
    }
    final base = _isUpper(lift)
        ? configuration.warmupBaseUpper
        : configuration.warmupBaseLower;
    final result = <CalculatorSet>[];
    for (
      var percent = firstWorkPercent - 10;
      percent > 0 && _round(tm * percent / 100) > base;
      percent -= 10
    ) {
      result.insert(
        0,
        CalculatorSet(
          repetitions: 5,
          percent: percent,
          weight: _round(tm * percent / 100),
          kind: 'warmup',
        ),
      );
    }
    result.insert(
      0,
      CalculatorSet(repetitions: 10, percent: 0, weight: base, kind: 'warmup'),
    );
    return result;
  }

  List<CalculatorSet> _highIntensity(
    CalculatorConfiguration configuration,
    String lift,
    double tm,
  ) {
    final base = _isUpper(lift)
        ? configuration.warmupBaseUpper
        : configuration.warmupBaseLower;
    final sets = <CalculatorSet>[
      CalculatorSet(
        repetitions: 10,
        percent: 0,
        weight: roundingIncrement,
        kind: 'deload',
      ),
      CalculatorSet(repetitions: 5, percent: 0, weight: base, kind: 'deload'),
    ];
    for (var percent = 10; percent < 95; percent += 10) {
      final weight = _round(tm * percent / 100);
      if (weight > base) {
        sets.add(
          CalculatorSet(
            repetitions: 5,
            percent: percent,
            weight: weight,
            kind: 'deload',
          ),
        );
      }
    }
    sets.add(
      CalculatorSet(
        repetitions: 1,
        percent: 100,
        weight: _round(tm),
        kind: 'deload',
      ),
    );
    return sets;
  }

  bool _isUpper(String lift) => lift == 'press' || lift == 'bench';

  void _appendTemplateWork(
    List<CalculatorSet> sets,
    CalculatorConfiguration configuration,
    String lift,
    double tm,
    List<int> percentages,
    List<int> repetitions,
  ) {
    if (configuration.template == CalculatorTemplateId.boringButBig) {
      final supplementalTm = configuration.variantId == 'less-boring'
          ? configuration.trainingMaxes[_oppositeLift(lift)]!
          : tm;
      final weeklyPercent = switch (configuration.variantId) {
        'beyond-variation-1' || 'beyond-variation-2' =>
          const [65, 70, 75][percentages.first == 65
              ? 0
              : percentages.first == 70
              ? 1
              : 2],
        'two-days' =>
          const [50, 60, 70][percentages.first == 65
              ? 0
              : percentages.first == 70
              ? 1
              : 2],
        '5x5' => 80,
        '5x3' => 90,
        '5x1' => 100,
        _ => configuration.supplementalPercent,
      };
      final reps = switch (configuration.variantId) {
        '5x5' => 5,
        '5x3' => 3,
        '5x1' => 1,
        'beyond-variation-2' => const {65: 10, 70: 8, 75: 5}[weeklyPercent]!,
        _ => 10,
      };
      sets.addAll(
        List.generate(
          5,
          (_) => CalculatorSet(
            repetitions: reps,
            percent: weeklyPercent,
            weight: _round(supplementalTm * weeklyPercent / 100),
            kind: 'supplemental',
          ),
        ),
      );
    } else if (configuration.template == CalculatorTemplateId.pyramid) {
      for (final index in const [1, 0]) {
        sets.add(
          CalculatorSet(
            repetitions: repetitions[index],
            percent: percentages[index],
            weight: _round(tm * percentages[index] / 100),
            kind: 'supplemental',
          ),
        );
      }
    } else if (configuration.template == CalculatorTemplateId.firstSetLast) {
      final count = configuration.variantId == 'multiple-sets'
          ? configuration.fslSetCount
          : 1;
      sets.addAll(
        List.generate(
          count,
          (_) => CalculatorSet(
            repetitions: configuration.variantId == 'multiple-sets'
                ? configuration.fslRepCount
                : repetitions.first,
            percent: percentages.first,
            weight: _round(tm * percentages.first / 100),
            amrap: configuration.variantId == 'amrap',
            kind: 'supplemental',
          ),
        ),
      );
    } else if (configuration.template ==
        CalculatorTemplateId.simplestStrength) {
      final index = percentages.first == 65
          ? 0
          : percentages.first == 70
          ? 1
          : 2;
      const simplestPercentages = [
        [50, 60, 70],
        [60, 70, 80],
        [65, 75, 85],
      ];
      const simplestReps = [
        [10, 10, 10],
        [8, 8, 8],
        [5, 5, 5],
      ];
      for (var setIndex = 0; setIndex < 3; setIndex++) {
        final percent = simplestPercentages[index][setIndex];
        sets.add(
          CalculatorSet(
            repetitions: simplestReps[index][setIndex],
            percent: percent,
            weight: _round(tm * percent / 100),
            kind: 'supplemental',
            exercise: _simplestSupplemental[lift],
          ),
        );
      }
      for (final exercise in _simplestAssistance[lift]!) {
        sets.addAll(_assistance(exercise, 3, 12));
      }
    } else if (configuration.template == CalculatorTemplateId.triumvirate) {
      final prescriptions = _triumvirate[lift]!;
      for (final prescription in prescriptions) {
        sets.addAll(_assistance(prescription.$1, 5, prescription.$2));
      }
    } else if (configuration.template ==
        CalculatorTemplateId.periodizationBible) {
      final prescriptions = _periodizationBible[lift]!;
      for (final prescription in prescriptions) {
        sets.addAll(_assistance(prescription.$1, 5, prescription.$2));
      }
    } else if (configuration.template == CalculatorTemplateId.bodyweight) {
      final distribution = _distributeRepetitions(
        configuration.bodyweightTotalReps,
        configuration.bodyweightSetCount,
      );
      for (final exercise in _bodyweight[lift]!) {
        for (final reps in distribution) {
          sets.add(
            CalculatorSet(
              repetitions: reps,
              percent: 0,
              weight: 0,
              kind: 'assistance',
              exercise: exercise,
            ),
          );
        }
      }
    } else if (configuration.template ==
        CalculatorTemplateId.germanVolumeTraining) {
      final supplementalLift = configuration.gvtLessBoring
          ? _oppositeLift(lift)
          : lift;
      final supplementalTm = configuration.trainingMaxes[supplementalLift]!;
      final gvtPercent =
          configuration.gvtPercents[lift] ?? configuration.gvtPercent;
      sets.addAll(
        List.generate(
          10,
          (_) => CalculatorSet(
            repetitions: 10,
            percent: gvtPercent,
            weight: _round(supplementalTm * gvtPercent / 100),
            kind: 'supplemental',
            exercise: supplementalLift,
          ),
        ),
      );
      final assistance = _gvtAssistance[supplementalLift]!;
      sets.addAll(_assistance(assistance.$1, assistance.$2, assistance.$3));
    }
  }

  List<CalculatorSet> _assistance(String exercise, int count, int reps) =>
      List.generate(
        count,
        (_) => CalculatorSet(
          repetitions: reps,
          percent: 0,
          weight: 0,
          kind: 'assistance',
          exercise: exercise,
        ),
      );

  List<int> _distributeRepetitions(int total, int sets) {
    final base = total ~/ sets;
    final remainder = total % sets;
    return List.generate(sets, (index) => base + (index < remainder ? 1 : 0));
  }

  static const _triumvirate = <String, List<(String, int)>>{
    'press': [('Dips', 15), ('Pull-up', 10)],
    'bench': [('Dumbbell Bench Press', 15), ('Dumbbell Row', 10)],
    'squat': [('Leg Press', 15), ('Hamstring Curl', 10)],
    'deadlift': [('Good Morning', 12), ('Hanging Leg Raise', 15)],
  };

  static const _periodizationBible = <String, List<(String, int)>>{
    'press': [('Dips', 15), ('Pull-up', 10), ('Pushdown', 15)],
    'bench': [
      ('Dumbbell Bench Press', 15),
      ('Dumbbell Row', 10),
      ('Triceps Extension', 15),
    ],
    'squat': [
      ('Good Morning', 12),
      ('Leg Press', 15),
      ('Hanging Leg Raise', 15),
    ],
    'deadlift': [
      ('Hamstring Curl', 10),
      ('Leg Press', 15),
      ('Hanging Leg Raise', 15),
    ],
  };

  static const _bodyweight = <String, List<String>>{
    'press': ['Pull-up', 'Dips'],
    'bench': ['Pull-up', 'Push-up'],
    'squat': ['One-leg Squat', 'Sit-up'],
    'deadlift': ['Glute-ham Raise', 'Hanging Leg Raise'],
  };

  static const _simplestSupplemental = <String, String>{
    'press': 'Close-grip Bench Press',
    'bench': 'Incline Press',
    'squat': 'Front Squat',
    'deadlift': 'Straight-leg Deadlift',
  };

  static const _simplestAssistance = <String, List<String>>{
    'press': ['Dumbbell Row', 'Pull-up', 'Pushdown', 'Biceps Curl'],
    'bench': ['Dumbbell Row', 'Pull-up', 'Dips', 'Biceps Curl'],
    'squat': ['Glute-ham Raise', 'Good Morning', 'Hanging Leg Raise'],
    'deadlift': ['Hamstring Curl', 'Good Morning', 'Sit-up'],
  };

  static const _gvtAssistance = <String, (String, int, int)>{
    'press': ('Lat Pulldown', 10, 10),
    'bench': ('Dumbbell Row', 10, 10),
    'squat': ('Ab Wheel', 5, 10),
    'deadlift': ('Hanging Leg Raise', 5, 15),
  };

  String _oppositeLift(String lift) => switch (lift) {
    'press' => 'bench',
    'bench' => 'press',
    'squat' => 'deadlift',
    'deadlift' => 'squat',
    _ => throw ArgumentError.value(lift, 'lift'),
  };

  double _round(double value) =>
      (value / roundingIncrement).round() * roundingIncrement;

  String serializeConfiguration(CalculatorConfiguration configuration) =>
      jsonEncode(configuration.toJson());

  CalculatorConfiguration deserializeConfiguration(String payload) {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported calculator schema version.');
    }
    final options = json['options'] as Map<String, dynamic>;
    return CalculatorConfiguration(
      template: CalculatorTemplateId.values.byName(json['template'] as String),
      variantId: json['variantId'] as String,
      trainingMaxes: (json['trainingMaxes'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      daysPerWeek: json['daysPerWeek'] as int,
      unit: json['unit'] as String? ?? 'kg',
      supplementalPercent: json['supplementalPercent'] as int? ?? 50,
      warmupBaseUpper: (json['warmupBaseUpper'] as num?)?.toDouble() ?? 20,
      warmupBaseLower: (json['warmupBaseLower'] as num?)?.toDouble() ?? 20,
      bodyweightTotalReps: json['bodyweightTotalReps'] as int? ?? 75,
      bodyweightSetCount: json['bodyweightSetCount'] as int? ?? 5,
      fslSetCount: json['fslSetCount'] as int? ?? 3,
      fslRepCount: json['fslRepCount'] as int? ?? 5,
      gvtPercent: json['gvtPercent'] as int? ?? 30,
      gvtLessBoring: json['gvtLessBoring'] as bool? ?? false,
      gvtPercents: (json['gvtPercents'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value as int)),
      liftOrder: (json['liftOrder'] as List).cast<String>(),
      options: CalculatorOptions(
        order: MainWorkOrder.values.byName(options['order'] as String),
        warmup: WarmupOption.values.byName(options['warmup'] as String),
        jokersEnabled: options['jokersEnabled'] as bool,
        jokerIncrementPercent: options['jokerIncrementPercent'] as int,
        jokerCapPercent: options['jokerCapPercent'] as int,
        deload: DeloadOption.values.byName(options['deload'] as String),
        skipWarmupDuringDeload: options['skipWarmupDuringDeload'] as bool,
      ),
    );
  }
}

class CalculatorValidationException implements Exception {
  const CalculatorValidationException(this.issues);
  final List<CalculatorIssue> issues;
  @override
  String toString() =>
      'CalculatorValidationException(${issues.map((issue) => issue.code).join(', ')})';
}
