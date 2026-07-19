import 'dart:convert';

import '../../load_rounding.dart';
import '../../training_models.dart';
import '../program_domain.dart';
import 'generated_training_plan.dart';

class MacrocycleGenerationException implements Exception {
  const MacrocycleGenerationException(this.message);
  final String message;
  @override
  String toString() => 'MacrocycleGenerationException: $message';
}

class ReviewedRule {
  const ReviewedRule({
    required this.id,
    required this.status,
    required this.source,
  });
  final String id;
  final RuleStatus status;
  final RuleReference source;
}

class SetTemplate {
  const SetTemplate({
    required this.percentage,
    required this.repetitions,
    required this.kind,
    required this.rule,
    this.isPerformanceSet = false,
  });
  final double percentage;
  final int repetitions;
  final SetKind kind;
  final ReviewedRule rule;
  final bool isPerformanceSet;
}

class MovementTemplate {
  MovementTemplate({required this.movement, required List<SetTemplate> sets})
    : sets = List.unmodifiable(sets);
  final MainLift movement;
  final List<SetTemplate> sets;
}

class ActivityTemplate {
  const ActivityTemplate({
    required this.activityId,
    required this.target,
    required this.kind,
    required this.rule,
    this.sourceEdition = SourceEdition.forever,
    this.generation = MethodGeneration.forever,
  });
  final ActivityId activityId;
  final PrescriptionTarget target;
  final PrescriptionKind kind;
  final ReviewedRule rule;
  final SourceEdition sourceEdition;
  final MethodGeneration generation;
}

class SessionBlockTemplate {
  SessionBlockTemplate({
    required this.kind,
    required List<MovementTemplate> movements,
    List<String> instructions = const [],
    List<ActivityTemplate> activities = const [],
  }) : movements = List.unmodifiable(movements),
       instructions = List.unmodifiable(instructions),
       activities = List.unmodifiable(activities);
  final GeneratedSessionBlockKind kind;
  final List<MovementTemplate> movements;
  final List<String> instructions;
  final List<ActivityTemplate> activities;
}

class SessionTemplate {
  SessionTemplate({required List<SessionBlockTemplate> blocks})
    : blocks = List.unmodifiable(blocks);
  final List<SessionBlockTemplate> blocks;
}

class WeekTemplate {
  WeekTemplate({required List<SessionTemplate> sessions})
    : sessions = List.unmodifiable(sessions);
  final List<SessionTemplate> sessions;
}

class MacrocycleBlockDefinition {
  MacrocycleBlockDefinition({
    required this.templateId,
    required this.role,
    required this.cycleCount,
    required List<WeekTemplate> weeks,
    required this.rule,
    this.seventhWeekPurpose,
  }) : weeks = List.unmodifiable(weeks);
  final BlockTemplateId templateId;
  final BlockRole role;
  final SeventhWeekPurpose? seventhWeekPurpose;
  final int cycleCount;
  final List<WeekTemplate> weeks;
  final ReviewedRule rule;
}

class ProgramBlueprintSnapshot {
  ProgramBlueprintSnapshot({
    required this.blueprint,
    required List<MacrocycleBlockDefinition> blocks,
    required Map<String, Object?> canonicalJson,
    Map<String, Set<Object?>> allowedOptions = const {},
    Map<String, Set<String>> allowedAssistanceSelections = const {},
    Map<String, Set<String>> allowedConditioningSelections = const {},
  }) : blocks = List.unmodifiable(blocks),
       canonicalJson =
           _deepFreeze(jsonDecode(jsonEncode(canonicalJson)))
               as Map<String, Object?>,
       allowedOptions = Map.unmodifiable({
         for (final entry in allowedOptions.entries)
           entry.key: Set.unmodifiable(entry.value),
       }),
       allowedAssistanceSelections = Map.unmodifiable({
         for (final entry in allowedAssistanceSelections.entries)
           entry.key: Set.unmodifiable(entry.value),
       }),
       allowedConditioningSelections = Map.unmodifiable({
         for (final entry in allowedConditioningSelections.entries)
           entry.key: Set.unmodifiable(entry.value),
       });
  final ProgramBlueprint blueprint;
  final List<MacrocycleBlockDefinition> blocks;
  final Map<String, Object?> canonicalJson;
  final Map<String, Set<Object?>> allowedOptions;
  final Map<String, Set<String>> allowedAssistanceSelections;
  final Map<String, Set<String>> allowedConditioningSelections;
  String stableJson() => jsonEncode(_canonicalize(canonicalJson));

  static Object? _deepFreeze(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.unmodifiable({
        for (final entry in value.entries)
          entry.key as String: _deepFreeze(entry.value),
      });
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_deepFreeze));
    }
    return value;
  }

  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: _canonicalize(value[key])};
    }
    if (value is List) return value.map(_canonicalize).toList();
    return value;
  }
}

class AthletePlanConfiguration {
  AthletePlanConfiguration({
    required Map<MainLift, double> trainingMaxes,
    required this.unit,
    required List<int> trainingWeekdays,
    required this.startDate,
    required this.rounder,
    Map<String, Object?> options = const {},
    Map<String, String> assistanceSelections = const {},
    Map<String, String> conditioningSelections = const {},
    this.seed = 0,
  }) : trainingMaxes = Map.unmodifiable(trainingMaxes),
       trainingWeekdays = List.unmodifiable(trainingWeekdays),
       options = Map.unmodifiable(options),
       assistanceSelections = Map.unmodifiable(assistanceSelections),
       conditioningSelections = Map.unmodifiable(conditioningSelections);
  final Map<MainLift, double> trainingMaxes;
  final WeightUnit unit;
  final List<int> trainingWeekdays;
  final LocalDate startDate;
  final Map<String, Object?> options;
  final Map<String, String> assistanceSelections;
  final Map<String, String> conditioningSelections;
  final LoadRounder rounder;
  final int seed;
}

class ForeverMacrocycleGenerator {
  const ForeverMacrocycleGenerator();

  GeneratedTrainingPlan generate({
    required ProgramBlueprintSnapshot snapshot,
    required AthletePlanConfiguration athlete,
  }) {
    _validate(snapshot, athlete);
    final blocks = <GeneratedPlanBlock>[];
    var cursor = athlete.startDate;
    var sessionNumber = 0;
    for (
      var blockIndex = 0;
      blockIndex < snapshot.blocks.length;
      blockIndex++
    ) {
      final definition = snapshot.blocks[blockIndex];
      final cycles = <GeneratedCycle>[];
      for (
        var cycleIndex = 0;
        cycleIndex < definition.cycleCount;
        cycleIndex++
      ) {
        final weeks = <GeneratedProgrammingWeek>[];
        for (
          var weekIndex = 0;
          weekIndex < definition.weeks.length;
          weekIndex++
        ) {
          final sessions = <GeneratedSession>[];
          for (final template in definition.weeks[weekIndex].sessions) {
            cursor = _nextTrainingDate(
              cursor,
              athlete.trainingWeekdays,
              includeCurrent: true,
            );
            sessions.add(
              _session(
                template,
                athlete,
                cursor,
                'session-${sessionNumber + 1}',
              ),
            );
            sessionNumber++;
            cursor = cursor.addDays(1);
          }
          weeks.add(
            GeneratedProgrammingWeek(number: weekIndex + 1, sessions: sessions),
          );
        }
        cycles.add(GeneratedCycle(number: cycleIndex + 1, weeks: weeks));
      }
      blocks.add(
        GeneratedPlanBlock(
          id: 'block-${blockIndex + 1}-${definition.templateId.value}',
          role: definition.role,
          seventhWeekPurpose: definition.seventhWeekPurpose,
          rule: definition.rule.source,
          cycles: cycles,
        ),
      );
    }
    final transitions = <GeneratedTransition>[
      for (var index = 1; index < blocks.length; index++)
        GeneratedTransition(
          fromBlockId: blocks[index - 1].id,
          toBlockId: blocks[index].id,
          rule: snapshot.blocks[index].rule.source,
        ),
    ];
    final events = <PlannedTrainingEvent>[];
    for (final block in blocks) {
      if (block.role == BlockRole.leader || block.role == BlockRole.anchor) {
        for (final cycle in block.cycles) {
          events.add(
            PlannedTrainingEvent(
              kind: PlannedEventKind.trainingMaxProgression,
              afterBlockId: block.id,
              afterCycleNumber: cycle.number,
              rule: const RuleReference(
                document: 'TM-PROG-001',
                location: 'training-max-specification.md',
              ),
            ),
          );
        }
      }
      if (block.seventhWeekPurpose == SeventhWeekPurpose.trainingMaxTest) {
        events.add(
          PlannedTrainingEvent(
            kind: PlannedEventKind.trainingMaxTest,
            afterBlockId: block.id,
            rule: block.rule,
          ),
        );
      } else if (block.seventhWeekPurpose ==
          SeventhWeekPurpose.personalRecordTest) {
        events.add(
          PlannedTrainingEvent(
            kind: PlannedEventKind.prTest,
            afterBlockId: block.id,
            rule: block.rule,
          ),
        );
      }
    }
    return GeneratedTrainingPlan(
      schemaVersion: 1,
      blueprintId: snapshot.blueprint.id,
      blueprintVersion: snapshot.blueprint.version,
      blueprintSnapshot: snapshot.stableJson(),
      unit: athlete.unit,
      seed: athlete.seed,
      sourceEdition: snapshot.blueprint.sourceEdition,
      generation: snapshot.blueprint.generation,
      blocks: blocks,
      transitions: transitions,
      events: events,
    );
  }

  GeneratedSession _session(
    SessionTemplate template,
    AthletePlanConfiguration athlete,
    LocalDate date,
    String id,
  ) => GeneratedSession(
    id: id,
    date: date,
    blocks: [
      for (final block in template.blocks)
        GeneratedSessionBlock(
          kind: block.kind,
          instructions: block.instructions,
          prescriptions: [
            for (final movement in block.movements)
              for (final set in movement.sets)
                GeneratedPrescription(
                  movement: movement.movement,
                  setKind: set.kind,
                  percentage: set.percentage,
                  repetitions: set.repetitions,
                  trainingMax: athlete.trainingMaxes[movement.movement]!,
                  unroundedLoad:
                      athlete.trainingMaxes[movement.movement]! *
                      set.percentage,
                  load: athlete.rounder.nearest(
                    athlete.trainingMaxes[movement.movement]! * set.percentage,
                  ),
                  roundingIncrement: athlete.rounder.increment,
                  isPerformanceSet: set.isPerformanceSet,
                  rule: set.rule.source,
                ),
          ],
          activities: [
            for (final activityEntry in block.activities.indexed)
              ActivityPrescription(
                id: PrescriptionId(
                  '$id:${block.kind.name}:${activityEntry.$1 + 1}',
                ),
                position: activityEntry.$1,
                activityId: activityEntry.$2.activityId,
                target: activityEntry.$2.target,
                kind: activityEntry.$2.kind,
                ruleId: activityEntry.$2.rule.id,
                sourceEdition: activityEntry.$2.sourceEdition,
                generation: activityEntry.$2.generation,
                source: activityEntry.$2.rule.source,
              ),
          ],
        ),
    ],
  );

  void _validate(
    ProgramBlueprintSnapshot snapshot,
    AthletePlanConfiguration athlete,
  ) {
    if (snapshot.blueprint.version.value < 1 || snapshot.blocks.isEmpty) {
      throw const MacrocycleGenerationException('Blueprint incomplet.');
    }
    final policies = <VersionedPolicy?>[
      snapshot.blueprint.trainingMaxPolicy,
      snapshot.blueprint.mainWorkPolicy,
      snapshot.blueprint.supplementalPolicy,
      snapshot.blueprint.assistancePolicy,
      snapshot.blueprint.conditioningPolicy,
      snapshot.blueprint.athleticWorkPolicy,
      snapshot.blueprint.schedulePolicy,
      snapshot.blueprint.transitionPolicy,
    ];
    if (snapshot.blueprint.implementationStatus !=
            ImplementationStatus.available ||
        policies.whereType<VersionedPolicy>().any(
          (policy) => policy.ruleStatus != RuleStatus.verified,
        )) {
      throw const MacrocycleGenerationException(
        'Le blueprint contient une politique non revue ou inactive.',
      );
    }
    final ordered = [...snapshot.blueprint.blockSequence.blocks]
      ..sort((a, b) => a.order.compareTo(b.order));
    if (ordered.length != snapshot.blocks.length ||
        ordered.asMap().entries.any(
          (entry) =>
              entry.value.templateId != snapshot.blocks[entry.key].templateId,
        )) {
      throw const MacrocycleGenerationException(
        'Le snapshot exécutable ne correspond pas à la séquence du blueprint.',
      );
    }
    final templatesById = {
      for (final template in snapshot.blueprint.blockTemplates)
        template.id: template,
    };
    for (final block in snapshot.blocks) {
      final template = templatesById[block.templateId];
      if (template == null ||
          template.role != block.role ||
          template.seventhWeekPurpose != block.seventhWeekPurpose) {
        throw const MacrocycleGenerationException(
          'Le snapshot exécutable ne correspond pas aux blocs du blueprint.',
        );
      }
    }
    final allowedTransitions =
        snapshot.blueprint.transitionPolicy?.allowedTransitions ?? const {};
    for (var index = 1; index < snapshot.blocks.length; index++) {
      final transition = BlockTransition(
        snapshot.blocks[index - 1].role,
        snapshot.blocks[index].role,
      );
      if (!allowedTransitions.contains(transition)) {
        throw const MacrocycleGenerationException(
          'Transition non autorisée par le blueprint.',
        );
      }
    }
    final rules = <ReviewedRule>[
      for (final block in snapshot.blocks) ...[
        block.rule,
        for (final week in block.weeks)
          for (final session in week.sessions)
            for (final sessionBlock in session.blocks) ...[
              for (final movement in sessionBlock.movements)
                for (final set in movement.sets) set.rule,
              for (final activity in sessionBlock.activities) activity.rule,
            ],
      ],
    ];
    if (rules.any((rule) => rule.status != RuleStatus.verified)) {
      throw const MacrocycleGenerationException(
        'Une règle NEEDS_REVIEW ou non documentée bloque ce blueprint.',
      );
    }
    for (final option in athlete.options.entries) {
      if (!(snapshot.allowedOptions[option.key]?.contains(option.value) ??
          false)) {
        throw MacrocycleGenerationException(
          'Option non autorisée: ${option.key}.',
        );
      }
    }
    _validateSelections(
      athlete.assistanceSelections,
      snapshot.allowedAssistanceSelections,
      'assistance',
    );
    _validateSelections(
      athlete.conditioningSelections,
      snapshot.allowedConditioningSelections,
      'conditioning',
    );
    if (athlete.trainingWeekdays.isEmpty ||
        athlete.trainingWeekdays.any((day) => day < 1 || day > 7) ||
        athlete.trainingWeekdays.toSet().length !=
            athlete.trainingWeekdays.length) {
      throw const MacrocycleGenerationException('Planning invalide.');
    }
    final normalizedStart = DateTime(
      athlete.startDate.year,
      athlete.startDate.month,
      athlete.startDate.day,
    );
    if (normalizedStart.year != athlete.startDate.year ||
        normalizedStart.month != athlete.startDate.month ||
        normalizedStart.day != athlete.startDate.day) {
      throw const MacrocycleGenerationException('Date de départ invalide.');
    }
    if (!(snapshot.blueprint.schedulePolicy?.supportedFrequencies.contains(
          athlete.trainingWeekdays.length,
        ) ??
        false)) {
      throw const MacrocycleGenerationException(
        'Fréquence non autorisée par le blueprint.',
      );
    }
    for (final block in snapshot.blocks) {
      if (block.cycleCount < 1 || block.weeks.isEmpty) {
        throw const MacrocycleGenerationException(
          'Le nombre de cycles et les semaines viennent du blueprint.',
        );
      }
      if (block.role == BlockRole.seventhWeek &&
          block.seventhWeekPurpose == null) {
        throw const MacrocycleGenerationException('7th Week non typée.');
      }
      if (block.role != BlockRole.seventhWeek &&
          block.seventhWeekPurpose != null) {
        throw const MacrocycleGenerationException(
          'Un protocole 7th Week exige un bloc 7th Week.',
        );
      }
      for (final week in block.weeks) {
        for (final session in week.sessions) {
          for (final sessionBlock in session.blocks) {
            for (final movement in sessionBlock.movements) {
              if (!athlete.trainingMaxes.containsKey(movement.movement)) {
                throw MacrocycleGenerationException(
                  'Training Max manquant pour ${movement.movement.name}.',
                );
              }
            }
          }
        }
      }
    }
  }

  void _validateSelections(
    Map<String, String> selected,
    Map<String, Set<String>> allowed,
    String kind,
  ) {
    for (final selection in selected.entries) {
      if (!(allowed[selection.key]?.contains(selection.value) ?? false)) {
        throw MacrocycleGenerationException(
          'Choix $kind non autorisé: ${selection.key}.',
        );
      }
    }
  }

  LocalDate _nextTrainingDate(
    LocalDate from,
    List<int> weekdays, {
    required bool includeCurrent,
  }) {
    var candidate = includeCurrent ? from : from.addDays(1);
    while (!weekdays.contains(candidate.weekday)) {
      candidate = candidate.addDays(1);
    }
    return candidate;
  }
}
