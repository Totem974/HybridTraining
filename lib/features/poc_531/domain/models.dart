import '../../programs/domain/training_models.dart';

enum Generation { original, beyond, forever }

enum SourceKind { canonical, supplement }

enum ProgramStatus { current, legacy, restricted, superseded }

enum CatalogEntryKind {
  executableTemplate,
  component,
  rule,
  schedule,
  protocol,
  transition,
  documentation,
}

enum ExperienceLevel { beginner, intermediate, advanced }

enum TrainingGoal {
  strength,
  hypertrophy,
  generalPreparation,
  reducedFrequency,
  powerliftingPreparation,
}

enum LiftInputKind { oneRepMax, trainingMax, repetitionMax }

class SourceProvenance {
  const SourceProvenance({required this.title, required this.pages});
  final String title;
  final String pages;
  Map<String, Object?> toJson() => {'title': title, 'pages': pages};
}

class ProgramDefinition {
  const ProgramDefinition({
    required this.id,
    required this.name,
    required this.family,
    required this.variant,
    required this.status,
    required this.sourceKind,
    required this.entryKind,
    required this.frequencies,
    required this.levels,
    required this.goals,
    required this.sources,
    this.generation,
    this.generatorId,
    this.nonExecutableReason,
    this.requiresLeaderAnchor = false,
  });
  final String id;
  final String name;
  final String family;
  final String variant;
  final Generation? generation;
  final ProgramStatus status;
  final SourceKind sourceKind;
  final CatalogEntryKind entryKind;
  final Set<int> frequencies;
  final Set<ExperienceLevel> levels;
  final Set<TrainingGoal> goals;
  final List<SourceProvenance> sources;
  final String? generatorId;
  final String? nonExecutableReason;
  final bool requiresLeaderAnchor;
  bool get isExecutable =>
      entryKind == CatalogEntryKind.executableTemplate && generatorId != null;
}

class LiftInput {
  const LiftInput({
    required this.lift,
    required this.kind,
    required this.weight,
    this.repetitions,
  });
  final MainLift lift;
  final LiftInputKind kind;
  final double weight;
  final int? repetitions;
}

class RepMaxInput {
  const RepMaxInput({required this.weight, required this.repetitions});
  final double weight;
  final int repetitions;
}

class TrainingMaxResult {
  const TrainingMaxResult({
    required this.oneRepMax,
    required this.trainingMax,
    required this.ratio,
  });
  final double oneRepMax;
  final double trainingMax;
  final double ratio;
}

class GenerationSpecificOptions {
  const GenerationSpecificOptions({
    this.confirmedTrainingMaxesByWeek = const {},
    this.confirmedTrainingMaxesByNode = const {},
    this.enablePowerliftingExtension = false,
    this.projectFutureTrainingMaxes = false,
  });
  final Map<int, Map<MainLift, double>> confirmedTrainingMaxesByWeek;
  final Map<String, Map<MainLift, double>> confirmedTrainingMaxesByNode;
  final bool enablePowerliftingExtension;
  final bool projectFutureTrainingMaxes;
}

class ProgramConfiguration {
  ProgramConfiguration({
    required this.programId,
    required this.generation,
    required this.unit,
    required Map<MainLift, LiftInput> lifts,
    required this.trainingMaxRatio,
    required this.daysPerWeek,
    required List<int> trainingWeekdays,
    this.roundingIncrement = 2.5,
    this.options = const GenerationSpecificOptions(),
    this.seed = 0,
    required this.startDate,
  }) : lifts = Map.unmodifiable(lifts),
       trainingWeekdays = List.unmodifiable(trainingWeekdays);
  final String programId;
  final Generation generation;
  final WeightUnit unit;
  final Map<MainLift, LiftInput> lifts;
  final double trainingMaxRatio;
  final int daysPerWeek;
  final List<int> trainingWeekdays;
  final double roundingIncrement;
  final GenerationSpecificOptions options;
  final int seed;
  final DateTime startDate;
}

class UserConstraints {
  const UserConstraints({
    required this.daysPerWeek,
    this.allowLegacy = false,
    this.hasBarbell = true,
  });
  final int daysPerWeek;
  final bool allowLegacy;
  final bool hasBarbell;
}

class UserProfile {
  const UserProfile({
    required this.goal,
    required this.level,
    required this.constraints,
    this.preferredGeneration,
  });
  final TrainingGoal goal;
  final ExperienceLevel level;
  final UserConstraints constraints;
  final Generation? preferredGeneration;
}

class ValidationIssue {
  const ValidationIssue({
    required this.code,
    required this.message,
    required this.field,
    this.blocking = true,
  });
  final String code;
  final String message;
  final String field;
  final bool blocking;
}

class Recommendation {
  const Recommendation({
    required this.program,
    required this.score,
    required this.reasons,
    required this.tradeoffs,
  });
  final ProgramDefinition program;
  final int score;
  final List<String> reasons;
  final List<String> tradeoffs;
}

class GeneratedProgram {
  GeneratedProgram({
    required this.schemaVersion,
    required this.programId,
    required this.generation,
    required this.payload,
    required this.sources,
    this.warnings = const [],
  });
  final int schemaVersion;
  final String programId;
  final Generation generation;
  final Map<String, Object?> payload;
  final List<SourceProvenance> sources;
  final List<String> warnings;
  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'programId': programId,
    'generation': generation.name,
    'payload': payload,
    'sources': sources.map((source) => source.toJson()).toList(),
    'warnings': warnings,
  };
}

class PlateInventory {
  const PlateInventory({required this.barWeight, required this.plates});
  final double barWeight;
  final Map<double, int> plates;
}

class PlateLoadingResult {
  const PlateLoadingResult({
    required this.requestedWeight,
    required this.loadedWeight,
    required this.perSide,
    required this.roundingError,
  });
  final double requestedWeight;
  final double loadedWeight;
  final List<double> perSide;
  final double roundingError;
}

class CatalogSummary {
  const CatalogSummary({
    required this.total,
    required this.executable,
    required this.byGeneration,
  });
  final int total;
  final int executable;
  final Map<Generation, int> byGeneration;
}

class CatalogCoverageReport {
  const CatalogCoverageReport({
    required this.total,
    required this.classified,
    required this.executable,
    required this.nonExecutable,
    required this.ambiguous,
  });
  final int total;
  final int classified;
  final int executable;
  final int nonExecutable;
  final int ambiguous;
  bool get isComplete => total == classified && ambiguous == 0;
}

class ProgramFilters {
  const ProgramFilters({
    this.generation,
    this.includeLegacy = false,
    this.executableOnly = true,
    this.includeSupplements = false,
  });
  final Generation? generation;
  final bool includeLegacy;
  final bool executableOnly;
  final bool includeSupplements;
}
