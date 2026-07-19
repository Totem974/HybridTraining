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
      if (![5, 10].contains(configuration.options.jokerIncrementPercent)) {
        issues.add(
          const CalculatorIssue(
            'unsupported_joker_increment',
            'Only verified UI increments of 5% or 10% are accepted.',
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
        'beyond-variation-1' || 'beyond-variation-2' || 'two-days' =>
          const [65, 70, 75][percentages.first == 65
              ? 0
              : percentages.first == 70
              ? 1
              : 2],
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
      final count = configuration.variantId == 'multiple-sets' ? 5 : 1;
      sets.addAll(
        List.generate(
          count,
          (_) => CalculatorSet(
            repetitions: configuration.variantId == 'multiple-sets'
                ? 5
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
        [8, 8, 6],
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
          ),
        );
      }
    }
  }

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
      supplementalPercent: json['supplementalPercent'] as int? ?? 50,
      warmupBaseUpper: (json['warmupBaseUpper'] as num?)?.toDouble() ?? 20,
      warmupBaseLower: (json['warmupBaseLower'] as num?)?.toDouble() ?? 20,
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
