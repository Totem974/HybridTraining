import 'dart:convert';

import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
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
                                      ruleProvenance: ruleJson(block.rule),
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

  final String id;
  final String athleteId;
  final String blueprintId;
  final int blueprintVersion;
  final Map<String, Object?> blueprintSnapshot;
  final List<Map<String, Object?>> ruleProvenance;
  final int macrocycle;
  final List<PlannedTrainingBlock> blocks;
  final DateTime createdAt;
}

class PlannedTrainingBlock {
  const PlannedTrainingBlock({
    required this.id,
    required this.sequence,
    required this.role,
    required this.templateId,
    required this.cycles,
  });
  final String id;
  final int sequence;
  final String role;
  final String templateId;
  final List<PlannedCycle> cycles;
}

class PlannedCycle {
  const PlannedCycle({
    required this.id,
    required this.sequence,
    required this.startsOn,
    required this.sessions,
  });
  final String id;
  final int sequence;
  final DateTime startsOn;
  final List<PlannedSession> sessions;
}

class PlannedSession {
  const PlannedSession({
    required this.id,
    required this.sequence,
    required this.scheduledFor,
    required this.blocks,
  });
  final String id;
  final int sequence;
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
  });
  final String id;
  final int sequence;
  final String kind;
  final String? movementId;
  final Map<String, Object?> ruleProvenance;
  final List<PlannedSetPrescription> prescriptions;
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

String canonicalJson(Object? value) => jsonEncode(_canonical(value));

Object? _canonical(Object? value) {
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List<Object?>) return value.map(_canonical).toList();
  return value;
}
