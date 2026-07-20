enum CalculatorTemplateId {
  standard,
  boringButBig,
  triumvirate,
  periodizationBible,
  bodyweight,
  simplestStrength,
  forBeginners,
  fullBody,
  twoDaysPerWeek,
  pyramid,
  firstSetLast,
  germanVolumeTraining,
  fivesProgression,
  boringButBigChallenge,
}

enum MainWorkOrder { fiveThreeOne, threeFiveOne }

enum EvidenceStatus { executable, needsReview }

enum WarmupOption { none, original, beyond }

enum DeloadOption {
  none,
  deload1,
  deload2,
  deload3,
  deload4,
  deload5,
  highIntensity,
}

enum BbbVariant {
  original5x10,
  lessBoring,
  fiveByFive,
  fiveByThree,
  fiveByOne,
  beyondVariation1,
  beyondVariation2,
  twoDaysPerWeek,
}

enum FslVariant { amrap, multipleSets }

class CalculatorSource {
  const CalculatorSource(this.title, this.pages);
  final String title;
  final String pages;
  Map<String, Object?> toJson() => {'title': title, 'pages': pages};
}

class VariantDefinition {
  const VariantDefinition({
    required this.id,
    required this.label,
    required this.status,
    required this.sources,
    this.allowedDays = const {3, 4},
    this.blockedReason,
  });
  final String id;
  final String label;
  final EvidenceStatus status;
  final Set<int> allowedDays;
  final List<CalculatorSource> sources;
  final String? blockedReason;
  bool get executable => status == EvidenceStatus.executable;
}

class TemplateDefinition {
  const TemplateDefinition({
    required this.id,
    required this.label,
    required this.variants,
    required this.allowedDays,
    required this.sources,
  });
  final CalculatorTemplateId id;
  final String label;
  final List<VariantDefinition> variants;
  final Set<int> allowedDays;
  final List<CalculatorSource> sources;
}

class CalculatorOptions {
  const CalculatorOptions({
    this.order = MainWorkOrder.fiveThreeOne,
    this.warmup = WarmupOption.none,
    this.jokersEnabled = false,
    this.jokerIncrementPercent = 5,
    this.jokerCapPercent = 10,
    this.deload = DeloadOption.deload1,
    this.skipWarmupDuringDeload = false,
  });
  final MainWorkOrder order;
  final WarmupOption warmup;
  final bool jokersEnabled;
  final int jokerIncrementPercent;
  final int jokerCapPercent;
  final DeloadOption deload;
  final bool skipWarmupDuringDeload;
  Map<String, Object?> toJson() => {
    'order': order.name,
    'warmup': warmup.name,
    'jokersEnabled': jokersEnabled,
    'jokerIncrementPercent': jokerIncrementPercent,
    'jokerCapPercent': jokerCapPercent,
    'deload': deload.name,
    'skipWarmupDuringDeload': skipWarmupDuringDeload,
  };
}

class CalculatorConfiguration {
  CalculatorConfiguration({
    required this.template,
    required this.variantId,
    required Map<String, double> trainingMaxes,
    required this.daysPerWeek,
    this.unit = 'kg',
    this.options = const CalculatorOptions(),
    this.supplementalPercent = 50,
    this.warmupBaseUpper = 20,
    this.warmupBaseLower = 20,
    this.bodyweightTotalReps = 75,
    this.bodyweightSetCount = 5,
    this.fslSetCount = 3,
    this.fslRepCount = 5,
    this.gvtPercent = 30,
    this.gvtLessBoring = false,
    Map<String, int> gvtPercents = const {},
    List<String> liftOrder = const ['press', 'deadlift', 'bench', 'squat'],
  }) : trainingMaxes = Map.unmodifiable(trainingMaxes),
       gvtPercents = Map.unmodifiable(gvtPercents),
       liftOrder = List.unmodifiable(liftOrder);
  final CalculatorTemplateId template;
  final String variantId;
  final Map<String, double> trainingMaxes;
  final int daysPerWeek;
  final String unit;
  final CalculatorOptions options;
  final int supplementalPercent;
  final double warmupBaseUpper;
  final double warmupBaseLower;
  final int bodyweightTotalReps;
  final int bodyweightSetCount;
  final int fslSetCount;
  final int fslRepCount;
  final int gvtPercent;
  final bool gvtLessBoring;
  final Map<String, int> gvtPercents;
  final List<String> liftOrder;
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'template': template.name,
    'variantId': variantId,
    'trainingMaxes': trainingMaxes,
    'daysPerWeek': daysPerWeek,
    'unit': unit,
    'supplementalPercent': supplementalPercent,
    'warmupBaseUpper': warmupBaseUpper,
    'warmupBaseLower': warmupBaseLower,
    'bodyweightTotalReps': bodyweightTotalReps,
    'bodyweightSetCount': bodyweightSetCount,
    'fslSetCount': fslSetCount,
    'fslRepCount': fslRepCount,
    'gvtPercent': gvtPercent,
    'gvtLessBoring': gvtLessBoring,
    'gvtPercents': gvtPercents,
    'options': options.toJson(),
    'liftOrder': liftOrder,
  };
}

class CalculatorIssue {
  const CalculatorIssue(
    this.code,
    this.message, {
    this.field = '',
    this.blocking = true,
  });
  final String code;
  final String message;
  final String field;
  final bool blocking;
}

class CalculatorSet {
  const CalculatorSet({
    required this.repetitions,
    required this.percent,
    required this.weight,
    this.amrap = false,
    this.kind = 'main',
    this.exercise,
  });
  final int repetitions;
  final int percent;
  final double weight;
  final bool amrap;
  final String kind;
  final String? exercise;
  Map<String, Object?> toJson() => {
    'repetitions': repetitions,
    'percent': percent,
    'weight': weight,
    'amrap': amrap,
    'kind': kind,
    if (exercise != null) 'exercise': exercise,
  };
}

class CalculatorSession {
  const CalculatorSession({required this.lift, required this.sets});
  final String lift;
  final List<CalculatorSet> sets;
  Map<String, Object?> toJson() => {
    'lift': lift,
    'sets': sets.map((s) => s.toJson()).toList(),
  };
}

class CalculatorWeek {
  const CalculatorWeek({
    required this.number,
    required this.sessions,
    this.deload = false,
  });
  final int number;
  final List<CalculatorSession> sessions;
  final bool deload;
  Map<String, Object?> toJson() => {
    'number': number,
    'deload': deload,
    'sessions': sessions.map((s) => s.toJson()).toList(),
  };
}

class CalculatorProgram {
  const CalculatorProgram({
    required this.schemaVersion,
    required this.configuration,
    required this.weeks,
    required this.sources,
    this.warnings = const [],
  });
  final int schemaVersion;
  final CalculatorConfiguration configuration;
  final List<CalculatorWeek> weeks;
  final List<CalculatorSource> sources;
  final List<String> warnings;
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'configuration': configuration.toJson(),
    'weeks': weeks.map((w) => w.toJson()).toList(),
    'sources': sources.map((s) => s.toJson()).toList(),
    'warnings': warnings,
  };
}
