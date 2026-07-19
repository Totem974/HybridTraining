import 'dart:convert';

import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/canonical_plan_generator.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';

class VersionedTrainingPlan {
  VersionedTrainingPlan({
    required this.id,
    required this.athleteId,
    required this.blueprintId,
    required this.blueprintVersion,
    required this.blueprintSnapshot,
    required this.ruleProvenance,
    required this.macrocycle,
    required this.blocks,
    required this.createdAt,
    this.sourceEdition,
    this.generation,
    this.trainingMaxTimeline = const [],
    this.plannedEvents = const [],
  }) {
    if (blueprintVersion <= 0 || macrocycle <= 0 || blocks.isEmpty) {
      throw ArgumentError('A versioned plan requires a version and blocks.');
    }
  }

  factory VersionedTrainingPlan.fromGenerated({
    required String id,
    required String athleteId,
    required int macrocycle,
    required DateTime createdAt,
    required GeneratedTrainingPlan generated,
  }) {
    Map<String, Object?> ruleJson(RuleReference rule) => {
      'document': rule.document,
      'location': rule.location,
    };

    final snapshot = jsonDecode(generated.blueprintSnapshot);
    if (snapshot is! Map<String, Object?>) {
      throw const FormatException('The blueprint snapshot must be an object.');
    }
    final provenance = <Map<String, Object?>>[
      for (final block in generated.blocks) ruleJson(block.rule),
      for (final transition in generated.transitions) ruleJson(transition.rule),
      for (final event in generated.events) ruleJson(event.rule),
    ];
    return VersionedTrainingPlan(
      id: id,
      athleteId: athleteId,
      blueprintId: generated.blueprintId.value,
      blueprintVersion: generated.blueprintVersion.value,
      blueprintSnapshot: snapshot,
      ruleProvenance: provenance,
      macrocycle: macrocycle,
      createdAt: createdAt,
      blocks: [
        for (
          var blockIndex = 0;
          blockIndex < generated.blocks.length;
          blockIndex++
        )
          () {
            final block = generated.blocks[blockIndex];
            final blockId = '$id-${block.id}';
            return PlannedTrainingBlock(
              id: blockId,
              sequence: blockIndex,
              role: block.role.name,
              templateId: block.id,
              cycles: [
                for (
                  var cycleIndex = 0;
                  cycleIndex < block.cycles.length;
                  cycleIndex++
                )
                  () {
                    final cycle = block.cycles[cycleIndex];
                    final sessions = cycle.weeks
                        .expand((week) => week.sessions)
                        .toList(growable: false);
                    if (sessions.isEmpty) {
                      throw ArgumentError(
                        'A generated cycle requires sessions.',
                      );
                    }
                    return PlannedCycle(
                      id: '$blockId-cycle-${cycle.number}',
                      sequence: cycleIndex,
                      startsOn: DateTime.parse(sessions.first.date.iso8601),
                      sessions: [
                        for (
                          var sessionIndex = 0;
                          sessionIndex < sessions.length;
                          sessionIndex++
                        )
                          () {
                            final session = sessions[sessionIndex];
                            final sessionId = '$id-${session.id}';
                            return PlannedSession(
                              id: sessionId,
                              sequence: sessionIndex,
                              scheduledFor: DateTime.parse(
                                session.date.iso8601,
                              ),
                              blocks: [
                                for (
                                  var sessionBlockIndex = 0;
                                  sessionBlockIndex < session.blocks.length;
                                  sessionBlockIndex++
                                )
                                  () {
                                    final sessionBlock =
                                        session.blocks[sessionBlockIndex];
                                    final sessionBlockId =
                                        '$sessionId-block-$sessionBlockIndex';
                                    final movement =
                                        sessionBlock.prescriptions.isEmpty
                                        ? null
                                        : sessionBlock
                                              .prescriptions
                                              .first
                                              .movement
                                              .name;
                                    return PlannedSessionBlock(
                                      id: sessionBlockId,
                                      sequence: sessionBlockIndex,
                                      kind: sessionBlock.kind.name,
                                      movementId: movement,
                                      ruleProvenance: {
                                        ...ruleJson(block.rule),
                                        if (sessionBlock
                                            .instructions
                                            .isNotEmpty)
                                          'instructions':
                                              sessionBlock.instructions,
                                      },
                                      prescriptions: [
                                        for (
                                          var setIndex = 0;
                                          setIndex <
                                              sessionBlock.prescriptions.length;
                                          setIndex++
                                        )
                                          () {
                                            final prescription = sessionBlock
                                                .prescriptions[setIndex];
                                            return PlannedSetPrescription(
                                              id: '$sessionBlockId-set-$setIndex',
                                              sequence: setIndex,
                                              trainingMax:
                                                  prescription.trainingMax,
                                              percentage:
                                                  prescription.percentage,
                                              unroundedLoad:
                                                  prescription.unroundedLoad,
                                              roundingIncrement: prescription
                                                  .roundingIncrement,
                                              prescribedLoad: prescription.load,
                                              prescribedReps:
                                                  prescription.repetitions,
                                              details: prescription.toJson(),
                                              ruleProvenance: ruleJson(
                                                prescription.rule,
                                              ),
                                            );
                                          }(),
                                      ],
                                    );
                                  }(),
                              ],
                            );
                          }(),
                      ],
                    );
                  }(),
              ],
            );
          }(),
      ],
    );
  }

  factory VersionedTrainingPlan.fromCanonical({
    required String id,
    required String athleteId,
    required int macrocycle,
    required DateTime createdAt,
    required CanonicalGeneratedPlan generated,
  }) {
    Map<String, Object?> sourceJson(RuleReference source) => {
      'document': source.document,
      'location': source.location,
    };
    return VersionedTrainingPlan(
      id: id,
      athleteId: athleteId,
      blueprintId: generated.blueprintId.value,
      blueprintVersion: generated.blueprintVersion.value,
      blueprintSnapshot: generated.toJson(),
      ruleProvenance: [
        for (final block in generated.blocks) sourceJson(block.source),
        for (final decision in generated.trainingMaxTimeline)
          sourceJson(decision.source),
      ],
      macrocycle: macrocycle,
      createdAt: createdAt,
      sourceEdition: generated.sourceEdition,
      generation: generated.generation,
      trainingMaxTimeline: [
        for (final decision in generated.trainingMaxTimeline) decision.toJson(),
      ],
      plannedEvents: [
        for (final decision in generated.trainingMaxTimeline)
          {
            'id': '$id-event-${decision.sequence}',
            'sequence': decision.sequence,
            'eventType': 'trainingMaxDecision',
            'programmingWeekNumber': decision.afterProgrammingWeek,
            'payload': decision.toJson(),
            'ruleId': 'TM-${decision.afterProgrammingWeek}',
            'source': sourceJson(decision.source),
          },
      ],
      blocks: [
        for (final blockEntry in generated.blocks.indexed)
          _canonicalBlock(id, blockEntry.$1, blockEntry.$2, sourceJson),
      ],
    );
  }

  final String id;
  final String athleteId;
  final String blueprintId;
  final int blueprintVersion;
  final Map<String, Object?> blueprintSnapshot;
  final List<Map<String, Object?>> ruleProvenance;
  final int macrocycle;
  final List<PlannedTrainingBlock> blocks;
  final DateTime createdAt;
  final SourceEdition? sourceEdition;
  final MethodGeneration? generation;
  final List<Map<String, Object?>> trainingMaxTimeline;
  final List<Map<String, Object?>> plannedEvents;
}

class PlannedTrainingBlock {
  const PlannedTrainingBlock({
    required this.id,
    required this.sequence,
    required this.role,
    required this.templateId,
    required this.cycles,
    this.type = 'cycle',
    this.seventhWeekPurpose,
  });
  final String id;
  final int sequence;
  final String role;
  final String type;
  final String? seventhWeekPurpose;
  final String templateId;
  final List<PlannedCycle> cycles;
}

class PlannedCycle {
  const PlannedCycle({
    required this.id,
    required this.sequence,
    required this.startsOn,
    required this.sessions,
    this.programmingCycleNumber,
  });
  final String id;
  final int sequence;
  final int? programmingCycleNumber;
  final DateTime startsOn;
  final List<PlannedSession> sessions;
}

class PlannedSession {
  const PlannedSession({
    required this.id,
    required this.sequence,
    required this.scheduledFor,
    required this.blocks,
    this.programmingWeekNumber,
    this.position,
  });
  final String id;
  final int sequence;
  final int? programmingWeekNumber;
  final int? position;
  final DateTime scheduledFor;
  final List<PlannedSessionBlock> blocks;
}

class PlannedSessionBlock {
  const PlannedSessionBlock({
    required this.id,
    required this.sequence,
    required this.kind,
    required this.movementId,
    required this.ruleProvenance,
    required this.prescriptions,
    this.activities = const [],
  });
  final String id;
  final int sequence;
  final String kind;
  final String? movementId;
  final Map<String, Object?> ruleProvenance;
  final List<PlannedSetPrescription> prescriptions;
  final List<PlannedActivityPrescription> activities;
}

class PlannedActivityPrescription {
  const PlannedActivityPrescription({
    required this.id,
    required this.sequence,
    required this.movementOrActivityId,
    required this.targetType,
    required this.target,
    required this.kind,
    required this.ruleId,
    required this.sourceEdition,
    required this.generation,
    required this.source,
    this.calculatedLoad,
    this.unroundedLoad,
    this.roundingIncrement,
    this.percentage,
  });
  final String id;
  final int sequence;
  final String movementOrActivityId;
  final String targetType;
  final Map<String, Object?> target;
  final String kind;
  final String ruleId;
  final String sourceEdition;
  final String generation;
  final Map<String, Object?> source;
  final double? calculatedLoad;
  final double? unroundedLoad;
  final double? roundingIncrement;
  final double? percentage;
}

class PlannedSetPrescription {
  const PlannedSetPrescription({
    required this.id,
    required this.sequence,
    required this.trainingMax,
    required this.percentage,
    required this.unroundedLoad,
    required this.roundingIncrement,
    required this.prescribedLoad,
    required this.prescribedReps,
    required this.details,
    required this.ruleProvenance,
  });
  final String id;
  final int sequence;
  final double trainingMax;
  final double? percentage;
  final double unroundedLoad;
  final double roundingIncrement;
  final double prescribedLoad;
  final int prescribedReps;
  final Map<String, Object?> details;
  final Map<String, Object?> ruleProvenance;
}

PlannedTrainingBlock _canonicalBlock(
  String planId,
  int blockSequence,
  CanonicalGeneratedBlock block,
  Map<String, Object?> Function(RuleReference) sourceJson,
) {
  final blockId = '$planId-${block.id}';
  final cycleNumbers =
      block.weeks.map((week) => week.cycleNumber).toSet().toList()..sort();
  return PlannedTrainingBlock(
    id: blockId,
    sequence: blockSequence,
    role: block.role.name,
    type: block.type.name,
    templateId: block.id,
    cycles: [
      for (final cycleEntry in cycleNumbers.indexed)
        () {
          final cycleNumber = cycleEntry.$2;
          final weeks = block.weeks
              .where((week) => week.cycleNumber == cycleNumber)
              .toList(growable: false);
          final sessions = [
            for (final week in weeks)
              for (final session in week.sessions)
                (week: week, session: session),
          ];
          return PlannedCycle(
            id: '$blockId-cycle-$cycleNumber',
            sequence: cycleEntry.$1,
            programmingCycleNumber: cycleNumber,
            startsOn: DateTime.parse(sessions.first.session.date.iso8601),
            sessions: [
              for (final sessionEntry in sessions.indexed)
                () {
                  final week = sessionEntry.$2.week;
                  final session = sessionEntry.$2.session;
                  final sessionId = '$planId-${session.id}';
                  return PlannedSession(
                    id: sessionId,
                    sequence: sessionEntry.$1,
                    programmingWeekNumber: week.number,
                    position: session.position,
                    scheduledFor: DateTime.parse(session.date.iso8601),
                    blocks: [
                      PlannedSessionBlock(
                        id: '$sessionId-block-0',
                        sequence: 0,
                        kind: 'mainWork',
                        movementId: session.movementId.value,
                        ruleProvenance: sourceJson(block.source),
                        prescriptions: const [],
                        activities: [
                          for (final prescription in session.prescriptions)
                            PlannedActivityPrescription(
                              id: '$planId-${prescription.id.value}',
                              sequence: prescription.position,
                              movementOrActivityId:
                                  prescription.movementId?.value ??
                                  prescription.activityId.value,
                              targetType: prescription.target.type.name,
                              target: {
                                'sets': prescription.target.sets,
                                'repetitionsPerSet':
                                    prescription.target.repetitionsPerSet,
                                'totalRepetitions':
                                    prescription.target.totalRepetitions,
                                'seconds': prescription.target.seconds,
                                'meters': prescription.target.meters,
                                'rounds': prescription.target.rounds,
                                'qualitativeGoal':
                                    prescription.target.qualitativeGoal,
                                'percentage': prescription.percentage,
                              },
                              kind: prescription.kind.name,
                              ruleId: prescription.ruleId,
                              sourceEdition: prescription.sourceEdition.name,
                              generation: prescription.generation.name,
                              source: sourceJson(prescription.source),
                              calculatedLoad: prescription.calculatedLoad,
                              unroundedLoad: prescription.unroundedLoad,
                              roundingIncrement: prescription.roundingIncrement,
                              percentage: prescription.percentage,
                            ),
                        ],
                      ),
                    ],
                  );
                }(),
            ],
          );
        }(),
    ],
  );
}

String canonicalJson(Object? value) => jsonEncode(_canonical(value));

Object? _canonical(Object? value) {
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List<Object?>) return value.map(_canonical).toList();
  return value;
}
