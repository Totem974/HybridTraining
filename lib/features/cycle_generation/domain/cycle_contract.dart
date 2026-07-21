enum WeightUnit { kg, lb }

final class Weight {
  const Weight(this.centiUnits, this.unit) : assert(centiUnits >= 0);
  final int centiUnits;
  final WeightUnit unit;
  double get value => centiUnits / 100;

  Map<String, Object> toJson() => {'centiUnits': centiUnits, 'unit': unit.name};
  static Weight fromJson(Map<String, Object?> json) => Weight(
    json['centiUnits']! as int,
    WeightUnit.values.byName(json['unit']! as String),
  );
}

final class Percentage {
  const Percentage(this.basisPoints)
    : assert(basisPoints >= 0),
      assert(basisPoints <= 20000);
  final int basisPoints;
  double get value => basisPoints / 10000;
}

extension type const MovementId(String value) {}

sealed class TrainingMaxInput {
  const TrainingMaxInput();
}

final class OneRepMaxInput extends TrainingMaxInput {
  const OneRepMaxInput(this.weight);
  final Weight weight;
}

final class RepMaxInput extends TrainingMaxInput {
  const RepMaxInput(this.weight, this.repetitions, {this.formula = 'epley'})
    : assert(repetitions > 0);
  final Weight weight;
  final int repetitions;
  final String formula;
}

final class DirectTrainingMaxInput extends TrainingMaxInput {
  const DirectTrainingMaxInput(this.weight);
  final Weight weight;
}

sealed class RepetitionPrescription {
  const RepetitionPrescription();
  Map<String, Object> toJson();
}

final class FixedRepetitions extends RepetitionPrescription {
  const FixedRepetitions(this.count) : assert(count > 0);
  final int count;
  @override
  Map<String, Object> toJson() => {'type': 'fixed', 'count': count};
}

final class RepetitionRange extends RepetitionPrescription {
  const RepetitionRange(this.minimum, this.maximum)
    : assert(minimum > 0),
      assert(maximum >= minimum);
  final int minimum;
  final int maximum;
  @override
  Map<String, Object> toJson() => {
    'type': 'range',
    'minimum': minimum,
    'maximum': maximum,
  };
}

final class TotalRepetitions extends RepetitionPrescription {
  const TotalRepetitions(this.total) : assert(total > 0);
  final int total;
  @override
  Map<String, Object> toJson() => {'type': 'total', 'total': total};
}

final class AmrapRepetitions extends RepetitionPrescription {
  const AmrapRepetitions({this.minimum});
  final int? minimum;
  @override
  Map<String, Object> toJson() => {'type': 'amrap', 'minimum': ?minimum};
}

sealed class LoadPrescription {
  const LoadPrescription();
}

final class TrainingMaxPercentageLoad extends LoadPrescription {
  const TrainingMaxPercentageLoad(this.percentage);
  final Percentage percentage;
}

final class ParameterizedTrainingMaxPercentageLoad extends LoadPrescription {
  const ParameterizedTrainingMaxPercentageLoad({
    required this.parameterId,
    required this.defaultValue,
    required this.minimum,
    required this.maximum,
  });
  final String parameterId;
  final Percentage defaultValue;
  final Percentage minimum;
  final Percentage maximum;
}

final class OneRepMaxPercentageLoad extends LoadPrescription {
  const OneRepMaxPercentageLoad(this.percentage);
  final Percentage percentage;
}

final class FixedLoad extends LoadPrescription {
  const FixedLoad(this.weight);
  final Weight weight;
}

final class BodyweightLoad extends LoadPrescription {
  const BodyweightLoad();
}

final class Unloaded extends LoadPrescription {
  const Unloaded();
}

final class PrescribedSetDefinition {
  const PrescribedSetDefinition({
    required this.repetitions,
    required this.load,
  });
  final RepetitionPrescription repetitions;
  final LoadPrescription load;
}

final class BlockDefinition {
  const BlockDefinition({
    required this.id,
    required this.role,
    required this.sets,
    this.movementId,
  });
  final String id;
  final String role;
  final List<PrescribedSetDefinition> sets;
  final MovementId? movementId;
}

final class SessionDefinition {
  const SessionDefinition({
    required this.id,
    required this.role,
    required this.blocks,
  });
  final MovementId id;
  final String role;
  final List<BlockDefinition> blocks;
}

final class WeekDefinition {
  const WeekDefinition({
    required this.number,
    this.blocks = const [],
    this.sessions = const [],
  });
  final int number;
  final List<BlockDefinition> blocks;
  final List<SessionDefinition> sessions;
}

final class ResolvedCycleDefinition {
  const ResolvedCycleDefinition({
    required this.catalogVersion,
    required this.templateId,
    required this.variantId,
    required this.sessionMovementIds,
    required this.weeks,
    required this.sourceReference,
  });
  final int catalogVersion;
  final String templateId;
  final String variantId;
  final List<MovementId> sessionMovementIds;
  final List<WeekDefinition> weeks;
  final String sourceReference;
}

final class BarProfile {
  const BarProfile({required this.weight, required this.platesPerSide});
  final Weight weight;
  final List<Weight> platesPerSide;
}

final class CycleRequest {
  const CycleRequest({
    required this.cycleId,
    required this.startDate,
    required this.trainingDays,
    required this.sessionOrder,
    required this.maxInputs,
    required this.globalTrainingMaxRatio,
    this.trainingMaxRatioByMovement = const {},
    this.percentageParameters = const {},
    this.percentageParametersByMovement = const {},
    required this.unit,
    required this.roundingIncrement,
    required this.barProfile,
    this.includeDeload = true,
  });
  final String cycleId;
  final DateTime startDate;
  final List<int> trainingDays;
  final List<MovementId> sessionOrder;
  final Map<MovementId, TrainingMaxInput> maxInputs;
  final Percentage globalTrainingMaxRatio;
  final Map<MovementId, Percentage> trainingMaxRatioByMovement;
  final Map<String, Percentage> percentageParameters;
  final Map<MovementId, Map<String, Percentage>> percentageParametersByMovement;
  final WeightUnit unit;
  final Weight roundingIncrement;
  final BarProfile barProfile;
  final bool includeDeload;
}

enum GenerationWarningCode { exactLoadUnavailable, insufficientEquipment }

final class GenerationWarning {
  const GenerationWarning(this.code, this.message);
  final GenerationWarningCode code;
  final String message;
  Map<String, Object> toJson() => {'code': code.name, 'message': message};
}

final class GeneratedSet {
  const GeneratedSet({
    required this.index,
    required this.repetitions,
    required this.percentageBasisPoints,
    required this.plannedLoad,
    required this.platesPerSide,
    this.warning,
  });
  final int index;
  final Map<String, Object> repetitions;
  final int? percentageBasisPoints;
  final Weight? plannedLoad;
  final List<Weight> platesPerSide;
  final GenerationWarning? warning;
  Map<String, Object?> toJson() => {
    'index': index,
    'repetitions': repetitions,
    'percentageBasisPoints': percentageBasisPoints,
    'plannedLoad': plannedLoad?.toJson(),
    'platesPerSide': platesPerSide.map((plate) => plate.toJson()).toList(),
    'warning': warning?.toJson(),
  };
}

final class GeneratedBlock {
  const GeneratedBlock({
    required this.id,
    required this.role,
    required this.sets,
    required this.movementId,
  });
  final String id;
  final String role;
  final List<GeneratedSet> sets;
  final MovementId movementId;
  Map<String, Object> toJson() => {
    'id': id,
    'role': role,
    'movementId': movementId.value,
    'sets': sets.map((set) => set.toJson()).toList(),
  };
}

final class GeneratedSession {
  const GeneratedSession({
    required this.id,
    required this.date,
    required this.movementId,
    required this.blocks,
  });
  final String id;
  final DateTime date;
  final MovementId movementId;
  final List<GeneratedBlock> blocks;
  Map<String, Object> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'movementId': movementId.value,
    'blocks': blocks.map((block) => block.toJson()).toList(),
  };
}

final class GeneratedWeek {
  const GeneratedWeek({required this.number, required this.sessions});
  final int number;
  final List<GeneratedSession> sessions;
  Map<String, Object> toJson() => {
    'number': number,
    'sessions': sessions.map((session) => session.toJson()).toList(),
  };
}

final class GeneratedCycle {
  const GeneratedCycle({
    required this.id,
    required this.catalogVersion,
    required this.templateId,
    required this.variantId,
    required this.effectiveTrainingMaxes,
    required this.weeks,
  });
  final String id;
  final int catalogVersion;
  final String templateId;
  final String variantId;
  final Map<String, Weight> effectiveTrainingMaxes;
  final List<GeneratedWeek> weeks;
  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'catalogVersion': catalogVersion,
    'templateId': templateId,
    'variantId': variantId,
    'effectiveTrainingMaxes': effectiveTrainingMaxes.map(
      (key, value) => MapEntry(key, value.toJson()),
    ),
    'weeks': weeks.map((week) => week.toJson()).toList(),
  };
}

abstract interface class CycleCompiler {
  GeneratedCycle compile(
    ResolvedCycleDefinition definition,
    CycleRequest request,
  );
}
