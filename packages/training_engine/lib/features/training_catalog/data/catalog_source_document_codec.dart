import 'dart:convert';

import '../../cycle_generation/domain/catalog_cycle_primitives.dart';
import '../../cycle_generation/domain/cycle_contract.dart';
import '../../cycle_generation/domain/cycle_execution_options.dart';

final class SourceComponent {
  const SourceComponent({
    required this.reference,
    required this.block,
    required this.constraints,
    required this.compatibilities,
  });
  final ComponentReference reference;
  final BlockDefinition block;
  final Map<String, Object?> constraints;
  final Map<String, Object?> compatibilities;
}

final class SourceSchedule {
  const SourceSchedule({required this.reference, required this.sessions});
  final ComponentReference reference;
  final List<SourceSession> sessions;
}

final class SourceSession {
  const SourceSession({required this.id, required this.movementIds});
  final String id;
  final List<String> movementIds;
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

final class SourceTemplate {
  const SourceTemplate({
    required this.id,
    required this.revision,
    required this.variants,
    required this.surface,
    this.isDefault = false,
  });
  final String id;
  final int revision;
  final List<SourceVariant> variants;
  final TemplateSurface surface;
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
          _keys(map, const {
            'id',
            'revision',
            'role',
            'labels',
            'sourceRuleIds',
            'parameterSchemaIds',
            'constraints',
            'compatibilities',
            'block',
          });
          return SourceComponent(
            reference: _recordReference(map),
            block: _block(_map(map['block'], 'block')),
            constraints: _map(map['constraints'], 'constraints'),
            compatibilities: _map(map['compatibilities'], 'compatibilities'),
          );
        })
        .toList(growable: false);
  }

  List<SourceSchedule> decodeSchedules(String source) {
    final root = _root(source, 'schedules');
    return _list(root, 'schedules')
        .map((value) {
          final map = _map(value, 'schedule');
          _keys(map, const {
            'id',
            'revision',
            'labels',
            'sourceRuleIds',
            'type',
            'sessions',
          });
          return SourceSchedule(
            reference: _recordReference(map),
            sessions: _list(map, 'sessions')
                .map((value) {
                  final session = _map(value, 'session');
                  _keys(session, const {'id', 'role', 'movementIds'});
                  return SourceSession(
                    id: _string(session, 'id'),
                    movementIds: _strings(session, 'movementIds'),
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  List<SourceTemplate> decodeTemplates(String source) {
    final root = _root(source, 'templates');
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
          _keys(map, const {'id', 'revision', 'sourceRuleIds', 'parameters'});
          for (final value in _list(map, 'parameters')) {
            _keys(
              _map(value, 'parameter'),
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
              optional: const {'presentationGroup', 'labelEn', 'labelFr'},
            );
          }
          return map;
        })
        .toList(growable: false);
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
      },
      optional: const {
        'weekPlans',
        'phases',
        'assistancePlanIds',
        'conditioningDefinitionIds',
        'componentSelections',
        'optionRecipeId',
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
      weekPlans: map['weekPlans'] == null
          ? const []
          : _weekPlans(_list(map, 'weekPlans')),
      phases: map['phases'] == null
          ? const []
          : _list(map, 'phases')
                .map((value) {
                  final phase = _map(value, 'phase');
                  _keys(phase, const {'id', 'repeatCount', 'weekPlans'});
                  return CatalogPhase(
                    id: _string(phase, 'id'),
                    repeatCount: _int(phase, 'repeatCount'),
                    weekPlans: _weekPlans(_list(phase, 'weekPlans')),
                  );
                })
                .toList(growable: false),
      compatibilities: _map(map['compatibilities'], 'compatibilities'),
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
            _keys(set, const {'repetitions', 'load'});
            final reps = _map(set['repetitions'], 'repetitions');
            final load = _map(set['load'], 'load');
            return PrescribedSetDefinition(
              repetitions: _repetitions(reps),
              load: _load(load),
            );
          })
          .toList(growable: false),
    );
  }

  RepetitionPrescription _repetitions(Map<String, Object?> map) {
    switch (_string(map, 'type')) {
      case 'fixed':
        _keys(map, const {'type', 'count'});
        return FixedRepetitions(_int(map, 'count'));
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
        _keys(map, const {'type', 'region'});
        return WarmUpBaseLoad(
          WarmUpBodyRegion.values.byName(_string(map, 'region')),
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

  Map<String, Object?> _root(String source, String kind) {
    final root = _map(jsonDecode(source), 'root');
    _keys(root, {'schemaVersion', 'kind', kind});
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
