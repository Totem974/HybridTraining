import '../../load_rounding.dart';
import '../../training_models.dart';
import '../program_domain.dart';
import 'generated_training_plan.dart';

enum CanonicalCycleModel { standard531, alternative351 }

enum TrainingMaxDecisionState { previewed, confirmed }

class CanonicalGenerationBlueprint {
  const CanonicalGenerationBlueprint({
    required this.id,
    required this.version,
    required this.sourceEdition,
    required this.generation,
    required this.cycleModel,
    required this.source,
  });

  static const standardPowerlifting = CanonicalGenerationBlueprint(
    id: ProgramBlueprintId('powerlifting-standard-531-v1'),
    version: ProgramVersion(1),
    sourceEdition: SourceEdition.powerlifting,
    generation: MethodGeneration.powerlifting,
    cycleModel: CanonicalCycleModel.standard531,
    source: RuleReference(
      document: '5/3/1 for Powerlifting',
      location: 'PDF pages 10-14',
    ),
  );

  static const beyondSixWeek = CanonicalGenerationBlueprint(
    id: ProgramBlueprintId('beyond-six-week-cycle-v1'),
    version: ProgramVersion(1),
    sourceEdition: SourceEdition.beyond,
    generation: MethodGeneration.beyond,
    cycleModel: CanonicalCycleModel.standard531,
    source: RuleReference(
      document: 'Beyond 5/3/1',
      location: 'PDF pages 9, 11-12',
    ),
  );

  static const foreverOriginalFsl = CanonicalGenerationBlueprint(
    id: ProgramBlueprintId('forever-original-531-fsl-2l1a-v1'),
    version: ProgramVersion(1),
    sourceEdition: SourceEdition.forever,
    generation: MethodGeneration.forever,
    cycleModel: CanonicalCycleModel.alternative351,
    source: RuleReference(
      document: '5/3/1 Forever',
      location: 'PDF pages 29-33 and 180-182',
    ),
  );

  final ProgramBlueprintId id;
  final ProgramVersion version;
  final SourceEdition sourceEdition;
  final MethodGeneration generation;
  final CanonicalCycleModel cycleModel;
  final RuleReference source;
}

class CanonicalAthleteConfiguration {
  CanonicalAthleteConfiguration({
    required List<MovementId> movementOrder,
    required Map<MovementId, double> trainingMaxes,
    required Map<MovementId, double> progressionIncrements,
    required List<int> trainingWeekdays,
    required this.startDate,
    required this.unit,
    required this.rounder,
    Map<MovementId, double>? confirmedBeyondTrainingMaxes,
    Map<int, Map<MovementId, double>> confirmedTrainingMaxesByWeek = const {},
  }) : movementOrder = List.unmodifiable(movementOrder),
       trainingMaxes = Map.unmodifiable(trainingMaxes),
       progressionIncrements = Map.unmodifiable(progressionIncrements),
       trainingWeekdays = List.unmodifiable(trainingWeekdays),
       confirmedBeyondTrainingMaxes = confirmedBeyondTrainingMaxes == null
           ? null
           : Map.unmodifiable(confirmedBeyondTrainingMaxes),
       confirmedTrainingMaxesByWeek = Map.unmodifiable({
         for (final entry in confirmedTrainingMaxesByWeek.entries)
           entry.key: Map<MovementId, double>.unmodifiable(entry.value),
       });

  final List<MovementId> movementOrder;
  final Map<MovementId, double> trainingMaxes;
  final Map<MovementId, double> progressionIncrements;
  final List<int> trainingWeekdays;
  final LocalDate startDate;
  final WeightUnit unit;
  final LoadRounder rounder;
  final Map<MovementId, double>? confirmedBeyondTrainingMaxes;
  final Map<int, Map<MovementId, double>> confirmedTrainingMaxesByWeek;
}

class CanonicalGeneratedSession {
  CanonicalGeneratedSession({
    required this.id,
    required this.position,
    required this.date,
    required this.movementId,
    required List<ActivityPrescription> prescriptions,
  }) : prescriptions = List.unmodifiable(prescriptions);

  final String id;
  final int position;
  final LocalDate date;
  final MovementId movementId;
  final List<ActivityPrescription> prescriptions;

  Map<String, Object?> toJson() => {
    'id': id,
    'position': position,
    'date': date.iso8601,
    'movementId': movementId.value,
    'prescriptions': prescriptions.map(_prescriptionJson).toList(),
  };
}

class CanonicalProgrammingWeek {
  CanonicalProgrammingWeek({
    required this.number,
    required this.cycleNumber,
    required List<CanonicalGeneratedSession> sessions,
  }) : sessions = List.unmodifiable(sessions);

  final int number;
  final int cycleNumber;
  final List<CanonicalGeneratedSession> sessions;

  Map<String, Object?> toJson() => {
    'number': number,
    'cycleNumber': cycleNumber,
    'sessions': sessions.map((session) => session.toJson()).toList(),
  };
}

class CanonicalGeneratedBlock {
  CanonicalGeneratedBlock({
    required this.id,
    required this.type,
    required this.role,
    required this.sourceEdition,
    required this.generation,
    required this.source,
    required List<CanonicalProgrammingWeek> weeks,
    this.seventhWeekPurpose,
  }) : weeks = List.unmodifiable(weeks);

  final String id;
  final BlockType type;
  final BlockRole role;
  final SourceEdition sourceEdition;
  final MethodGeneration generation;
  final RuleReference source;
  final SeventhWeekPurpose? seventhWeekPurpose;
  final List<CanonicalProgrammingWeek> weeks;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'role': role.name,
    'sourceEdition': sourceEdition.name,
    'generation': generation.name,
    'source': _sourceJson(source),
    'seventhWeekPurpose': seventhWeekPurpose?.name,
    'weeks': weeks.map((week) => week.toJson()).toList(),
  };
}

class TrainingMaxTimelineDecision {
  const TrainingMaxTimelineDecision({
    required this.id,
    required this.sequence,
    required this.movementId,
    required this.afterProgrammingWeek,
    required this.previousTrainingMax,
    required this.proposedTrainingMax,
    required this.state,
    required this.reason,
    required this.source,
    this.confirmedTrainingMax,
  });

  final String id;
  final int sequence;
  final MovementId movementId;
  final int afterProgrammingWeek;
  final double previousTrainingMax;
  final double proposedTrainingMax;
  final double? confirmedTrainingMax;
  final TrainingMaxDecisionState state;
  final String reason;
  final RuleReference source;

  Map<String, Object?> toJson() => {
    'id': id,
    'sequence': sequence,
    'movementId': movementId.value,
    'afterProgrammingWeek': afterProgrammingWeek,
    'previousTrainingMax': previousTrainingMax,
    'proposedTrainingMax': proposedTrainingMax,
    'confirmedTrainingMax': confirmedTrainingMax,
    'state': state.name,
    'reason': reason,
    'source': _sourceJson(source),
  };
}

class CanonicalGeneratedPlan {
  CanonicalGeneratedPlan({
    required this.schemaVersion,
    required this.blueprintId,
    required this.blueprintVersion,
    required this.sourceEdition,
    required this.generation,
    required this.unit,
    required List<CanonicalGeneratedBlock> blocks,
    required List<TrainingMaxTimelineDecision> trainingMaxTimeline,
    required this.awaitingTrainingMaxConfirmation,
  }) : blocks = List.unmodifiable(blocks),
       trainingMaxTimeline = List.unmodifiable(trainingMaxTimeline);

  final int schemaVersion;
  final ProgramBlueprintId blueprintId;
  final ProgramVersion blueprintVersion;
  final SourceEdition sourceEdition;
  final MethodGeneration generation;
  final WeightUnit unit;
  final List<CanonicalGeneratedBlock> blocks;
  final List<TrainingMaxTimelineDecision> trainingMaxTimeline;
  final bool awaitingTrainingMaxConfirmation;

  List<CanonicalProgrammingWeek> get weeks =>
      blocks.expand((block) => block.weeks).toList(growable: false);

  List<Map<String, Object?>> get transitions => [
    for (var index = 1; index < blocks.length; index++)
      {
        'id': 'transition-${index - 1}-$index',
        'sequence': index - 1,
        'fromBlockId': blocks[index - 1].id,
        'toBlockId': blocks[index].id,
        'transitionType':
            '${blocks[index - 1].role.name}To${blocks[index].role.name}',
        'ruleId': blocks[index].source.document,
        'source': _sourceJson(blocks[index].source),
      },
  ];

  List<Map<String, Object?>> get plannedEvents => [
    for (final decision in trainingMaxTimeline)
      {
        'id': 'event-${decision.id}',
        'sequence': decision.sequence,
        'eventType': decision.afterProgrammingWeek == 11
            ? 'trainingMaxTest'
            : 'trainingMaxDecision',
        'programmingWeekNumber': decision.afterProgrammingWeek,
        'payload': decision.toJson(),
        'ruleId': decision.source.document,
        'source': _sourceJson(decision.source),
      },
  ];

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'blueprintId': blueprintId.value,
    'blueprintVersion': blueprintVersion.value,
    'sourceEdition': sourceEdition.name,
    'generation': generation.name,
    'unit': unit.name,
    'awaitingTrainingMaxConfirmation': awaitingTrainingMaxConfirmation,
    'blocks': blocks.map((block) => block.toJson()).toList(),
    'trainingMaxTimeline': trainingMaxTimeline
        .map((decision) => decision.toJson())
        .toList(),
    'transitions': transitions,
    'plannedEvents': plannedEvents,
  };
}

class CanonicalPlanGenerator {
  const CanonicalPlanGenerator();

  CanonicalGeneratedPlan generate({
    required CanonicalGenerationBlueprint blueprint,
    required CanonicalAthleteConfiguration athlete,
  }) {
    _validate(blueprint, athlete);
    return switch (blueprint.generation) {
      MethodGeneration.powerlifting => _standard(blueprint, athlete),
      MethodGeneration.beyond => _beyond(blueprint, athlete),
      MethodGeneration.forever => _forever(blueprint, athlete),
      _ => throw StateError(
        'No canonical generator registered for ${blueprint.generation.name}.',
      ),
    };
  }

  CanonicalGeneratedPlan _standard(
    CanonicalGenerationBlueprint blueprint,
    CanonicalAthleteConfiguration athlete,
  ) {
    var cursor = athlete.startDate;
    var sessionNumber = 0;
    final workWeeks = <CanonicalProgrammingWeek>[];
    for (var index = 0; index < 3; index++) {
      final generated = _week(
        blueprint: blueprint,
        athlete: athlete,
        trainingMaxes: athlete.trainingMaxes,
        scheme: _workSchemes(blueprint.cycleModel)[index],
        programmingWeek: index + 1,
        cycleNumber: 1,
        cursor: cursor,
        firstSessionNumber: sessionNumber,
      );
      workWeeks.add(generated.week);
      cursor = generated.nextDate;
      sessionNumber += athlete.movementOrder.length;
    }
    final deload = _week(
      blueprint: blueprint,
      athlete: athlete,
      trainingMaxes: athlete.trainingMaxes,
      scheme: _deload,
      programmingWeek: 4,
      cycleNumber: 1,
      cursor: cursor,
      firstSessionNumber: sessionNumber,
    );
    final decisions = _decisions(
      athlete: athlete,
      previous: athlete.trainingMaxes,
      afterProgrammingWeek: 4,
      confirmed: null,
      source: const RuleReference(
        document: '5/3/1 for Powerlifting',
        location: 'PDF pages 14-16',
      ),
    );
    return CanonicalGeneratedPlan(
      schemaVersion: 5,
      blueprintId: blueprint.id,
      blueprintVersion: blueprint.version,
      sourceEdition: blueprint.sourceEdition,
      generation: blueprint.generation,
      unit: athlete.unit,
      blocks: [
        CanonicalGeneratedBlock(
          id: 'powerlifting-cycle-1',
          type: BlockType.cycle,
          role: BlockRole.classicCycle,
          sourceEdition: blueprint.sourceEdition,
          generation: blueprint.generation,
          source: blueprint.source,
          weeks: workWeeks,
        ),
        CanonicalGeneratedBlock(
          id: 'powerlifting-deload-1',
          type: BlockType.deload,
          role: BlockRole.deload,
          sourceEdition: blueprint.sourceEdition,
          generation: blueprint.generation,
          source: const RuleReference(
            document: '5/3/1 for Powerlifting',
            location: 'PDF pages 11 and 13',
          ),
          weeks: [deload.week],
        ),
      ],
      trainingMaxTimeline: decisions,
      awaitingTrainingMaxConfirmation: true,
    );
  }

  CanonicalGeneratedPlan _beyond(
    CanonicalGenerationBlueprint blueprint,
    CanonicalAthleteConfiguration athlete,
  ) {
    var cursor = athlete.startDate;
    var sessionNumber = 0;
    final firstCycle = <CanonicalProgrammingWeek>[];
    for (var index = 0; index < 3; index++) {
      final generated = _week(
        blueprint: blueprint,
        athlete: athlete,
        trainingMaxes: athlete.trainingMaxes,
        scheme: _workSchemes(blueprint.cycleModel)[index],
        programmingWeek: index + 1,
        cycleNumber: 1,
        cursor: cursor,
        firstSessionNumber: sessionNumber,
      );
      firstCycle.add(generated.week);
      cursor = generated.nextDate;
      sessionNumber += athlete.movementOrder.length;
    }
    final confirmed = athlete.confirmedBeyondTrainingMaxes;
    final firstCheckpoint = _decisions(
      athlete: athlete,
      previous: athlete.trainingMaxes,
      afterProgrammingWeek: 3,
      confirmed: confirmed,
      source: const RuleReference(
        document: 'Beyond 5/3/1',
        location: 'PDF page 11',
      ),
    );
    final blocks = <CanonicalGeneratedBlock>[
      CanonicalGeneratedBlock(
        id: 'beyond-cycle-1',
        type: BlockType.cycle,
        role: BlockRole.beyondCycle,
        sourceEdition: blueprint.sourceEdition,
        generation: blueprint.generation,
        source: blueprint.source,
        weeks: firstCycle,
      ),
    ];
    if (confirmed == null) {
      return CanonicalGeneratedPlan(
        schemaVersion: 5,
        blueprintId: blueprint.id,
        blueprintVersion: blueprint.version,
        sourceEdition: blueprint.sourceEdition,
        generation: blueprint.generation,
        unit: athlete.unit,
        blocks: blocks,
        trainingMaxTimeline: firstCheckpoint,
        awaitingTrainingMaxConfirmation: true,
      );
    }
    final secondCycle = <CanonicalProgrammingWeek>[];
    for (var index = 0; index < 3; index++) {
      final generated = _week(
        blueprint: blueprint,
        athlete: athlete,
        trainingMaxes: confirmed,
        scheme: _workSchemes(blueprint.cycleModel)[index],
        programmingWeek: index + 4,
        cycleNumber: 2,
        cursor: cursor,
        firstSessionNumber: sessionNumber,
      );
      secondCycle.add(generated.week);
      cursor = generated.nextDate;
      sessionNumber += athlete.movementOrder.length;
    }
    final deload = _week(
      blueprint: blueprint,
      athlete: athlete,
      trainingMaxes: confirmed,
      scheme: _deload,
      programmingWeek: 7,
      cycleNumber: 2,
      cursor: cursor,
      firstSessionNumber: sessionNumber,
    );
    blocks.addAll([
      CanonicalGeneratedBlock(
        id: 'beyond-cycle-2',
        type: BlockType.cycle,
        role: BlockRole.beyondCycle,
        sourceEdition: blueprint.sourceEdition,
        generation: blueprint.generation,
        source: blueprint.source,
        weeks: secondCycle,
      ),
      CanonicalGeneratedBlock(
        id: 'beyond-deload-1',
        type: BlockType.deload,
        role: BlockRole.deload,
        sourceEdition: blueprint.sourceEdition,
        generation: blueprint.generation,
        source: const RuleReference(
          document: 'Beyond 5/3/1',
          location: 'PDF page 12',
        ),
        weeks: [deload.week],
      ),
    ]);
    final finalCheckpoint = _decisions(
      athlete: athlete,
      previous: confirmed,
      afterProgrammingWeek: 7,
      confirmed: null,
      source: const RuleReference(
        document: 'Beyond 5/3/1',
        location: 'PDF page 12',
      ),
      sequenceOffset: firstCheckpoint.length,
    );
    return CanonicalGeneratedPlan(
      schemaVersion: 5,
      blueprintId: blueprint.id,
      blueprintVersion: blueprint.version,
      sourceEdition: blueprint.sourceEdition,
      generation: blueprint.generation,
      unit: athlete.unit,
      blocks: blocks,
      trainingMaxTimeline: [...firstCheckpoint, ...finalCheckpoint],
      awaitingTrainingMaxConfirmation: true,
    );
  }

  CanonicalGeneratedPlan _forever(
    CanonicalGenerationBlueprint blueprint,
    CanonicalAthleteConfiguration athlete,
  ) {
    var cursor = athlete.startDate;
    var sessionNumber = 0;
    var programmingWeek = 1;
    var currentTrainingMaxes = athlete.trainingMaxes;
    final blocks = <CanonicalGeneratedBlock>[];
    final timeline = <TrainingMaxTimelineDecision>[];

    CanonicalGeneratedBlock workCycle({
      required String id,
      required BlockRole role,
      required List<_WeekScheme> schemes,
      required int cycleNumber,
      required RuleReference source,
    }) {
      final weeks = <CanonicalProgrammingWeek>[];
      for (final scheme in schemes) {
        final generated = _week(
          blueprint: blueprint,
          athlete: athlete,
          trainingMaxes: currentTrainingMaxes,
          scheme: scheme,
          programmingWeek: programmingWeek,
          cycleNumber: cycleNumber,
          cursor: cursor,
          firstSessionNumber: sessionNumber,
        );
        weeks.add(generated.week);
        cursor = generated.nextDate;
        sessionNumber += athlete.movementOrder.length;
        programmingWeek++;
      }
      return CanonicalGeneratedBlock(
        id: id,
        type: BlockType.cycle,
        role: role,
        sourceEdition: blueprint.sourceEdition,
        generation: blueprint.generation,
        source: source,
        weeks: weeks,
      );
    }

    bool confirmCheckpoint(int afterWeek, RuleReference source) {
      final confirmed = athlete.confirmedTrainingMaxesByWeek[afterWeek];
      if (confirmed != null) {
        for (final movement in athlete.movementOrder) {
          final maximum =
              currentTrainingMaxes[movement]! +
              athlete.progressionIncrements[movement]!;
          final value = confirmed[movement];
          if (value == null || value <= 0 || value > maximum) {
            throw StateError(
              'Forever TM decisions may hold, reset, or use at most the source-defined increment.',
            );
          }
        }
      }
      timeline.addAll(
        _decisions(
          athlete: athlete,
          previous: currentTrainingMaxes,
          afterProgrammingWeek: afterWeek,
          confirmed: confirmed,
          source: source,
          sequenceOffset: timeline.length,
        ),
      );
      if (confirmed == null) return false;
      currentTrainingMaxes = confirmed;
      return true;
    }

    blocks.add(
      workCycle(
        id: 'forever-leader-1',
        role: BlockRole.leader,
        schemes: _foreverLeaderWeeks,
        cycleNumber: 1,
        source: _foreverOriginalFslSource,
      ),
    );
    if (!confirmCheckpoint(3, _foreverProgressionSource)) {
      return _foreverPlan(blueprint, athlete, blocks, timeline, true);
    }

    blocks.add(
      workCycle(
        id: 'forever-leader-2',
        role: BlockRole.leader,
        schemes: _foreverLeaderWeeks,
        cycleNumber: 2,
        source: _foreverOriginalFslSource,
      ),
    );
    if (!confirmCheckpoint(6, _foreverProgressionSource)) {
      return _foreverPlan(blueprint, athlete, blocks, timeline, true);
    }

    final deload = _week(
      blueprint: blueprint,
      athlete: athlete,
      trainingMaxes: currentTrainingMaxes,
      scheme: _foreverDeload,
      programmingWeek: 7,
      cycleNumber: 2,
      cursor: cursor,
      firstSessionNumber: sessionNumber,
    );
    blocks.add(
      CanonicalGeneratedBlock(
        id: 'forever-seventh-week-deload',
        type: BlockType.deload,
        role: BlockRole.seventhWeek,
        seventhWeekPurpose: SeventhWeekPurpose.deload,
        sourceEdition: blueprint.sourceEdition,
        generation: blueprint.generation,
        source: _foreverDeloadSource,
        weeks: [deload.week],
      ),
    );
    cursor = deload.nextDate;
    sessionNumber += athlete.movementOrder.length;
    programmingWeek = 8;

    blocks.add(
      workCycle(
        id: 'forever-anchor-1',
        role: BlockRole.anchor,
        schemes: _foreverAnchorWeeks,
        cycleNumber: 3,
        source: _foreverOriginalFslSource,
      ),
    );
    if (!confirmCheckpoint(10, _foreverProgressionSource)) {
      return _foreverPlan(blueprint, athlete, blocks, timeline, true);
    }

    final test = _week(
      blueprint: blueprint,
      athlete: athlete,
      trainingMaxes: currentTrainingMaxes,
      scheme: _foreverTrainingMaxTest,
      programmingWeek: 11,
      cycleNumber: 3,
      cursor: cursor,
      firstSessionNumber: sessionNumber,
    );
    blocks.add(
      CanonicalGeneratedBlock(
        id: 'forever-seventh-week-tm-test',
        type: BlockType.test,
        role: BlockRole.trainingMaxTest,
        seventhWeekPurpose: SeventhWeekPurpose.trainingMaxTest,
        sourceEdition: blueprint.sourceEdition,
        generation: blueprint.generation,
        source: _foreverTrainingMaxTestSource,
        weeks: [test.week],
      ),
    );
    timeline.addAll(
      _testDecisions(
        athlete: athlete,
        trainingMaxes: currentTrainingMaxes,
        sequenceOffset: timeline.length,
      ),
    );
    return _foreverPlan(blueprint, athlete, blocks, timeline, true);
  }

  CanonicalGeneratedPlan _foreverPlan(
    CanonicalGenerationBlueprint blueprint,
    CanonicalAthleteConfiguration athlete,
    List<CanonicalGeneratedBlock> blocks,
    List<TrainingMaxTimelineDecision> timeline,
    bool awaitingConfirmation,
  ) => CanonicalGeneratedPlan(
    schemaVersion: 5,
    blueprintId: blueprint.id,
    blueprintVersion: blueprint.version,
    sourceEdition: blueprint.sourceEdition,
    generation: blueprint.generation,
    unit: athlete.unit,
    blocks: blocks,
    trainingMaxTimeline: timeline,
    awaitingTrainingMaxConfirmation: awaitingConfirmation,
  );

  List<TrainingMaxTimelineDecision> _testDecisions({
    required CanonicalAthleteConfiguration athlete,
    required Map<MovementId, double> trainingMaxes,
    required int sequenceOffset,
  }) => [
    for (final movementEntry in athlete.movementOrder.indexed)
      TrainingMaxTimelineDecision(
        id: 'tm-test-week-11-${movementEntry.$2.value}',
        sequence: sequenceOffset + movementEntry.$1,
        movementId: movementEntry.$2,
        afterProgrammingWeek: 11,
        previousTrainingMax: trainingMaxes[movementEntry.$2]!,
        proposedTrainingMax: trainingMaxes[movementEntry.$2]!,
        state: TrainingMaxDecisionState.previewed,
        reason: 'TM Test result must confirm hold, progress, or reset.',
        source: _foreverTrainingMaxTestSource,
      ),
  ];

  ({CanonicalProgrammingWeek week, LocalDate nextDate}) _week({
    required CanonicalGenerationBlueprint blueprint,
    required CanonicalAthleteConfiguration athlete,
    required Map<MovementId, double> trainingMaxes,
    required _WeekScheme scheme,
    required int programmingWeek,
    required int cycleNumber,
    required LocalDate cursor,
    required int firstSessionNumber,
  }) {
    final sessions = <CanonicalGeneratedSession>[];
    var nextDate = cursor;
    for (final movementEntry in athlete.movementOrder.indexed) {
      final movement = movementEntry.$2;
      final date = _nextTrainingDate(nextDate, athlete.trainingWeekdays);
      final tm = trainingMaxes[movement]!;
      final sessionNumber = firstSessionNumber + movementEntry.$1 + 1;
      final prescriptions = <ActivityPrescription>[];
      for (final setEntry in scheme.sets.indexed) {
        final set = setEntry.$2;
        final unrounded = tm * set.percentage;
        prescriptions.add(
          ActivityPrescription(
            id: PrescriptionId('session-$sessionNumber:set-${setEntry.$1 + 1}'),
            position: setEntry.$1,
            activityId: ActivityId(movement.value),
            movementId: movement,
            percentage: set.percentage,
            target: PrescriptionTarget(
              type: PrescriptionTargetType.setsRepetitionsLoad,
              sets: 1,
              repetitionsPerSet: set.repetitions,
            ),
            kind:
                set.kind ??
                (set.performance
                    ? PrescriptionKind.performanceSet
                    : PrescriptionKind.mainWork),
            ruleId: set.ruleId,
            sourceEdition: blueprint.sourceEdition,
            generation: blueprint.generation,
            source: set.source,
            calculatedLoad: athlete.rounder.nearest(unrounded),
            unroundedLoad: unrounded,
            roundingIncrement: athlete.rounder.increment,
          ),
        );
      }
      sessions.add(
        CanonicalGeneratedSession(
          id: 'session-$sessionNumber',
          position: movementEntry.$1,
          date: date,
          movementId: movement,
          prescriptions: prescriptions,
        ),
      );
      nextDate = date.addDays(1);
    }
    return (
      week: CanonicalProgrammingWeek(
        number: programmingWeek,
        cycleNumber: cycleNumber,
        sessions: sessions,
      ),
      nextDate: nextDate,
    );
  }

  List<TrainingMaxTimelineDecision> _decisions({
    required CanonicalAthleteConfiguration athlete,
    required Map<MovementId, double> previous,
    required int afterProgrammingWeek,
    required Map<MovementId, double>? confirmed,
    required RuleReference source,
    int sequenceOffset = 0,
  }) => [
    for (final movementEntry in athlete.movementOrder.indexed)
      TrainingMaxTimelineDecision(
        id: 'tm-week-$afterProgrammingWeek-${movementEntry.$2.value}',
        sequence: sequenceOffset + movementEntry.$1,
        movementId: movementEntry.$2,
        afterProgrammingWeek: afterProgrammingWeek,
        previousTrainingMax: previous[movementEntry.$2]!,
        proposedTrainingMax:
            previous[movementEntry.$2]! +
            athlete.progressionIncrements[movementEntry.$2]!,
        confirmedTrainingMax: confirmed?[movementEntry.$2],
        state: confirmed == null
            ? TrainingMaxDecisionState.previewed
            : TrainingMaxDecisionState.confirmed,
        reason: 'Source-defined end-of-cycle training max progression.',
        source: source,
      ),
  ];

  void _validate(
    CanonicalGenerationBlueprint blueprint,
    CanonicalAthleteConfiguration athlete,
  ) {
    if (blueprint.version.value < 1 ||
        blueprint.source.location == null ||
        blueprint.source.location!.isEmpty) {
      throw StateError(
        'A versioned blueprint with an exact source is required.',
      );
    }
    if (athlete.movementOrder.length != 4 ||
        athlete.movementOrder.toSet().length != 4 ||
        !athlete.trainingMaxes.keys.toSet().containsAll(
          athlete.movementOrder,
        ) ||
        !athlete.progressionIncrements.keys.toSet().containsAll(
          athlete.movementOrder,
        ) ||
        athlete.trainingMaxes.values.any((value) => value <= 0) ||
        athlete.progressionIncrements.values.any((value) => value <= 0)) {
      throw StateError(
        'Four unique movements, TMs and increments are required.',
      );
    }
    if ((athlete.trainingWeekdays.length != 3 &&
            athlete.trainingWeekdays.length != 4) ||
        athlete.trainingWeekdays.toSet().length !=
            athlete.trainingWeekdays.length ||
        athlete.trainingWeekdays.any((day) => day < 1 || day > 7)) {
      throw StateError(
        'Only reviewed three- or four-day schedules are allowed.',
      );
    }
    final confirmed = athlete.confirmedBeyondTrainingMaxes;
    if (confirmed != null) {
      for (final movement in athlete.movementOrder) {
        final expected =
            athlete.trainingMaxes[movement]! +
            athlete.progressionIncrements[movement]!;
        if (confirmed[movement] != expected) {
          throw StateError(
            'Beyond cycle two requires the confirmed source-defined TM increase.',
          );
        }
      }
    }
    for (final checkpoint in athlete.confirmedTrainingMaxesByWeek.entries) {
      if (!{3, 6, 10}.contains(checkpoint.key)) {
        throw StateError(
          'Unsupported Forever TM checkpoint: ${checkpoint.key}.',
        );
      }
      for (final movement in athlete.movementOrder) {
        if (checkpoint.value[movement] == null ||
            checkpoint.value[movement]! <= 0) {
          throw StateError('Every confirmed Forever checkpoint needs all TMs.');
        }
      }
    }
    if (blueprint.generation == MethodGeneration.forever &&
        athlete.trainingWeekdays.length != 4) {
      throw StateError('This reviewed Forever preset requires four days.');
    }
  }

  LocalDate _nextTrainingDate(LocalDate from, List<int> weekdays) {
    var candidate = from;
    while (!weekdays.contains(candidate.weekday)) {
      candidate = candidate.addDays(1);
    }
    return candidate;
  }
}

class _SetScheme {
  const _SetScheme({
    required this.percentage,
    required this.repetitions,
    required this.performance,
    required this.ruleId,
    required this.source,
    this.kind,
  });
  final double percentage;
  final int repetitions;
  final bool performance;
  final String ruleId;
  final RuleReference source;
  final PrescriptionKind? kind;
}

class _WeekScheme {
  const _WeekScheme(this.sets);
  final List<_SetScheme> sets;
}

const _powerliftingSetsSource = RuleReference(
  document: '5/3/1 for Powerlifting',
  location: 'PDF page 11',
);
const _powerliftingDeloadSource = RuleReference(
  document: '5/3/1 for Powerlifting',
  location: 'PDF pages 11 and 13',
);
const _foreverOriginalFslSource = RuleReference(
  document: '5/3/1 Forever',
  location: 'PDF pages 180-182',
);
const _foreverDeloadSource = RuleReference(
  document: '5/3/1 Forever',
  location: 'PDF pages 31 and 33',
);
const _foreverTrainingMaxTestSource = RuleReference(
  document: '5/3/1 Forever',
  location: 'PDF pages 31-33',
);
const _foreverProgressionSource = RuleReference(
  document: '5/3/1 Forever',
  location: 'PDF pages 15 and 32-33',
);

const _standardWeeks = [
  _WeekScheme([
    _SetScheme(
      percentage: .65,
      repetitions: 5,
      performance: false,
      ruleId: 'POWERLIFTING-531-W1-S1',
      source: _powerliftingSetsSource,
    ),
    _SetScheme(
      percentage: .75,
      repetitions: 5,
      performance: false,
      ruleId: 'POWERLIFTING-531-W1-S2',
      source: _powerliftingSetsSource,
    ),
    _SetScheme(
      percentage: .85,
      repetitions: 5,
      performance: true,
      ruleId: 'POWERLIFTING-531-W1-S3',
      source: _powerliftingSetsSource,
    ),
  ]),
  _WeekScheme([
    _SetScheme(
      percentage: .70,
      repetitions: 3,
      performance: false,
      ruleId: 'POWERLIFTING-531-W2-S1',
      source: _powerliftingSetsSource,
    ),
    _SetScheme(
      percentage: .80,
      repetitions: 3,
      performance: false,
      ruleId: 'POWERLIFTING-531-W2-S2',
      source: _powerliftingSetsSource,
    ),
    _SetScheme(
      percentage: .90,
      repetitions: 3,
      performance: true,
      ruleId: 'POWERLIFTING-531-W2-S3',
      source: _powerliftingSetsSource,
    ),
  ]),
  _WeekScheme([
    _SetScheme(
      percentage: .75,
      repetitions: 5,
      performance: false,
      ruleId: 'POWERLIFTING-531-W3-S1',
      source: _powerliftingSetsSource,
    ),
    _SetScheme(
      percentage: .85,
      repetitions: 3,
      performance: false,
      ruleId: 'POWERLIFTING-531-W3-S2',
      source: _powerliftingSetsSource,
    ),
    _SetScheme(
      percentage: .95,
      repetitions: 1,
      performance: true,
      ruleId: 'POWERLIFTING-531-W3-S3',
      source: _powerliftingSetsSource,
    ),
  ]),
];

final _alternativeWeeks = [
  _WeekScheme([
    _SetScheme(
      percentage: .70,
      repetitions: 3,
      performance: false,
      ruleId: 'POWERLIFTING-351-W1-S1',
      source: _powerliftingSetsSource,
    ),
    _SetScheme(
      percentage: .80,
      repetitions: 3,
      performance: false,
      ruleId: 'POWERLIFTING-351-W1-S2',
      source: _powerliftingSetsSource,
    ),
    _SetScheme(
      percentage: .90,
      repetitions: 3,
      performance: true,
      ruleId: 'POWERLIFTING-351-W1-S3',
      source: _powerliftingSetsSource,
    ),
  ]),
  _WeekScheme([
    _SetScheme(
      percentage: .65,
      repetitions: 5,
      performance: false,
      ruleId: 'POWERLIFTING-351-W2-S1',
      source: _powerliftingSetsSource,
    ),
    _SetScheme(
      percentage: .75,
      repetitions: 5,
      performance: false,
      ruleId: 'POWERLIFTING-351-W2-S2',
      source: _powerliftingSetsSource,
    ),
    _SetScheme(
      percentage: .85,
      repetitions: 5,
      performance: false,
      ruleId: 'POWERLIFTING-351-W2-S3',
      source: _powerliftingSetsSource,
    ),
  ]),
  _standardWeeks[2],
];

const _deload = _WeekScheme([
  _SetScheme(
    percentage: .40,
    repetitions: 5,
    performance: false,
    ruleId: 'POWERLIFTING-DELOAD-S1',
    source: _powerliftingDeloadSource,
  ),
  _SetScheme(
    percentage: .50,
    repetitions: 5,
    performance: false,
    ruleId: 'POWERLIFTING-DELOAD-S2',
    source: _powerliftingDeloadSource,
  ),
  _SetScheme(
    percentage: .60,
    repetitions: 5,
    performance: false,
    ruleId: 'POWERLIFTING-DELOAD-S3',
    source: _powerliftingDeloadSource,
  ),
]);

final _foreverLeaderWeeks = [
  _foreverWorkWeek(
    week: 1,
    main: const [
      (percentage: .70, reps: 3),
      (percentage: .80, reps: 3),
      (percentage: .90, reps: 3),
    ],
    performance: true,
    fslPercentage: .70,
  ),
  _foreverWorkWeek(
    week: 2,
    main: const [
      (percentage: .65, reps: 5),
      (percentage: .75, reps: 5),
      (percentage: .85, reps: 5),
    ],
    performance: false,
    fslPercentage: .65,
  ),
  _foreverWorkWeek(
    week: 3,
    main: const [
      (percentage: .75, reps: 5),
      (percentage: .85, reps: 3),
      (percentage: .95, reps: 1),
    ],
    performance: true,
    fslPercentage: .75,
  ),
];

final _foreverAnchorWeeks = [
  _foreverAnchorWeek(1, const [
    (percentage: .65, reps: 5),
    (percentage: .75, reps: 5),
    (percentage: .85, reps: 5),
  ]),
  _foreverAnchorWeek(2, const [
    (percentage: .70, reps: 3),
    (percentage: .80, reps: 3),
    (percentage: .90, reps: 3),
  ]),
  _foreverAnchorWeek(3, const [
    (percentage: .75, reps: 5),
    (percentage: .85, reps: 3),
    (percentage: .95, reps: 1),
  ]),
];

_WeekScheme _foreverWorkWeek({
  required int week,
  required List<({double percentage, int reps})> main,
  required bool performance,
  required double fslPercentage,
}) => _WeekScheme([
  for (final set in main.indexed)
    _SetScheme(
      percentage: set.$2.percentage,
      repetitions: set.$2.reps,
      performance: performance && set.$1 == main.length - 1,
      ruleId: 'FOREVER-ORIGINAL-FSL-L-W$week-M${set.$1 + 1}',
      source: _foreverOriginalFslSource,
    ),
  for (var set = 1; set <= 5; set++)
    _SetScheme(
      percentage: fslPercentage,
      repetitions: 5,
      performance: false,
      kind: PrescriptionKind.supplemental,
      ruleId: 'FOREVER-ORIGINAL-FSL-L-W$week-FSL-$set',
      source: _foreverOriginalFslSource,
    ),
]);

_WeekScheme _foreverAnchorWeek(
  int week,
  List<({double percentage, int reps})> main,
) => _WeekScheme([
  for (final set in main.indexed)
    _SetScheme(
      percentage: set.$2.percentage,
      repetitions: set.$2.reps,
      performance: set.$1 == main.length - 1,
      ruleId: 'FOREVER-ORIGINAL-FSL-A-W$week-M${set.$1 + 1}',
      source: _foreverOriginalFslSource,
    ),
]);

const _foreverDeload = _WeekScheme([
  _SetScheme(
    percentage: .70,
    repetitions: 5,
    performance: false,
    ruleId: 'FOREVER-7W-DELOAD-70',
    source: _foreverDeloadSource,
  ),
  _SetScheme(
    percentage: .80,
    repetitions: 3,
    performance: false,
    ruleId: 'FOREVER-7W-DELOAD-80',
    source: _foreverDeloadSource,
  ),
  _SetScheme(
    percentage: .90,
    repetitions: 1,
    performance: false,
    ruleId: 'FOREVER-7W-DELOAD-90',
    source: _foreverDeloadSource,
  ),
  _SetScheme(
    percentage: 1,
    repetitions: 1,
    performance: false,
    ruleId: 'FOREVER-7W-DELOAD-TM',
    source: _foreverDeloadSource,
  ),
]);

const _foreverTrainingMaxTest = _WeekScheme([
  _SetScheme(
    percentage: .70,
    repetitions: 5,
    performance: false,
    kind: PrescriptionKind.trainingMaxTest,
    ruleId: 'FOREVER-7W-TMTEST-70',
    source: _foreverTrainingMaxTestSource,
  ),
  _SetScheme(
    percentage: .80,
    repetitions: 5,
    performance: false,
    kind: PrescriptionKind.trainingMaxTest,
    ruleId: 'FOREVER-7W-TMTEST-80',
    source: _foreverTrainingMaxTestSource,
  ),
  _SetScheme(
    percentage: .90,
    repetitions: 5,
    performance: false,
    kind: PrescriptionKind.trainingMaxTest,
    ruleId: 'FOREVER-7W-TMTEST-90',
    source: _foreverTrainingMaxTestSource,
  ),
  _SetScheme(
    percentage: 1,
    repetitions: 3,
    performance: false,
    kind: PrescriptionKind.trainingMaxTest,
    ruleId: 'FOREVER-7W-TMTEST-TM',
    source: _foreverTrainingMaxTestSource,
  ),
]);

List<_WeekScheme> _workSchemes(CanonicalCycleModel model) =>
    model == CanonicalCycleModel.standard531
    ? _standardWeeks
    : _alternativeWeeks;

Map<String, Object?> _prescriptionJson(ActivityPrescription prescription) => {
  'id': prescription.id.value,
  'position': prescription.position,
  'activityId': prescription.activityId.value,
  'movementId': prescription.movementId?.value,
  'percentage': prescription.percentage,
  'targetType': prescription.target.type.name,
  'sets': prescription.target.sets,
  'repetitionsPerSet': prescription.target.repetitionsPerSet,
  'kind': prescription.kind.name,
  'ruleId': prescription.ruleId,
  'sourceEdition': prescription.sourceEdition.name,
  'generation': prescription.generation.name,
  'source': _sourceJson(prescription.source),
  'calculatedLoad': prescription.calculatedLoad,
  'unroundedLoad': prescription.unroundedLoad,
  'roundingIncrement': prescription.roundingIncrement,
};

Map<String, Object?> _sourceJson(RuleReference source) => {
  'document': source.document,
  'location': source.location,
};
