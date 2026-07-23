import 'dart:convert';

import '../../cycle_generation/domain/catalog_cycle_primitives.dart';
import '../../cycle_generation/domain/cycle_contract.dart';
import '../../cycle_generation/domain/cycle_execution_options.dart';
import '../../cycle_generation/domain/cycle_schedule_mode.dart';
import '../../cycle_generation/domain/load_rounding_policy.dart';

final class SourceComponent {
  const SourceComponent({
    required this.reference,
    required this.block,
    required this.constraints,
    required this.compatibilities,
    this.sessionMovementBindings = const [],
    this.mainWorkSemantics,
  });
  final ComponentReference reference;
  final BlockDefinition block;
  final Map<String, Object?> constraints;
  final Map<String, Object?> compatibilities;
  final List<SourceSessionMovementBinding> sessionMovementBindings;
  final MainWorkSemantics? mainWorkSemantics;
}

final class SourceSessionMovementBinding {
  const SourceSessionMovementBinding({
    required this.sessionId,
    required this.movementId,
  });

  final String sessionId;
  final String movementId;
}

final class SourceSchedule {
  const SourceSchedule({
    required this.reference,
    required this.sessions,
    this.type = CycleScheduleMode.fixed,
    this.sessionBlockOrder = SessionBlockOrder.componentMajor,
    this.sessionsPerWeek,
  });
  final ComponentReference reference;
  final List<SourceSession> sessions;
  final CycleScheduleMode type;
  final SessionBlockOrder sessionBlockOrder;
  final int? sessionsPerWeek;
}

final class SourceSession {
  const SourceSession({
    required this.id,
    required this.movementIds,
    this.role = 'mainLift',
  });
  final String id;
  final List<String> movementIds;
  final String role;
}

final class SourceVariant {
  const SourceVariant({
    required this.id,
    required this.revision,
    required this.scheduleIds,
    required this.weekPlans,
    required this.phases,
    required this.compatibilities,
    required this.optionSchemaId,
    this.componentSelections = const [],
    this.optionRecipeId,
    this.assistancePlanIds = const [],
    this.conditioningDefinitionIds = const [],
    this.loadRoundingPolicy = LoadRoundingPolicy.nearest,
    this.trainingMaxProgression,
  });
  final String id;
  final int revision;
  final List<ComponentReference> scheduleIds;
  final List<CatalogWeekPlan> weekPlans;
  final List<CatalogPhase> phases;
  final Map<String, Object?> compatibilities;
  final ComponentReference optionSchemaId;
  final List<SourceComponentSelection> componentSelections;
  final ComponentReference? optionRecipeId;
  final List<ComponentReference> assistancePlanIds;
  final List<ComponentReference> conditioningDefinitionIds;
  final LoadRoundingPolicy loadRoundingPolicy;
  final TrainingMaxProgression? trainingMaxProgression;
}

final class SourceBlockRecipe {
  const SourceBlockRecipe({
    this.componentIds = const [],
    this.byUnit = const {},
  });
  final List<ComponentReference> componentIds;
  final Map<WeightUnit, List<ComponentReference>> byUnit;
}

final class SourceCycleOptionRecipe {
  const SourceCycleOptionRecipe({
    required this.reference,
    this.warmUp = const {},
    this.joker,
    this.deload = const {},
  });
  final ComponentReference reference;
  final Map<WarmUpType, SourceBlockRecipe> warmUp;
  final ResolvedJokerRecipe? joker;
  final Map<DeloadType, SourceBlockRecipe> deload;
}

final class SourceComponentSelection {
  const SourceComponentSelection({
    required this.parameterId,
    required this.targetComponentId,
    required this.choices,
  });
  final String parameterId;
  final ComponentReference targetComponentId;
  final List<SourceComponentSelectionChoice> choices;
}

final class SourceComponentSelectionChoice {
  const SourceComponentSelectionChoice({
    required this.value,
    required this.componentId,
  });
  final Object value;
  final ComponentReference componentId;
}

enum TemplateSurface { cyclePublic, foreverInternal }

final class SourceTemplateGeneration {
  const SourceTemplateGeneration({required this.id, required this.labels});

  final String id;
  final Map<String, String> labels;
}

final class SourceTemplate {
  const SourceTemplate({
    required this.id,
    required this.revision,
    required this.variants,
    required this.surface,
    required this.generation,
    this.isDefault = false,
  });
  final String id;
  final int revision;
  final List<SourceVariant> variants;
  final TemplateSurface surface;
  final SourceTemplateGeneration generation;
  final bool isDefault;
}

final class SourceTemplateAlias {
  const SourceTemplateAlias({
    required this.legacyTemplateId,
    required this.legacyVariantId,
    required this.templateId,
    required this.variantId,
    required this.optionOverrides,
  });
  final String legacyTemplateId;
  final String legacyVariantId;
  final String templateId;
  final String variantId;
  final Map<String, Object> optionOverrides;
}

final class CatalogSourceDocumentCodec {
  const CatalogSourceDocumentCodec();

  List<SourceComponent> decodeComponents(String source) {
    final root = _root(source, 'components');
    return _list(root, 'components')
        .map((value) {
          final map = _map(value, 'component');
          _keys(
            map,
            const {
              'id',
              'revision',
              'role',
              'labels',
              'sourceRuleIds',
              'parameterSchemaIds',
              'constraints',
              'compatibilities',
              'block',
            },
            optional: const {'sessionMovementBindings'},
          );
          final block = _block(_map(map['block'], 'block'));
          final constraints = _map(map['constraints'], 'constraints');
          final compatibilities = _map(
            map['compatibilities'],
            'compatibilities',
          );
          final bindings = _sessionMovementBindings(
            map['sessionMovementBindings'],
          );
          if (bindings.isNotEmpty) {
            if (block.movementId != null) {
              throw const FormatException(
                'sessionMovementBindings cannot be combined with '
                'block.movementId.',
              );
            }
            if (constraints.containsKey('movementRelation')) {
              throw const FormatException(
                'sessionMovementBindings cannot be combined with '
                'constraints.movementRelation.',
              );
            }
            if (compatibilities.containsKey('sessionIds') ||
                compatibilities.containsKey('movementIds')) {
              throw const FormatException(
                'sessionMovementBindings cannot be combined with component '
                'sessionIds or movementIds compatibilities.',
              );
            }
          }
          return SourceComponent(
            reference: _recordReference(map),
            block: block,
            constraints: constraints,
            compatibilities: compatibilities,
            sessionMovementBindings: bindings,
            mainWorkSemantics: _mainWorkSemantics(block, constraints),
          );
        })
        .toList(growable: false);
  }

  List<SourceSessionMovementBinding> _sessionMovementBindings(Object? value) {
    if (value == null) return const [];
    if (value is! List<Object?> || value.isEmpty) {
      throw const FormatException(
        'sessionMovementBindings must be a non-empty list.',
      );
    }
    final sessionIds = <String>{};
    return List.unmodifiable([
      for (final item in value)
        (() {
          final binding = _map(item, 'sessionMovementBinding');
          _keys(binding, const {'sessionId', 'movementId'});
          final sessionId = _nonEmptyString(binding, 'sessionId');
          final movementId = _nonEmptyString(binding, 'movementId');
          if (!sessionIds.add(sessionId)) {
            throw FormatException(
              'Duplicate sessionMovementBinding for session $sessionId.',
            );
          }
          return SourceSessionMovementBinding(
            sessionId: sessionId,
            movementId: movementId,
          );
        })(),
    ]);
  }

  List<SourceSchedule> decodeSchedules(String source) {
    final root = _root(source, 'schedules');
    return _list(root, 'schedules')
        .map((value) {
          final map = _map(value, 'schedule');
          _keys(
            map,
            const {
              'id',
              'revision',
              'labels',
              'sourceRuleIds',
              'type',
              'sessions',
            },
            optional: const {'sessionsPerWeek', 'sessionBlockOrder'},
          );
          final type = _scheduleMode(map);
          final sessionBlockOrder = _sessionBlockOrder(
            map['sessionBlockOrder'],
          );
          if (sessionBlockOrder == SessionBlockOrder.movementMajor &&
              type != CycleScheduleMode.multiMovement) {
            throw const FormatException(
              'movementMajor sessionBlockOrder requires a multiMovement schedule.',
            );
          }
          final sessions = _list(map, 'sessions')
              .map((value) {
                final session = _map(value, 'session');
                _keys(session, const {'id', 'role', 'movementIds'});
                return SourceSession(
                  id: _string(session, 'id'),
                  movementIds: _strings(session, 'movementIds'),
                  role: _string(session, 'role'),
                );
              })
              .toList(growable: false);
          if (sessionBlockOrder == SessionBlockOrder.movementMajor) {
            if (sessions.every((session) => session.movementIds.length < 2)) {
              throw const FormatException(
                'movementMajor sessionBlockOrder requires a session with multiple movements.',
              );
            }
            for (final session in sessions) {
              if (session.movementIds.isEmpty ||
                  session.movementIds.toSet().length !=
                      session.movementIds.length) {
                throw const FormatException(
                  'movementMajor session movementIds must be non-empty and unique.',
                );
              }
            }
          }
          final sessionsPerWeek = map['sessionsPerWeek'] == null
              ? null
              : _positiveInt(map, 'sessionsPerWeek');
          if (sessionsPerWeek != null) {
            _validateScheduleCadence(type, sessions, sessionsPerWeek);
          }
          return SourceSchedule(
            reference: _recordReference(map),
            type: type,
            sessionBlockOrder: sessionBlockOrder,
            sessions: sessions,
            sessionsPerWeek: sessionsPerWeek,
          );
        })
        .toList(growable: false);
  }

  List<SourceTemplate> decodeTemplates(String source) {
    final root = _root(source, 'templates', optional: const {'generation'});
    final generation = _templateGeneration(root['generation']);
    return _list(root, 'templates')
        .map((value) {
          final map = _map(value, 'template');
          _keys(
            map,
            const {
              'id',
              'revision',
              'labels',
              'sourceRuleIds',
              'surface',
              'isDefault',
              'variants',
            },
            optional: const {'isDefault'},
          );
          return SourceTemplate(
            id: _string(map, 'id'),
            revision: _int(map, 'revision'),
            surface: TemplateSurface.values.byName(_string(map, 'surface')),
            generation: generation,
            isDefault: map['isDefault'] == null
                ? false
                : _bool(map, 'isDefault'),
            variants: _list(
              map,
              'variants',
            ).map(_variant).toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  SourceTemplateGeneration _templateGeneration(Object? value) {
    if (value == null) {
      return const SourceTemplateGeneration(
        id: 'unspecified',
        labels: {'en': 'Unspecified', 'fr': 'Non spécifiée'},
      );
    }
    final generation = _map(value, 'template generation');
    _keys(generation, const {'id', 'labels'});
    final labels = _map(generation['labels'], 'template generation labels');
    _keys(labels, const {'en', 'fr'});
    return SourceTemplateGeneration(
      id: _string(generation, 'id'),
      labels: {'en': _string(labels, 'en'), 'fr': _string(labels, 'fr')},
    );
  }

  List<SourceTemplateAlias> decodeTemplateAliases(String source) {
    final root = _root(source, 'templateAliases');
    return _list(root, 'templateAliases')
        .map((value) {
          final map = _map(value, 'templateAlias');
          _keys(map, const {
            'legacyTemplateId',
            'legacyVariantId',
            'templateId',
            'variantId',
            'optionOverrides',
          });
          final overrides = _map(map['optionOverrides'], 'optionOverrides');
          for (final entry in overrides.entries) {
            if (!_isJsonScalar(entry.value)) {
              throw FormatException(
                'Option override ${entry.key} must be a JSON scalar.',
              );
            }
          }
          return SourceTemplateAlias(
            legacyTemplateId: _string(map, 'legacyTemplateId'),
            legacyVariantId: _string(map, 'legacyVariantId'),
            templateId: _string(map, 'templateId'),
            variantId: _string(map, 'variantId'),
            optionOverrides: overrides.cast<String, Object>(),
          );
        })
        .toList(growable: false);
  }

  List<SourceCycleOptionRecipe> decodeCycleOptionRecipes(String source) {
    final root = _root(source, 'cycleOptionRecipes');
    return _list(root, 'cycleOptionRecipes')
        .map((value) {
          final map = _map(value, 'cycleOptionRecipe');
          _keys(
            map,
            const {'id', 'revision', 'warmUp', 'joker', 'deload'},
            optional: const {'warmUp', 'joker', 'deload'},
          );
          final warmUp = <WarmUpType, SourceBlockRecipe>{};
          if (map['warmUp'] != null) {
            final recipes = _map(map['warmUp'], 'warmUp');
            _enumKeys(
              recipes,
              WarmUpType.values.map((value) => value.name).toSet(),
            );
            for (final entry in recipes.entries) {
              warmUp[WarmUpType.values.byName(entry.key)] = _blockRecipe(
                _map(entry.value, 'warmUp.${entry.key}'),
              );
            }
          }
          final deload = <DeloadType, SourceBlockRecipe>{};
          if (map['deload'] != null) {
            final recipes = _map(map['deload'], 'deload');
            _enumKeys(
              recipes,
              DeloadType.values.map((value) => value.name).toSet(),
            );
            for (final entry in recipes.entries) {
              deload[DeloadType.values.byName(entry.key)] = _blockRecipe(
                _map(entry.value, 'deload.${entry.key}'),
              );
            }
          }
          return SourceCycleOptionRecipe(
            reference: _recordReference(map),
            warmUp: Map.unmodifiable(warmUp),
            joker: map['joker'] == null
                ? null
                : _jokerRecipe(_map(map['joker'], 'joker')),
            deload: Map.unmodifiable(deload),
          );
        })
        .toList(growable: false);
  }

  SourceBlockRecipe _blockRecipe(Map<String, Object?> map) {
    _keys(
      map,
      const {'componentIds', 'byUnit'},
      optional: const {'componentIds', 'byUnit'},
    );
    if (map.containsKey('componentIds') == map.containsKey('byUnit')) {
      throw const FormatException(
        'Option recipe requires exactly one of componentIds or byUnit.',
      );
    }
    if (map['componentIds'] != null) {
      return SourceBlockRecipe(
        componentIds: _componentReferences(map['componentIds'], 'componentIds'),
      );
    }
    final units = _map(map['byUnit'], 'byUnit');
    _enumKeys(units, WeightUnit.values.map((value) => value.name).toSet());
    if (units.isEmpty) {
      throw const FormatException('Option recipe byUnit cannot be empty.');
    }
    return SourceBlockRecipe(
      byUnit: Map.unmodifiable({
        for (final entry in units.entries)
          WeightUnit.values.byName(entry.key): _componentReferences(
            entry.value,
            entry.key,
          ),
      }),
    );
  }

  List<ComponentReference> _componentReferences(Object? value, String label) {
    if (value is! List<Object?> || value.isEmpty) {
      throw FormatException('$label must be a non-empty reference list.');
    }
    return List.unmodifiable(
      value.map((value) => _reference(_map(value, label))),
    );
  }

  ResolvedJokerRecipe _jokerRecipe(Map<String, Object?> map) {
    _keys(map, const {'blockId', 'steps'});
    final steps = _list(map, 'steps')
        .map((value) {
          final step = _map(value, 'jokerStep');
          _keys(step, const {'cumulativeIncreaseBasisPoints', 'repetitions'});
          return JokerRecipeStep(
            cumulativeIncreaseBasisPoints: _positiveInt(
              step,
              'cumulativeIncreaseBasisPoints',
            ),
            repetitions: _repetitions(_map(step['repetitions'], 'repetitions')),
          );
        })
        .toList(growable: false);
    if (steps.isEmpty) {
      throw const FormatException('Joker recipe steps cannot be empty.');
    }
    return ResolvedJokerRecipe(
      blockId: _nonEmptyString(map, 'blockId'),
      steps: List.unmodifiable(steps),
    );
  }

  List<Map<String, Object?>> decodeOptionSchemas(String source) {
    final root = _root(source, 'optionSchemas');
    return _list(root, 'optionSchemas')
        .map((value) {
          final map = _map(value, 'optionSchema');
          _keys(
            map,
            const {'id', 'revision', 'sourceRuleIds', 'parameters'},
            optional: const {'includeSchemaIds'},
          );
          _nonEmptyString(map, 'id');
          _positiveInt(map, 'revision');
          _validateOptionSchemaReferences(map);
          for (final value in _list(map, 'parameters')) {
            final parameter = _map(value, 'parameter');
            _keys(
              parameter,
              const {
                'id',
                'type',
                'scope',
                'default',
                'minimum',
                'maximum',
                'step',
                'allowedValues',
                'visibleWhen',
                'enabledWhen',
                'requiredWhen',
              },
              optional: const {
                'presentationGroup',
                'labelEn',
                'labelFr',
                'requestPath',
              },
            );
            _nonEmptyString(parameter, 'id');
            if (parameter['requestPath'] case final Object requestPath) {
              if (requestPath is! String ||
                  requestPath.isEmpty ||
                  requestPath.startsWith('options.') ||
                  requestPath.split('.').any((segment) => segment.isEmpty)) {
                throw const FormatException(
                  'requestPath must be relative to options.',
                );
              }
            }
          }
          return map;
        })
        .toList(growable: false);
  }

  void _validateOptionSchemaReferences(Map<String, Object?> schema) {
    if (!schema.containsKey('includeSchemaIds')) return;
    final values = _list(schema, 'includeSchemaIds');
    if (values.isEmpty) {
      throw const FormatException('includeSchemaIds cannot be empty.');
    }
    final seen = <String>{};
    for (final value in values) {
      final reference = _map(value, 'includeSchemaId');
      _keys(reference, const {'id', 'revision'});
      final id = _nonEmptyString(reference, 'id');
      final revision = _positiveInt(reference, 'revision');
      if (!seen.add('$id@$revision')) {
        throw FormatException(
          'Duplicate option schema reference $id@$revision.',
        );
      }
    }
  }

  SourceVariant _variant(Object? value) {
    final map = _map(value, 'variant');
    _keys(
      map,
      const {
        'id',
        'revision',
        'labels',
        'sourceRuleIds',
        'optionSchemaId',
        'scheduleIds',
        'compatibilities',
        'validExample',
        'weekPlans',
        'phases',
        'assistancePlanIds',
        'conditioningDefinitionIds',
        'componentSelections',
        'optionRecipeId',
        'loadRoundingPolicy',
        'trainingMaxProgression',
      },
      optional: const {
        'weekPlans',
        'phases',
        'assistancePlanIds',
        'conditioningDefinitionIds',
        'componentSelections',
        'optionRecipeId',
        'loadRoundingPolicy',
        'trainingMaxProgression',
      },
    );
    if (map.containsKey('weekPlans') == map.containsKey('phases')) {
      throw const FormatException(
        'Variant requires exactly one of weekPlans or phases.',
      );
    }
    return SourceVariant(
      id: _string(map, 'id'),
      revision: _int(map, 'revision'),
      optionSchemaId: _reference(_map(map['optionSchemaId'], 'optionSchemaId')),
      optionRecipeId: map['optionRecipeId'] == null
          ? null
          : _reference(_map(map['optionRecipeId'], 'optionRecipeId')),
      scheduleIds: _list(map, 'scheduleIds')
          .map((value) => _reference(_map(value, 'reference')))
          .toList(growable: false),
      assistancePlanIds: map['assistancePlanIds'] == null
          ? const []
          : _list(map, 'assistancePlanIds')
                .map((value) => _reference(_map(value, 'reference')))
                .toList(growable: false),
      conditioningDefinitionIds: map['conditioningDefinitionIds'] == null
          ? const []
          : _list(map, 'conditioningDefinitionIds')
                .map((value) => _reference(_map(value, 'reference')))
                .toList(growable: false),
      weekPlans: map['weekPlans'] == null
          ? const []
          : _weekPlans(_list(map, 'weekPlans')),
      phases: map['phases'] == null
          ? const []
          : _list(map, 'phases')
                .map((value) {
                  final phase = _map(value, 'phase');
                  _keys(
                    phase,
                    const {
                      'id',
                      'repeatCount',
                      'weekPlans',
                      'trainingMaxProgressionStep',
                    },
                    optional: const {'trainingMaxProgressionStep'},
                  );
                  return CatalogPhase(
                    id: _string(phase, 'id'),
                    repeatCount: _int(phase, 'repeatCount'),
                    weekPlans: _weekPlans(_list(phase, 'weekPlans')),
                    trainingMaxProgressionStep:
                        phase['trainingMaxProgressionStep'] == null
                        ? 0
                        : _nonNegativeInt(phase, 'trainingMaxProgressionStep'),
                  );
                })
                .toList(growable: false),
      compatibilities: _map(map['compatibilities'], 'compatibilities'),
      loadRoundingPolicy: _loadRoundingPolicy(map['loadRoundingPolicy']),
      trainingMaxProgression: _trainingMaxProgression(
        map['trainingMaxProgression'],
      ),
      componentSelections: map['componentSelections'] == null
          ? const []
          : _list(map, 'componentSelections')
                .map((value) {
                  final selection = _map(value, 'componentSelection');
                  _keys(selection, const {
                    'parameterId',
                    'targetComponentId',
                    'choices',
                  });
                  final choices = _list(selection, 'choices')
                      .map((value) {
                        final choice = _map(value, 'componentSelectionChoice');
                        _keys(choice, const {'value', 'componentId'});
                        final choiceValue = choice['value'];
                        if (!_isJsonScalar(choiceValue)) {
                          throw const FormatException(
                            'Component choice value must be a JSON scalar.',
                          );
                        }
                        return SourceComponentSelectionChoice(
                          value: choiceValue!,
                          componentId: _reference(
                            _map(choice['componentId'], 'componentId'),
                          ),
                        );
                      })
                      .toList(growable: false);
                  if (choices.isEmpty) {
                    throw const FormatException(
                      'Component selection requires choices.',
                    );
                  }
                  return SourceComponentSelection(
                    parameterId: _string(selection, 'parameterId'),
                    targetComponentId: _reference(
                      _map(selection['targetComponentId'], 'targetComponentId'),
                    ),
                    choices: choices,
                  );
                })
                .toList(growable: false),
    );
  }

  LoadRoundingPolicy _loadRoundingPolicy(Object? value) {
    if (value == null) return LoadRoundingPolicy.nearest;
    if (value is! String ||
        !LoadRoundingPolicy.values.any((policy) => policy.name == value)) {
      throw const FormatException('loadRoundingPolicy must be nearest or up.');
    }
    return LoadRoundingPolicy.values.byName(value);
  }

  TrainingMaxProgression? _trainingMaxProgression(Object? value) {
    if (value == null) return null;
    final map = _map(value, 'trainingMaxProgression');
    _keys(map, const {'type', 'incrementCentiUnitsByUnit'});
    if (_string(map, 'type') != 'linear_phase_step') {
      throw FormatException(
        'Unknown trainingMaxProgression type ${map['type']}.',
      );
    }
    final units = _map(
      map['incrementCentiUnitsByUnit'],
      'incrementCentiUnitsByUnit',
    );
    _keys(units, const {'lb', 'kg'});
    const movementIds = {'overhead_press', 'bench_press', 'squat', 'deadlift'};
    final increments = <WeightUnit, Map<MovementId, int>>{};
    for (final unit in WeightUnit.values) {
      final byMovement = _map(
        units[unit.name],
        'incrementCentiUnitsByUnit.${unit.name}',
      );
      _keys(byMovement, movementIds);
      increments[unit] = Map.unmodifiable({
        for (final movementId in movementIds)
          MovementId(movementId): _positiveInt(byMovement, movementId),
      });
    }
    return LinearPhaseStepTrainingMaxProgression(
      incrementCentiUnitsByUnit: Map.unmodifiable(increments),
    );
  }

  List<CatalogWeekPlan> _weekPlans(List<Object?> values) => values
      .map((value) {
        final map = _map(value, 'weekPlan');
        _keys(map, const {'weekNumber', 'componentIds'});
        return CatalogWeekPlan(
          weekNumber: _int(map, 'weekNumber'),
          components: _list(map, 'componentIds')
              .map((value) => _reference(_map(value, 'reference')))
              .toList(growable: false),
        );
      })
      .toList(growable: false);

  BlockDefinition _block(Map<String, Object?> map) {
    _keys(
      map,
      const {'id', 'role', 'sets', 'movementId'},
      optional: const {'movementId'},
    );
    return BlockDefinition(
      id: _string(map, 'id'),
      role: _string(map, 'role'),
      movementId: map['movementId'] == null
          ? null
          : MovementId(_string(map, 'movementId')),
      sets: _list(map, 'sets')
          .map((value) {
            final set = _map(value, 'set');
            _keys(
              set,
              const {'repetitions', 'load', 'multiplicity'},
              optional: const {'multiplicity'},
            );
            final reps = _map(set['repetitions'], 'repetitions');
            final load = _map(set['load'], 'load');
            return PrescribedSetDefinition(
              repetitions: _repetitions(reps),
              load: _load(load),
              multiplicity: set['multiplicity'] == null
                  ? const FixedSetMultiplicity(1)
                  : _multiplicity(
                      _map(set['multiplicity'], 'set multiplicity'),
                    ),
            );
          })
          .toList(growable: false),
    );
  }

  MainWorkSemantics? _mainWorkSemantics(
    BlockDefinition block,
    Map<String, Object?> constraints,
  ) {
    if (!const {
      'main_work',
      'main work',
      'deload',
      'training_max_test',
    }.contains(block.role)) {
      return null;
    }
    if (block.sets.isEmpty) {
      throw const FormatException(
        'A main-work semantic block requires at least one prescribed set.',
      );
    }
    final setRoles = constraints.containsKey('setRoles')
        ? _mainWorkSetRoles(constraints['setRoles'], block.sets.length)
        : _defaultMainWorkSetRoles(block.sets.length);
    _validateMainWorkSetRoles(setRoles);
    final topIndex = setRoles.indexOf(MainWorkSetRole.top);
    final policyValue = constraints['lastSet'];
    final lastSetPolicy = policyValue == null
        ? _derivedLastSetPolicy(
            block.sets[topIndex < 0 ? block.sets.length - 1 : topIndex],
          )
        : switch (policyValue) {
            'amrapPermission' => MainWorkLastSetPolicy.amrapPermitted,
            'fixed' => MainWorkLastSetPolicy.fixed,
            _ => throw FormatException(
              'Unknown main-work last-set policy $policyValue.',
            ),
          };
    final waveValue = constraints['weekRole'];
    final waveRole = waveValue == null
        ? null
        : switch (waveValue) {
            'five' => MainWorkWaveRole.five,
            'three' => MainWorkWaveRole.three,
            'fiveThreeOne' => MainWorkWaveRole.fiveThreeOne,
            'deload' => MainWorkWaveRole.deload,
            'test' || 'trainingMaxTest' => MainWorkWaveRole.test,
            _ => throw FormatException(
              'Unknown main-work week role $waveValue.',
            ),
          };
    return MainWorkSemantics(
      waveRole: waveRole,
      lastSetPolicy: lastSetPolicy,
      setRoles: List.unmodifiable(setRoles),
    );
  }

  List<MainWorkSetRole?> _mainWorkSetRoles(Object? value, int setCount) {
    if (value is! List<Object?>) {
      throw const FormatException('setRoles must be a list.');
    }
    if (value.length != setCount) {
      throw const FormatException(
        'setRoles must contain one entry per prescribed set.',
      );
    }
    return [
      for (final role in value)
        switch (role) {
          null => null,
          'first' => MainWorkSetRole.first,
          'second' => MainWorkSetRole.second,
          'top' => MainWorkSetRole.top,
          'heavySingle' || 'heavy_single' => MainWorkSetRole.heavySingle,
          _ => throw FormatException('Unknown main-work set role $role.'),
        },
    ];
  }

  List<MainWorkSetRole?> _defaultMainWorkSetRoles(int setCount) => [
    for (var index = 0; index < setCount; index++)
      switch ((setCount, index)) {
        (1, 0) => MainWorkSetRole.top,
        (2, 0) => MainWorkSetRole.first,
        (2, 1) => MainWorkSetRole.top,
        (_, 0) => MainWorkSetRole.first,
        (_, 1) => MainWorkSetRole.second,
        (_, 2) => MainWorkSetRole.top,
        _ => null,
      },
  ];

  void _validateMainWorkSetRoles(List<MainWorkSetRole?> roles) {
    for (final role in const [
      MainWorkSetRole.first,
      MainWorkSetRole.second,
      MainWorkSetRole.top,
    ]) {
      if (roles.where((candidate) => candidate == role).length > 1) {
        throw FormatException('Main-work set role ${role.name} is duplicated.');
      }
    }
  }

  MainWorkLastSetPolicy _derivedLastSetPolicy(
    PrescribedSetDefinition definition,
  ) => switch (definition.repetitions) {
    AmrapRepetitions() ||
    PlusSetRepetitions() => MainWorkLastSetPolicy.amrapPermitted,
    _ => MainWorkLastSetPolicy.fixed,
  };

  RepetitionPrescription _repetitions(Map<String, Object?> map) {
    switch (_string(map, 'type')) {
      case 'fixed':
        _keys(map, const {'type', 'count'});
        return FixedRepetitions(_positiveInt(map, 'count'));
      case 'parameterized_fixed':
        _keys(map, const {
          'type',
          'parameterId',
          'default',
          'minimum',
          'maximum',
        });
        final parameter = _boundedIntegerParameter(
          map,
          'parameterized fixed repetitions',
        );
        return ParameterizedFixedRepetitions(
          parameterId: parameter.parameterId,
          defaultValue: parameter.defaultValue,
          minimum: parameter.minimum,
          maximum: parameter.maximum,
        );
      case 'range':
        _keys(map, const {'type', 'minimum', 'maximum'});
        return RepetitionRange(_int(map, 'minimum'), _int(map, 'maximum'));
      case 'total':
        _keys(map, const {'type', 'total'});
        return TotalRepetitions(_int(map, 'total'));
      case 'amrap':
        _keys(map, const {'type', 'minimum'}, optional: const {'minimum'});
        return AmrapRepetitions(
          minimum: map['minimum'] == null ? null : _int(map, 'minimum'),
        );
      case 'joker':
        _keys(map, const {'type'});
        return const JokerRepetitions();
      case 'percentage_thresholds':
        _keys(map, const {'type', 'thresholds'});
        final thresholds = _list(map, 'thresholds')
            .map((value) {
              final threshold = _map(value, 'percentageThreshold');
              _keys(threshold, const {'maximumBasisPoints', 'count'});
              return PercentageRepetitionThreshold(
                maximumBasisPoints: _positiveInt(
                  threshold,
                  'maximumBasisPoints',
                ),
                count: _positiveInt(threshold, 'count'),
              );
            })
            .toList(growable: false);
        if (thresholds.isEmpty) {
          throw const FormatException('percentage_thresholds cannot be empty.');
        }
        for (var index = 1; index < thresholds.length; index++) {
          if (thresholds[index].maximumBasisPoints <=
              thresholds[index - 1].maximumBasisPoints) {
            throw const FormatException(
              'percentage_thresholds must be strictly ascending.',
            );
          }
        }
        return PercentageThresholdRepetitions(List.unmodifiable(thresholds));
      default:
        throw FormatException("Unknown repetition type ${map['type']}.");
    }
  }

  SetMultiplicity _multiplicity(Map<String, Object?> map) {
    switch (_string(map, 'type')) {
      case 'fixed':
        _keys(map, const {'type', 'count'});
        return FixedSetMultiplicity(_positiveInt(map, 'count'));
      case 'parameterized':
        _keys(map, const {
          'type',
          'parameterId',
          'default',
          'minimum',
          'maximum',
        });
        final parameter = _boundedIntegerParameter(
          map,
          'parameterized set multiplicity',
        );
        return ParameterizedSetMultiplicity(
          parameterId: parameter.parameterId,
          defaultValue: parameter.defaultValue,
          minimum: parameter.minimum,
          maximum: parameter.maximum,
        );
      default:
        throw FormatException("Unknown set multiplicity type ${map['type']}.");
    }
  }

  ({String parameterId, int defaultValue, int minimum, int maximum})
  _boundedIntegerParameter(Map<String, Object?> map, String label) {
    final parameterId = _nonEmptyString(map, 'parameterId');
    final defaultValue = _positiveInt(map, 'default');
    final minimum = _positiveInt(map, 'minimum');
    final maximum = _positiveInt(map, 'maximum');
    if (maximum < minimum || defaultValue < minimum || defaultValue > maximum) {
      throw FormatException('$label requires minimum <= default <= maximum.');
    }
    return (
      parameterId: parameterId,
      defaultValue: defaultValue,
      minimum: minimum,
      maximum: maximum,
    );
  }

  LoadPrescription _load(Map<String, Object?> map) {
    switch (_string(map, 'type')) {
      case 'training_max_percentage':
        _keys(map, const {'type', 'basisPoints'});
        return TrainingMaxPercentageLoad(Percentage(_int(map, 'basisPoints')));
      case 'parameterized_training_max_percentage':
        _keys(map, const {
          'type',
          'parameterId',
          'defaultBasisPoints',
          'minimumBasisPoints',
          'maximumBasisPoints',
        });
        return ParameterizedTrainingMaxPercentageLoad(
          parameterId: _nonEmptyString(map, 'parameterId'),
          defaultValue: Percentage(_int(map, 'defaultBasisPoints')),
          minimum: Percentage(_int(map, 'minimumBasisPoints')),
          maximum: Percentage(_int(map, 'maximumBasisPoints')),
        );
      case 'one_rep_max_percentage':
        _keys(map, const {'type', 'basisPoints'});
        return OneRepMaxPercentageLoad(Percentage(_int(map, 'basisPoints')));
      case 'fixed':
        _keys(map, const {'type', 'centiUnits', 'unit'});
        return FixedLoad(
          Weight(
            _int(map, 'centiUnits'),
            WeightUnit.values.byName(_string(map, 'unit')),
          ),
        );
      case 'bodyweight':
        _keys(map, const {'type'});
        return const BodyweightLoad();
      case 'unloaded':
        _keys(map, const {'type'});
        return const Unloaded();
      case 'relative_set':
        _keys(map, const {'type', 'position', 'multiplierBasisPoints'});
        return RelativeSetLoad(
          position: RelativeSetPosition.values.byName(_string(map, 'position')),
          multiplierBasisPoints: _int(map, 'multiplierBasisPoints'),
        );
      case 'warm_up_base':
        _keys(
          map,
          const {'type', 'region', 'centiUnits', 'unit'},
          optional: const {'region', 'centiUnits', 'unit'},
        );
        final hasRegion = map.containsKey('region');
        final hasFixed =
            map.containsKey('centiUnits') || map.containsKey('unit');
        if (hasRegion == hasFixed ||
            (hasFixed &&
                (!map.containsKey('centiUnits') || !map.containsKey('unit')))) {
          throw const FormatException(
            'warm_up_base requires exactly region or centiUnits/unit.',
          );
        }
        return hasRegion
            ? WarmUpBaseLoad(
                WarmUpBodyRegion.values.byName(_string(map, 'region')),
              )
            : WarmUpBaseLoad.fixed(
                Weight(
                  _positiveInt(map, 'centiUnits'),
                  WeightUnit.values.byName(_string(map, 'unit')),
                ),
              );
      case 'main_work_set_plus':
        _keys(map, const {'type', 'cumulativeIncreaseBasisPoints'});
        return MainWorkSetPlusLoad(
          _positiveInt(map, 'cumulativeIncreaseBasisPoints'),
        );
      case 'training_max_ramp':
        _keys(
          map,
          const {
            'type',
            'anchor',
            'stepBasisPoints',
            'lowerBound',
            'lowerBoundStepFractionBasisPoints',
            'anchorMultiplierBasisPoints',
            'maximumExclusiveBasisPoints',
          },
          optional: const {
            'lowerBound',
            'lowerBoundStepFractionBasisPoints',
            'anchorMultiplierBasisPoints',
            'maximumExclusiveBasisPoints',
          },
        );
        final anchor = switch (_string(map, 'anchor')) {
          'before_main_work' => TrainingMaxRampAnchor.beforeMainWork,
          'warm_up_base' => TrainingMaxRampAnchor.warmUpBase,
          final value => throw FormatException('Unknown ramp anchor $value.'),
        };
        if (map['lowerBound'] != null &&
            _string(map, 'lowerBound') != 'warm_up_base_plus_step_fraction') {
          throw FormatException(
            'Unknown ramp lowerBound ${map['lowerBound']}.',
          );
        }
        final lowerFraction = map['lowerBoundStepFractionBasisPoints'] == null
            ? null
            : _positiveInt(map, 'lowerBoundStepFractionBasisPoints');
        final anchorMultiplier = map['anchorMultiplierBasisPoints'] == null
            ? null
            : _positiveInt(map, 'anchorMultiplierBasisPoints');
        final maximum = map['maximumExclusiveBasisPoints'] == null
            ? null
            : _positiveInt(map, 'maximumExclusiveBasisPoints');
        if ((anchor == TrainingMaxRampAnchor.beforeMainWork &&
                (map['lowerBound'] == null ||
                    lowerFraction == null ||
                    anchorMultiplier != null ||
                    maximum != null)) ||
            (anchor == TrainingMaxRampAnchor.warmUpBase &&
                (map['lowerBound'] != null ||
                    lowerFraction != null ||
                    anchorMultiplier == null ||
                    maximum == null))) {
          throw const FormatException(
            'Ramp parameters do not match the selected anchor.',
          );
        }
        return TrainingMaxRampLoad(
          anchor: anchor,
          stepBasisPoints: _positiveInt(map, 'stepBasisPoints'),
          lowerBoundStepFractionBasisPoints: lowerFraction,
          anchorMultiplierBasisPoints: anchorMultiplier,
          maximumExclusiveBasisPoints: maximum,
        );
      default:
        throw FormatException("Unknown load type ${map['type']}.");
    }
  }

  Map<String, Object?> _root(
    String source,
    String kind, {
    Set<String> optional = const {},
  }) {
    final root = _map(jsonDecode(source), 'root');
    _keys(root, {'schemaVersion', 'kind', kind}, optional: optional);
    if (_int(root, 'schemaVersion') != 1 || _string(root, 'kind') != kind) {
      throw FormatException('Expected schemaVersion 1 $kind document.');
    }
    return root;
  }

  ComponentReference _reference(Map<String, Object?> map) {
    _keys(map, const {'id', 'revision'});
    return ComponentReference(_string(map, 'id'), _int(map, 'revision'));
  }

  ComponentReference _recordReference(Map<String, Object?> map) =>
      ComponentReference(_string(map, 'id'), _int(map, 'revision'));

  CycleScheduleMode _scheduleMode(Map<String, Object?> map) =>
      switch (_string(map, 'type')) {
        'fixed' => CycleScheduleMode.fixed,
        'rotating' => CycleScheduleMode.rotating,
        'multiMovement' => CycleScheduleMode.multiMovement,
        'finite' => CycleScheduleMode.finite,
        final value => throw FormatException('Unknown schedule type $value.'),
      };

  SessionBlockOrder _sessionBlockOrder(Object? value) {
    if (value == null) return SessionBlockOrder.componentMajor;
    if (value is! String ||
        !SessionBlockOrder.values.any((order) => order.name == value)) {
      throw const FormatException(
        'sessionBlockOrder must be componentMajor or movementMajor.',
      );
    }
    return SessionBlockOrder.values.byName(value);
  }

  void _validateScheduleCadence(
    CycleScheduleMode type,
    List<SourceSession> sessions,
    int sessionsPerWeek,
  ) {
    if (sessionsPerWeek > 7) {
      throw const FormatException('sessionsPerWeek must be from 1 to 7.');
    }
    switch (type) {
      case CycleScheduleMode.fixed || CycleScheduleMode.multiMovement:
        if (sessionsPerWeek != sessions.length) {
          throw FormatException(
            'sessionsPerWeek must equal the session count for ${type.name} schedules.',
          );
        }
      case CycleScheduleMode.rotating:
        if (sessionsPerWeek > sessions.length) {
          throw const FormatException(
            'sessionsPerWeek cannot exceed the session count for rotating schedules.',
          );
        }
      case CycleScheduleMode.finite:
        break;
    }
  }

  static Map<String, Object?> _map(Object? value, String label) =>
      value is Map<String, Object?>
      ? value
      : throw FormatException('$label must be an object.');
  static List<Object?> _list(Map<String, Object?> map, String key) =>
      map[key] is List<Object?>
      ? map[key]! as List<Object?>
      : throw FormatException('$key must be a list.');
  static String _string(Map<String, Object?> map, String key) =>
      map[key] is String
      ? map[key]! as String
      : throw FormatException('$key must be a string.');
  static int _int(Map<String, Object?> map, String key) => map[key] is int
      ? map[key]! as int
      : throw FormatException('$key must be an integer.');
  static bool _bool(Map<String, Object?> map, String key) => map[key] is bool
      ? map[key]! as bool
      : throw FormatException('$key must be a boolean.');
  static int _positiveInt(Map<String, Object?> map, String key) {
    final value = _int(map, key);
    if (value <= 0) throw FormatException('$key must be positive.');
    return value;
  }

  static int _nonNegativeInt(Map<String, Object?> map, String key) {
    final value = _int(map, key);
    if (value < 0) {
      throw FormatException('$key must be non-negative.');
    }
    return value;
  }

  static String _nonEmptyString(Map<String, Object?> map, String key) {
    final value = _string(map, key);
    if (value.trim().isEmpty) throw FormatException('$key cannot be empty.');
    return value;
  }

  static List<String> _strings(Map<String, Object?> map, String key) =>
      _list(map, key)
          .map(
            (value) => value is String
                ? value
                : throw FormatException('$key values must be strings.'),
          )
          .toList();
  static void _keys(
    Map<String, Object?> map,
    Set<String> allowed, {
    Set<String> optional = const {},
  }) {
    final allAllowed = {...allowed, ...optional};
    final unknown = map.keys.toSet().difference(allAllowed);
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown key ${unknown.first}.');
    }
    final missing = allowed.difference(map.keys.toSet()).difference(optional);
    if (missing.isNotEmpty) {
      throw FormatException('Missing key ${missing.first}.');
    }
  }

  static void _enumKeys(Map<String, Object?> map, Set<String> allowed) {
    final unknown = map.keys.toSet().difference(allowed);
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown enum key ${unknown.first}.');
    }
  }

  static bool _isJsonScalar(Object? value) =>
      value is String || value is num || value is bool;
}
