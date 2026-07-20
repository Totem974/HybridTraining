import 'dart:convert';

import 'package:hybrid_training/features/poc_531/domain/calculator/calculator.dart'
    as calc;
import 'package:hybrid_training/features/poc_531/domain/core.dart' as core;
import 'package:hybrid_training/features/poc_531/domain/forever_calculator/forever_calculator.dart'
    as forever;
import 'package:hybrid_training/features/poc_531/application/poc_531_configuration_codec.dart';
import 'package:hybrid_training/features/poc_531/domain/planning/planning.dart'
    as planning;
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_page.dart';

/// Translation-only adapter. Every prescription and compatibility decision is
/// delegated to one of the two pure calculator engines.
class DomainPoc531GeneratorCore implements Poc531GeneratorCore {
  const DomainPoc531GeneratorCore();

  @override
  GeneratorOptions get options => GeneratorOptions(
    classicTemplates: [
      for (final template in calc.calculatorTemplates)
        if (template.id != calc.CalculatorTemplateId.standard)
          CalculatorTemplateChoice(
            id: template.id.name,
            name: template.label,
            allowedDays: template.allowedDays.toList()..sort(),
            variants: [
              for (final variant in template.variants)
                CalculatorVariantChoice(
                  id: variant.id,
                  name: variant.label,
                  executable: variant.executable,
                  allowedDays: variant.allowedDays.toList()..sort(),
                  blockedReason: variant.blockedReason,
                ),
            ],
          ),
    ],
    foreverTemplates: [
      for (final template in forever.listForeverCalculatorTemplates())
        ForeverTemplateChoice(
          id: template.id,
          name: template.name,
          variant: template.variant,
          executable: template.selectable,
          days: template.daysPerWeek,
          blockedReason: template.unavailableReason,
          planKind: template.id == 'FV-141'
              ? 'standaloneProgram'
              : 'macrocycle',
          sequence: [
            for (final block in template.sequence)
              '${_blockLabel(block.kind)} · semaines ${block.startWeek}–${block.startWeek + block.durationWeeks - 1}',
          ],
          timeline: _timeline(template),
        ),
    ],
  );

  static String _blockLabel(forever.ForeverBlockKind kind) => switch (kind) {
    forever.ForeverBlockKind.leader => 'Leader',
    forever.ForeverBlockKind.anchor => 'Anchor',
    forever.ForeverBlockKind.seventhWeekDeload => '7th Week Deload',
    forever.ForeverBlockKind.seventhWeekTmTest => '7th Week TM Test',
  };

  static List<ForeverTimelineNodeChoice> _timeline(
    forever.ForeverCalculatorTemplate template,
  ) {
    if (!template.selectable) return const [];
    if (template.id == 'FV-141') {
      return const [
        ForeverTimelineNodeChoice(
          id: 'C1',
          title: 'Beginner Prep School',
          details: ['Programme autonome', '3 jours', '3 semaines', 'Current'],
          protocol: false,
        ),
      ];
    }
    final profile = planning.CommonTrainingProfile(
      trainingDaysPerWeek: 4,
      trainingWeekdays: [1, 2, 4, 5],
      trainingMaxes: {'press': 1},
      progressionIncrements: {'press': 1},
    );
    final configuration = planning.ForeverPlanningConfiguration(
      profile: profile,
      kind: planning.ForeverPlanKind.macrocycle,
      series: planning.createForeverOriginalFslSeries(profile: profile),
    );
    return [
      for (final node
          in const planning.ForeverSequenceCompiler().compileStructure(
            configuration,
          ))
        switch (node) {
          planning.ForeverCycleNode cycle => ForeverTimelineNodeChoice(
            id: cycle.nodeId,
            title: cycle.role == planning.CycleRole.leader
                ? 'Leader · Original + FSL'
                : 'Anchor · Original 5/3/1',
            details: [
              'Current',
              '4 jours',
              'TM 85–90%',
              cycle.role == planning.CycleRole.leader
                  ? 'Main work 3/5/1 · FSL 5×5'
                  : 'Main work 5/3/1',
              '3 semaines',
              'Source revue',
            ],
            protocol: false,
          ),
          planning.ForeverProtocolNode protocol => ForeverTimelineNodeChoice(
            id: protocol.nodeId,
            title:
                protocol.purpose == planning.ProtocolPurpose.seventhWeekDeload
                ? '7th Week Deload'
                : '7th Week Training Max Test',
            details: [
              '1 semaine',
              'Automatique',
              'Inséré par la recette forever-2l1a',
            ],
            protocol: true,
            autoInserted: protocol.autoInserted,
          ),
        },
    ];
  }

  @override
  Future<List<GeneratorWarning>> validate(Map<String, Object?> value) async {
    if (value['mode'] == 'forever') {
      final request = _foreverRequest(value);
      if (request == null) return const [];
      return [
        for (final configuration in request.configurations)
          for (final issue in forever.validateForeverCalculatorConfiguration(
            configuration,
          ))
            GeneratorWarning(issue.message, isError: issue.blocking),
      ];
    }
    final configuration = _classicConfiguration(value);
    if (configuration == null) return const [];
    return [
      for (final issue in const calc.ClassicCalculatorEngine().validate(
        configuration,
      ))
        GeneratorWarning(issue.message, isError: issue.blocking),
    ];
  }

  @override
  Future<GeneratorResult> generate(Map<String, Object?> value) async {
    if (value['mode'] == 'forever') {
      final request = _foreverRequest(value);
      if (request == null) {
        throw const FormatException('Configuration incomplète.');
      }
      final plans = [
        for (var index = 0; index < request.configurations.length; index++)
          request.compiledSequences[index] == null
              ? forever.generateForeverCalculatorProgram(
                  request.configurations[index],
                )
              : core.generateProgram(
                  request.configurations[index],
                  foreverSequence: request.compiledSequences[index],
                ),
      ];
      if (plans.isEmpty) {
        return GeneratorResult(
          title: 'Série Forever',
          blocks: const [],
          exportJson: jsonEncode({
            'schemaVersion': 4,
            'seriesId': request.seriesId,
            'terminated': request.terminated,
            'macrocycles': request.exportMacrocycles(plans),
          }),
        );
      }
      final definition = core.getProgramDefinition(plans.first.programId)!;
      return GeneratorResult(
        title: definition.name,
        blocks: [
          for (var index = 0; index < plans.length; index++)
            for (final block in _payloadToBlocks(plans[index].payload))
              PlanBlockView(
                request.isSeries
                    ? '${request.macrocycles[index].instanceId} · ${block.name}'
                    : block.name,
                block.weeks,
              ),
        ],
        explanation: core.explainGeneratedProgram(plans.first),
        sources: [
          for (final source in plans.first.sources)
            '${source.title} · ${source.pages}',
        ],
        warnings: [
          for (final warning in plans.expand((plan) => plan.warnings).toSet())
            GeneratorWarning(warning),
        ],
        exportJson: request.isSeries
            ? jsonEncode({
                'schemaVersion': 4,
                'seriesId': request.seriesId,
                'terminated': request.terminated,
                'macrocycles': request.exportMacrocycles(plans),
              })
            : forever.serializeForeverCalculatorProgram(plans.single),
      );
    }
    final configuration = _classicConfiguration(value);
    if (configuration == null) {
      throw const FormatException('Configuration incomplète.');
    }
    final program = calc.ClassicCalculatorEngine(
      roundingIncrement: value['unit'] == 'lb' ? 5 : 2.5,
    ).generate(configuration);
    return GeneratorResult(
      title: calc.calculatorTemplate(configuration.template).label,
      blocks: [
        PlanBlockView('Cycle', [
          for (final week in program.weeks) _classicWeek(week),
        ]),
      ],
      sources: [
        for (final source in program.sources)
          '${source.title} · ${source.pages}',
      ],
      warnings: [
        for (final warning in program.warnings) GeneratorWarning(warning),
      ],
      exportJson: jsonEncode(program.toJson()),
    );
  }

  static PlanWeekView _classicWeek(calc.CalculatorWeek week) => PlanWeekView(
    week.deload ? 'Semaine ${week.number} · Deload' : 'Semaine ${week.number}',
    [
      for (final session in week.sessions)
        PlanSessionView(_liftLabel(session.lift), [
          for (final set in session.sets)
            '${set.kind == 'supplemental'
                ? 'SUP · '
                : set.kind == 'assistance'
                ? 'ASSIST · '
                : set.kind == 'joker'
                ? 'JOKER · optional · '
                : ''}${set.exercise == null || set.kind == 'joker' ? '' : '${set.exercise} · '}${set.kind == 'joker' ? '' : '${set.repetitions}${set.amrap ? '+' : ''} reps'}${set.percent > 0 ? ' · ${set.weight.toStringAsFixed(set.weight % 1 == 0 ? 0 : 1)} · ${set.percent}%' : ''}',
        ]),
    ],
  );

  static String _liftLabel(String id) => switch (id) {
    'press' => 'Overhead Press',
    'bench' => 'Bench Press',
    'squat' => 'Squat',
    'deadlift' => 'Deadlift',
    _ => id,
  };

  calc.CalculatorConfiguration? _classicConfiguration(
    Map<String, Object?> value,
  ) {
    final templateName = value['templateId'] as String?;
    final variant = value['variantId'] as String?;
    final maxes = _trainingMaxes(value);
    if (templateName == null || variant == null || maxes == null) return null;
    return calc.CalculatorConfiguration(
      template: calc.CalculatorTemplateId.values.byName(templateName),
      variantId: variant,
      trainingMaxes: maxes,
      daysPerWeek: value['days'] as int? ?? 4,
      unit: value['unit'] as String? ?? 'kg',
      supplementalPercent: value['supplementalPercent'] as int? ?? 50,
      warmupBaseUpper: (value['warmupBaseUpper'] as num?)?.toDouble() ?? 95,
      warmupBaseLower: (value['warmupBaseLower'] as num?)?.toDouble() ?? 135,
      bbbPercents:
          value['bbbUseSameRatio'] == false && value['bbbRatiosByLift'] is Map
          ? (value['bbbRatiosByLift'] as Map).map(
              (key, ratio) => MapEntry('$key', ratio as int),
            )
          : const {},
      bodyweightTotalReps: value['bodyweightTotalReps'] as int? ?? 75,
      bodyweightSetCount: value['bodyweightSetCount'] as int? ?? 5,
      fslSetCount: value['fslSetCount'] as int? ?? 3,
      fslRepCount: value['fslRepetitions'] as int? ?? 5,
      gvtPercent: value['gvtRatio'] as int? ?? 30,
      gvtLessBoring: value['gvtAlternateExercise'] as bool? ?? false,
      gvtPercents:
          value['gvtUseSameRatio'] == false && value['gvtRatiosByLift'] is Map
          ? (value['gvtRatiosByLift'] as Map).map(
              (key, ratio) => MapEntry('$key', ratio as int),
            )
          : const {},
      beginnerIntermediate: value['beginnerIntermediate'] as bool? ?? false,
      simplestStrengthTrainingMaxes: _simplestStrengthTrainingMaxes(value),
      liftOrder:
          (value['liftOrder'] as List?)?.cast<String>() ??
          const ['press', 'deadlift', 'bench', 'squat'],
      options: calc.CalculatorOptions(
        order: value['weekOrder'] == '351'
            ? calc.MainWorkOrder.threeFiveOne
            : calc.MainWorkOrder.fiveThreeOne,
        warmup: calc.WarmupOption.values.byName(
          value['warmup'] as String? ?? 'none',
        ),
        jokersEnabled: value['jokersEnabled'] as bool? ?? false,
        jokerIncrementPercent: value['jokerIncrement'] as int? ?? 5,
        jokerCapPercent: value['jokerCap'] as int? ?? 10,
        deload: calc.DeloadOption.values.byName(
          value['deload'] as String? ?? 'deload1',
        ),
        skipWarmupDuringDeload: value['skipDeloadWarmup'] as bool? ?? false,
        bastardWorkOrder: value['bastardWorkOrder'] as bool? ?? false,
      ),
    );
  }

  Map<String, double> _simplestStrengthTrainingMaxes(
    Map<String, Object?> value,
  ) {
    final rawWeights = value['simplestStrengthLifts'];
    if (rawWeights is! Map) return const {};
    final rawRepetitions = value['simplestStrengthRepetitions'];
    final directTm = const {
      'tm',
      'trainingMax',
    }.contains(value['simplestStrengthInputMode']);
    final ratio =
        ((value['simplestStrengthTrainingMaxRatio'] as num?)?.toDouble() ??
            90) /
        100;
    const liftKeys = {
      'Close Grip Bench': 'press',
      'Incline Press': 'bench',
      'Front Squat': 'squat',
      'Straight Leg Deadlift': 'deadlift',
    };
    final result = <String, double>{};
    for (final entry in liftKeys.entries) {
      final weight = rawWeights[entry.key];
      if (weight is! num || weight <= 0) continue;
      if (directTm) {
        result[entry.value] = weight.toDouble();
        continue;
      }
      final reps = rawRepetitions is Map
          ? rawRepetitions[entry.key] as int? ?? 1
          : 1;
      final oneRepMax = reps <= 1
          ? weight.toDouble()
          : core.calculateEstimatedOneRepMax(
              core.RepMaxInput(weight: weight.toDouble(), repetitions: reps),
            );
      result[entry.value] = oneRepMax * ratio;
    }
    return result;
  }

  _ForeverGenerationRequest? _foreverRequest(Map<String, Object?> value) {
    if (value['schemaVersion'] != 4) {
      final configuration = _foreverConfiguration(value);
      return configuration == null
          ? null
          : _ForeverGenerationRequest.single(configuration);
    }
    final decoded = const Poc531ConfigurationCodec().decodeMap(value);
    final foreverValue = decoded.forever!;
    final standalone = foreverValue['standaloneProgramId'];
    if (standalone is String) {
      final configuration = _foreverConfiguration({
        ...decoded.common,
        'foreverTemplateId':
            standalone == Poc531ConfigurationCodec.beginnerPrepSchoolId
            ? 'FV-141'
            : standalone,
      });
      return configuration == null
          ? null
          : _ForeverGenerationRequest.single(configuration);
    }
    final seriesValue = foreverValue['series'];
    if (seriesValue is! Map) return null;
    final rawMacrocycles = seriesValue['macrocycles'];
    if (rawMacrocycles is! List || rawMacrocycles.isEmpty) return null;
    final macrocycles = <_GeneratedMacrocycle>[];
    final preservedMacrocycles = <Map<String, Object?>>[];
    final configurations = <core.ProgramConfiguration>[];
    final compiledSequences = <planning.CompiledForeverSequence?>[];
    final sourceOrder = <String>[];
    final domainMacrocycles = <planning.ForeverMacrocycle>[];
    final futureDomainMacrocycles = <planning.ForeverMacrocycle>[];
    final historicalInstanceIds = <String>{};
    final allIds = <String>{};
    for (final raw in rawMacrocycles) {
      if (raw is! Map) throw const FormatException('Macrocycle invalide.');
      final macrocycle = {
        for (final entry in raw.entries) '${entry.key}': entry.value,
      };
      final instanceId = macrocycle['instanceId'];
      if (instanceId is! String ||
          instanceId.trim().isEmpty ||
          !allIds.add(instanceId)) {
        throw const FormatException('Identifiant de macrocycle invalide.');
      }
      final status = '${macrocycle['status']}';
      sourceOrder.add(instanceId);
      final domainMacrocycle = _domainMacrocycle(macrocycle);
      domainMacrocycles.add(domainMacrocycle);
      if (status == 'completed' || status == 'cancelled') {
        // Historical macrocycles are intentionally absent from generation:
        // their immutable snapshots remain owned by persistence.
        preservedMacrocycles.add(_deepCopyMap(macrocycle));
        historicalInstanceIds.add(instanceId);
        continue;
      }
      if (macrocycle['recipeId'] != 'forever-2l1a-v2') {
        throw FormatException(
          'Recette Forever non exécutable: ${macrocycle['recipeId']}.',
        );
      }
      _validateExecutableMacrocycle(macrocycle);
      futureDomainMacrocycles.add(domainMacrocycle);
      macrocycles.add(
        _GeneratedMacrocycle(
          instanceId: instanceId,
          metadata: {
            'instanceId': instanceId,
            'intent': macrocycle['intent'],
            'status': macrocycle['status'],
            'recipeId': macrocycle['recipeId'],
          },
        ),
      );
    }
    final profile = _planningProfile(decoded.common);
    final domainSeries = planning.ForeverProgramSeries(
      id: '${seriesValue['id'] ?? 'forever-series-v1'}',
      profile: profile,
      macrocycles: domainMacrocycles,
      terminated: seriesValue['terminated'] == true,
    );
    final validation = const planning.MacrocycleSeriesValidator().validate(
      domainSeries,
    );
    if (!validation.isValid) {
      throw planning.ForeverCompilationException(validation);
    }
    if (futureDomainMacrocycles.isNotEmpty) {
      final compiled = const planning.ForeverSequenceCompiler().compileSeries(
        domainSeries,
      );
      var startDate = _startDate(decoded.common);
      final historicalSequence = planning.CompiledForeverSequence(
        nodes: compiled.nodes.where(
          (node) => historicalInstanceIds.any(
            (instanceId) => node.nodeId.startsWith('$instanceId-'),
          ),
        ),
        trainingMaxDecisions: const [],
      );
      startDate = startDate.add(
        Duration(days: _compiledWeeks(historicalSequence) * 7),
      );
      for (final macrocycle in futureDomainMacrocycles) {
        final sequence = planning.CompiledForeverSequence(
          nodes: compiled.nodes.where(
            (node) => node.nodeId.startsWith('${macrocycle.instanceId}-'),
          ),
          trainingMaxDecisions: compiled.trainingMaxDecisions.where(
            (decision) => decision.cycleInstanceId == macrocycle.instanceId,
          ),
        );
        final initialMaxes =
            sequence.trainingMaxDecisions.single.previousTrainingMaxes;
        final configuration = _foreverConfiguration({
          ...decoded.common,
          'lifts': _displayTrainingMaxes(initialMaxes),
          'inputMode': 'tm',
          'trainingMaxRatio': 100,
          'foreverTemplateId': 'FV-236',
          'startDate': startDate,
        });
        if (configuration == null) return null;
        configurations.add(configuration);
        compiledSequences.add(sequence);
        startDate = startDate.add(Duration(days: _compiledWeeks(sequence) * 7));
      }
    }
    return _ForeverGenerationRequest.series(
      seriesId: '${seriesValue['id'] ?? 'forever-series-v1'}',
      terminated: seriesValue['terminated'] == true,
      preservedMacrocycles: preservedMacrocycles,
      sourceOrder: sourceOrder,
      macrocycles: macrocycles,
      configurations: configurations,
      compiledSequences: compiledSequences,
    );
  }

  static Map<String, double> _displayTrainingMaxes(
    Map<String, double> trainingMaxes,
  ) => {
    'Press': trainingMaxes['overheadPress'] ?? trainingMaxes['press']!,
    'Bench Press': trainingMaxes['benchPress'] ?? trainingMaxes['bench']!,
    'Squat': trainingMaxes['squat']!,
    'Deadlift': trainingMaxes['deadlift']!,
  };

  static int _compiledWeeks(planning.CompiledForeverSequence sequence) =>
      sequence.nodes.fold(
        0,
        (weeks, node) => weeks + (node is planning.ForeverCycleNode ? 3 : 1),
      );

  static void _validateExecutableMacrocycle(Map<String, Object?> macrocycle) {
    final slots = macrocycle['slots'];
    final protocols = macrocycle['protocols'];
    if (slots is! List || protocols is! List) {
      throw const FormatException('Slots ou protocoles manquants.');
    }
    if (slots.length != slots.whereType<Map>().length ||
        protocols.length != protocols.whereType<Map>().length) {
      throw const FormatException('Slot ou protocole invalide.');
    }
    final slotIds = slots
        .whereType<Map>()
        .map((slot) => slot['slotId'])
        .toList();
    if (slotIds.length != 3 ||
        slotIds[0] != 'leader-1' ||
        slotIds[1] != 'leader-2' ||
        slotIds[2] != 'anchor-1') {
      throw const FormatException('La recette 2L/1A exige ses trois slots.');
    }
    const expectedRoles = ['leader', 'leader', 'anchor'];
    const expectedRevisions = [
      'forever-original-fsl-leader-v1',
      'forever-original-fsl-leader-v1',
      'forever-original-pr-set-anchor-v1',
    ];
    for (var index = 0; index < slots.length; index++) {
      final slot = slots[index] as Map;
      if (slot['role'] != expectedRoles[index] ||
          slot['cycleTemplateRevisionId'] != expectedRevisions[index]) {
        throw const FormatException('Rôle ou révision de cycle invalide.');
      }
    }
    final protocolIds = protocols
        .whereType<Map>()
        .map((protocol) => protocol['protocolTemplateRevisionId'])
        .toSet();
    final protocolByBoundary = {
      for (final protocol in protocols.whereType<Map>())
        protocol['boundaryId']: protocol['protocolTemplateRevisionId'],
    };
    if (!protocolIds.contains('forever-seventh-week-deload-v1') ||
        !protocolIds.contains('forever-seventh-week-tm-test-v1') ||
        protocols.length != 2 ||
        protocolByBoundary['leaders-to-anchor'] !=
            'forever-seventh-week-deload-v1' ||
        protocolByBoundary['macrocycle-end'] !=
            'forever-seventh-week-tm-test-v1' ||
        protocols.whereType<Map>().any(
          (protocol) => protocol['required'] != true,
        )) {
      throw const FormatException(
        'Les protocoles obligatoires de la recette sont absents.',
      );
    }
  }

  static planning.ForeverMacrocycle _domainMacrocycle(
    Map<String, Object?> value,
  ) {
    final recipe = switch (value['recipeId']) {
      'forever-2l1a-v2' => planning.foreverTwoLeadersOneAnchorRecipe,
      'forever-2l2a-v1' => planning.foreverTwoLeadersTwoAnchorsRecipe,
      'forever-3l2a-v1' => planning.foreverThreeLeadersTwoAnchorsRecipe,
      _ => throw FormatException(
        'Recette Forever inconnue: ${value['recipeId']}.',
      ),
    };
    final intent = switch (value['intent']) {
      'active' => planning.MacrocycleIntent.active,
      'projected' => planning.MacrocycleIntent.projected,
      _ => throw FormatException(
        'Intent Forever invalide: ${value['intent']}.',
      ),
    };
    final status = switch (value['status']) {
      'planned' => planning.MacrocycleStatus.planned,
      'active' => planning.MacrocycleStatus.active,
      'completed' => planning.MacrocycleStatus.completed,
      'cancelled' => planning.MacrocycleStatus.cancelled,
      _ => throw FormatException(
        'Statut Forever invalide: ${value['status']}.',
      ),
    };
    final slots = value['slots'];
    if (slots is! List) throw const FormatException('Slots manquants.');
    final rawTrainingMaxStates = value['trainingMaxStates'];
    final trainingMaxStates = <String, planning.TrainingMaxDecisionState>{};
    final trainingMaxChoices = <String, double>{};
    if (rawTrainingMaxStates is Map) {
      for (final entry in rawTrainingMaxStates.entries) {
        final lift = '${entry.key}';
        final raw = entry.value;
        final stateValue = raw is Map ? raw['state'] : raw;
        final state = switch (stateValue) {
          'confirmed' => planning.TrainingMaxDecisionState.confirmed,
          'projected' => planning.TrainingMaxDecisionState.projected,
          'proposed' => planning.TrainingMaxDecisionState.proposed,
          'held' => planning.TrainingMaxDecisionState.held,
          'reset' => planning.TrainingMaxDecisionState.reset,
          _ => null,
        };
        if (state != null) trainingMaxStates[lift] = state;
        if (raw is Map) {
          final candidate =
              raw['trainingMax'] ??
              raw['confirmedTrainingMax'] ??
              raw['proposedTrainingMax'] ??
              raw['value'];
          if (candidate is num) {
            trainingMaxChoices[lift] = candidate.toDouble();
          }
        }
      }
    }
    return planning.ForeverMacrocycle(
      instanceId: value['instanceId']! as String,
      intent: intent,
      status: status,
      recipe: recipe,
      outcome: trainingMaxStates.isEmpty
          ? null
          : planning.MacrocycleOutcome(
              macrocycleInstanceId: value['instanceId']! as String,
              trainingMaxStates: trainingMaxStates,
            ),
      trainingMaxChoices: trainingMaxChoices,
      cycleSelections: [
        for (final raw in slots.whereType<Map>())
          planning.CycleSlotSelection(
            slotId: '${raw['slotId']}',
            cycleInstanceId: '${value['instanceId']}-${raw['slotId']}',
            revision: raw['role'] == 'anchor'
                ? planning.foreverOriginalPrSetAnchorRevision
                : planning.foreverOriginalFslLeaderRevision,
          ),
      ],
    );
  }

  planning.CommonTrainingProfile _planningProfile(Map<String, Object?> common) {
    final maxes = _trainingMaxes(common);
    if (maxes == null) {
      throw const FormatException('Training Maxes Forever incomplets.');
    }
    return planning.CommonTrainingProfile(
      unit: common['unit'] == 'lb'
          ? planning.TrainingUnit.pounds
          : planning.TrainingUnit.kilograms,
      trainingDaysPerWeek: common['days'] as int? ?? 4,
      trainingWeekdays:
          (common['trainingWeekdays'] as List?)?.whereType<int>().toList() ??
          const [1, 2, 4, 5],
      trainingMaxRatio:
          ((common['trainingMaxRatio'] as num?)?.toDouble() ?? 90) / 100,
      roundingIncrement:
          (common['roundingIncrement'] as num?)?.toDouble() ?? 2.5,
      trainingMaxes: maxes,
      progressionIncrements: {
        for (final lift in maxes.keys)
          lift: lift == 'press' || lift == 'bench' ? 2.5 : 5,
      },
    );
  }

  static DateTime _startDate(Map<String, Object?> common) =>
      switch (common['startDate']) {
        final DateTime value => value.toUtc(),
        final String value when DateTime.tryParse(value) != null =>
          DateTime.parse(value).toUtc(),
        _ => DateTime.utc(2026, 1, 5),
      };

  static Map<String, Object?> _deepCopyMap(Map<String, Object?> source) => {
    for (final entry in source.entries) entry.key: _deepCopy(entry.value),
  };

  static Object? _deepCopy(Object? value) => switch (value) {
    Map map => {
      for (final entry in map.entries) '${entry.key}': _deepCopy(entry.value),
    },
    List list => [for (final item in list) _deepCopy(item)],
    _ => value,
  };

  core.ProgramConfiguration? _foreverConfiguration(Map<String, Object?> value) {
    final id = value['foreverTemplateId'] as String?;
    final lifts = _liftInputs(value);
    if (id == null || lifts == null) return null;
    final days = value['days'] as int? ?? 4;
    return core.ProgramConfiguration(
      programId: id,
      generation: core.Generation.forever,
      unit: value['unit'] == 'lb'
          ? core.WeightUnit.pounds
          : core.WeightUnit.kilograms,
      lifts: lifts,
      trainingMaxRatio:
          ((value['trainingMaxRatio'] as num?)?.toDouble() ?? 90) / 100,
      daysPerWeek: days,
      trainingWeekdays: List.generate(days, (index) => index + 1),
      options: const core.GenerationSpecificOptions(
        projectFutureTrainingMaxes: true,
      ),
      startDate: switch (value['startDate']) {
        final DateTime date => date,
        final String encoded =>
          DateTime.tryParse(encoded)?.toUtc() ?? DateTime.utc(2026, 1, 5),
        _ => DateTime.utc(2026, 1, 5),
      },
    );
  }

  Map<String, double>? _trainingMaxes(Map<String, Object?> value) {
    final inputs = _liftInputs(value);
    if (inputs == null) return null;
    final ratio = ((value['trainingMaxRatio'] as num?)?.toDouble() ?? 90) / 100;
    return {
      for (final entry in inputs.entries)
        _coreLiftId(entry.key): core
            .deriveTrainingMax(input: entry.value, ratio: ratio)
            .trainingMax,
    };
  }

  Map<core.MainLift, core.LiftInput>? _liftInputs(Map<String, Object?> value) {
    final raw = value['lifts'];
    if (raw is! Map) return null;
    final reps = value['repetitions'];
    final inputMode = value['inputMode'] as String? ?? 'oneRm';
    const names = {
      core.MainLift.overheadPress: 'Press',
      core.MainLift.benchPress: 'Bench Press',
      core.MainLift.squat: 'Squat',
      core.MainLift.deadlift: 'Deadlift',
    };
    final result = <core.MainLift, core.LiftInput>{};
    for (final entry in names.entries) {
      final weight = raw[entry.value];
      if (weight is! num || weight <= 0) return null;
      final repetitionCount = reps is Map ? reps[entry.value] as int? ?? 1 : 1;
      final kind = switch (inputMode) {
        'tm' || 'plusSet' => core.LiftInputKind.trainingMax,
        _ when repetitionCount > 1 => core.LiftInputKind.repetitionMax,
        _ => core.LiftInputKind.oneRepMax,
      };
      result[entry.key] = core.LiftInput(
        lift: entry.key,
        kind: kind,
        weight: inputMode == 'plusSet'
            ? weight.toDouble() / .95
            : weight.toDouble(),
        repetitions: kind == core.LiftInputKind.repetitionMax
            ? repetitionCount
            : null,
      );
    }
    return result;
  }

  static String _coreLiftId(core.MainLift lift) => switch (lift) {
    core.MainLift.overheadPress => 'press',
    core.MainLift.benchPress => 'bench',
    core.MainLift.squat => 'squat',
    core.MainLift.deadlift => 'deadlift',
  };

  @override
  Future<String> serializeConfiguration(
    Map<String, Object?> configuration,
  ) async {
    const codec = Poc531ConfigurationCodec();
    final version = configuration['schemaVersion'];
    final decoded = version == Poc531Configuration.schemaVersion
        ? codec.decodeMap(configuration)
        : codec.decodeMap({...configuration, 'schemaVersion': 2});
    return codec.encode(decoded);
  }

  @override
  Future<PlateLoadingView> calculatePlateLoading({
    required double weight,
    required double barWeight,
    required List<double> inventory,
    required String unit,
  }) async {
    final result = core.calculatePlateLoading(
      weight,
      core.PlateInventory(
        barWeight: barWeight,
        plates: {
          for (final plate in inventory.toSet())
            plate: inventory.where((candidate) => candidate == plate).length,
        },
      ),
    );
    return PlateLoadingView(
      perSide: result.perSide,
      actualWeight: result.loadedWeight,
      roundingError: result.roundingError,
    );
  }

  static List<PlanBlockView> _payloadToBlocks(Map<String, Object?> payload) {
    final rawBlocks = payload['blocks'] ?? payload['cycles'];
    if (rawBlocks is! List) {
      return [
        PlanBlockView('Plan', [
          PlanWeekView('Programme', [
            PlanSessionView('Prescription', [jsonEncode(payload)]),
          ]),
        ]),
      ];
    }
    return [for (var i = 0; i < rawBlocks.length; i++) _block(rawBlocks[i], i)];
  }

  static PlanBlockView _block(Object? raw, int index) {
    final map = raw is Map ? raw : const {};
    final cycles = map['cycles'];
    final weeks = map['weeks'];
    final role = '${map['role'] ?? ''}';
    return PlanBlockView(
      '${map['name'] ?? (role.isEmpty ? map['kind'] : _titleCase(role)) ?? 'Bloc ${index + 1}'}',
      [
        if (cycles is List)
          for (var cycleIndex = 0; cycleIndex < cycles.length; cycleIndex++)
            ..._cycleWeeks(cycles[cycleIndex], cycleIndex)
        else if (weeks is List)
          for (var i = 0; i < weeks.length; i++) _week(weeks[i], i)
        else
          PlanWeekView('Contenu', [
            PlanSessionView('Prescription', [jsonEncode(raw)]),
          ]),
      ],
    );
  }

  static List<PlanWeekView> _cycleWeeks(Object? raw, int cycleIndex) {
    final cycle = raw is Map ? raw : const {};
    final weeks = cycle['weeks'];
    if (weeks is! List) return const [];
    return [
      for (var weekIndex = 0; weekIndex < weeks.length; weekIndex++)
        _week(
          weeks[weekIndex],
          weekIndex,
          cycleNumber: cycle['number'] as int? ?? cycleIndex + 1,
        ),
    ];
  }

  static PlanWeekView _week(Object? raw, int index, {int? cycleNumber}) {
    final map = raw is Map ? raw : const {};
    final sessions = map['sessions'] ?? map['workouts'];
    final weekNumber = map['number'] ?? index + 1;
    final cycleLabel = cycleNumber == null ? '' : ' · Cycle $cycleNumber';
    return PlanWeekView('${map['name'] ?? 'Semaine $weekNumber'}$cycleLabel', [
      if (sessions is List)
        for (var i = 0; i < sessions.length; i++)
          _payloadSession(sessions[i], i)
      else
        PlanSessionView('Prescription', [jsonEncode(raw)]),
    ]);
  }

  static PlanSessionView _payloadSession(Object? raw, int index) {
    final session = raw is Map ? raw : const {};
    final blocks = session['blocks'];
    final directPrescriptions = session['prescriptions'];
    final prescriptions = <Map>[];
    if (blocks is List) {
      for (final rawBlock in blocks) {
        if (rawBlock is! Map) continue;
        final blockPrescriptions = rawBlock['prescriptions'];
        if (blockPrescriptions is List) {
          prescriptions.addAll(blockPrescriptions.whereType<Map>());
        }
      }
    } else if (directPrescriptions is List) {
      prescriptions.addAll(directPrescriptions.whereType<Map>());
    }
    final firstMovement = prescriptions.firstOrNull?['movement'];
    final movement =
        '${firstMovement ?? session['movementId'] ?? session['exercise'] ?? 'Séance ${index + 1}'}'
            .replaceAll('barbell.', '')
            .replaceAll('-', ' ');
    if (prescriptions.isEmpty) {
      return PlanSessionView(_liftLabel(movement), const [
        'Prescription disponible dans l’export JSON.',
      ]);
    }
    return PlanSessionView(_liftLabel(movement), [
      for (final prescription in prescriptions) _prescriptionLine(prescription),
    ]);
  }

  static String _prescriptionLine(Map prescription) {
    final sets = prescription['sets'] ?? 1;
    final reps =
        prescription['repetitionsPerSet'] ?? prescription['repetitions'] ?? '?';
    final load =
        prescription['load'] ??
        prescription['calculatedLoad'] ??
        prescription['weight'];
    final percent = prescription['percentage'];
    final kind = '${prescription['kind'] ?? prescription['setKind'] ?? ''}'
        .replaceAll('mainWork', 'MAIN')
        .replaceAll('supplemental', 'SUP');
    final displayedPercent = percent is num
        ? (percent <= 1 ? percent * 100 : percent)
        : null;
    return '${kind.isEmpty ? '' : '$kind · '}$sets × $reps${load == null ? '' : ' · $load'}${displayedPercent == null ? '' : ' · ${displayedPercent.toStringAsFixed(0)}%'}';
  }

  static String _titleCase(String value) => value
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _ForeverGenerationRequest {
  const _ForeverGenerationRequest._({
    required this.seriesId,
    required this.terminated,
    required this.preservedMacrocycles,
    required this.sourceOrder,
    required this.macrocycles,
    required this.configurations,
    required this.compiledSequences,
    required this.isSeries,
  });

  factory _ForeverGenerationRequest.single(
    core.ProgramConfiguration configuration,
  ) => _ForeverGenerationRequest._(
    seriesId: '',
    terminated: false,
    preservedMacrocycles: const [],
    sourceOrder: const ['M1'],
    macrocycles: const [_GeneratedMacrocycle(instanceId: 'M1', metadata: {})],
    configurations: [configuration],
    compiledSequences: const [null],
    isSeries: false,
  );

  factory _ForeverGenerationRequest.series({
    required String seriesId,
    required bool terminated,
    required List<Map<String, Object?>> preservedMacrocycles,
    required List<String> sourceOrder,
    required List<_GeneratedMacrocycle> macrocycles,
    required List<core.ProgramConfiguration> configurations,
    required List<planning.CompiledForeverSequence?> compiledSequences,
  }) => _ForeverGenerationRequest._(
    seriesId: seriesId,
    terminated: terminated,
    preservedMacrocycles: List.unmodifiable(preservedMacrocycles),
    sourceOrder: List.unmodifiable(sourceOrder),
    macrocycles: List.unmodifiable(macrocycles),
    configurations: List.unmodifiable(configurations),
    compiledSequences: List.unmodifiable(compiledSequences),
    isSeries: true,
  );

  final String seriesId;
  final bool terminated;
  final List<Map<String, Object?>> preservedMacrocycles;
  final List<String> sourceOrder;
  final List<_GeneratedMacrocycle> macrocycles;
  final List<core.ProgramConfiguration> configurations;
  final List<planning.CompiledForeverSequence?> compiledSequences;
  final bool isSeries;

  List<Map<String, Object?>> exportMacrocycles(
    List<core.GeneratedProgram> plans,
  ) {
    final preserved = {
      for (final value in preservedMacrocycles)
        value['instanceId']! as String: value,
    };
    final generated = <String, Map<String, Object?>>{
      for (var index = 0; index < macrocycles.length; index++)
        macrocycles[index].instanceId: {
          ...macrocycles[index].metadata,
          'generatedProgram': plans[index].toJson(),
        },
    };
    return [for (final id in sourceOrder) preserved[id] ?? generated[id]!];
  }
}

class _GeneratedMacrocycle {
  const _GeneratedMacrocycle({
    required this.instanceId,
    required this.metadata,
  });

  final String instanceId;
  final Map<String, Object?> metadata;
}
