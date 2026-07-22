import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final recipesDocument = _read(
    'catalog_src/shared/cycle_option_recipes_v1.json',
  );
  final componentsDocument = _read(
    'catalog_src/shared/cycle_components_v1.json',
  );
  final recipes = _records(recipesDocument, 'cycleOptionRecipes');
  final components = _records(componentsDocument, 'components');
  final componentById = {
    for (final component in components) component['id'] as String: component,
  };
  final recipe = recipes.singleWhere(
    (item) => item['id'] == 'classic_additional_options',
  );

  test(
    'recipe document is v1, unique and all leaves reference real components',
    () {
      expect(recipesDocument['schemaVersion'], 1);
      expect(recipesDocument['kind'], 'cycleOptionRecipes');
      expect(
        recipes.map((item) => item['id']).toSet(),
        hasLength(recipes.length),
      );
      for (final leaf in _recipeLeaves(recipe)) {
        final hasComponents = leaf.containsKey('componentIds');
        final hasUnits = leaf.containsKey('byUnit');
        expect(hasComponents ^ hasUnits, isTrue, reason: '$leaf');
        final references = hasComponents
            ? _maps(leaf['componentIds'])
            : _map(leaf['byUnit']).values.expand(_maps);
        for (final reference in references) {
          expect(reference['revision'], 1);
          expect(componentById, contains(reference['id']));
        }
      }
    },
  );

  test('Original and Beyond warm-ups remain distinct data recipes', () {
    final warmUp = _map(recipe['warmUp']);
    expect(_ids(_map(warmUp['original'])['componentIds']), [
      'warmup_original_40_50_60',
    ]);
    expect(_prescription(componentById['warmup_original_40_50_60']!), [
      'fixed:5@training_max_percentage:4000',
      'fixed:5@training_max_percentage:5000',
      'fixed:3@training_max_percentage:6000',
    ]);

    final beyond = _map(warmUp['beyond']);
    expect(beyond, isNot(contains('byUnit')));
    expect(_ids(beyond['componentIds']).toSet(), {
      'warmup_beyond_ramp_upper',
      'warmup_beyond_ramp_lower',
    });
    final component = componentById['warmup_beyond_ramp_upper']!;
    final sets = _sets(component);
    expect(_map(sets[0]['repetitions']), {'type': 'fixed', 'count': 10});
    expect(_map(sets[0]['load']), {'type': 'unloaded'});
    expect(_map(sets[1]['repetitions']), {'type': 'fixed', 'count': 5});
    expect(_map(sets[1]['load']), {
      'type': 'warm_up_base',
      'region': 'upperBody',
    });
    expect(_map(sets[2]['repetitions']), {
      'type': 'percentage_thresholds',
      'thresholds': [
        {'maximumBasisPoints': 5000, 'count': 5},
        {'maximumBasisPoints': 10000, 'count': 3},
      ],
    });
    expect(_map(sets[2]['load']), {
      'type': 'training_max_ramp',
      'anchor': 'before_main_work',
      'stepBasisPoints': 1000,
      'lowerBound': 'warm_up_base_plus_step_fraction',
      'lowerBoundStepFractionBasisPoints': 2500,
    });
  });

  test('Joker declares six cumulative steps without inventing repetitions', () {
    final joker = _map(recipe['joker']);
    expect(joker['blockId'], 'joker');
    final steps = _maps(joker['steps']);
    expect(steps.map((step) => step['cumulativeIncreaseBasisPoints']), [
      500,
      1000,
      1500,
      2000,
      2500,
      3000,
    ]);
    for (final step in steps) {
      expect(_map(step['repetitions']), {'type': 'joker'});
      expect(_map(step['repetitions']), isNot(contains('count')));
    }
  });

  test('Deload types 1 through 5 preserve exact source prescriptions', () {
    final deload = _map(recipe['deload']);
    final expected = <String, List<String>>{
      'type1': [
        'fixed:5@training_max_percentage:4000',
        'fixed:5@training_max_percentage:5000',
        'fixed:5@training_max_percentage:6000',
      ],
      'type2': [
        'fixed:5@training_max_percentage:5000',
        'fixed:5@training_max_percentage:6000',
        'fixed:5@training_max_percentage:7000',
      ],
      'type3': [
        'fixed:3@training_max_percentage:6500',
        'fixed:3@training_max_percentage:7600',
        'fixed:3@training_max_percentage:8500',
      ],
      'type4': [
        'fixed:10@training_max_percentage:4000',
        'fixed:8@training_max_percentage:5000',
        'fixed:6@training_max_percentage:6000',
      ],
      'type5': [
        'fixed:10@training_max_percentage:5000',
        'fixed:8@training_max_percentage:6000',
        'fixed:6@training_max_percentage:7000',
      ],
    };
    for (final entry in expected.entries) {
      final component =
          componentById[_ids(_map(deload[entry.key])['componentIds']).single]!;
      expect(_prescription(component), entry.value, reason: entry.key);
    }
  });

  test('High Intensity declares exact kg/lb and upper/lower overlays', () {
    final high = _map(_map(recipe['deload'])['highIntensity']);
    final byUnit = _map(high['byUnit']);
    expect(byUnit.keys.toSet(), {'kg', 'lb'});
    final expectedBases = {
      'deload_high_intensity_lb_upper': ('lb', 9500),
      'deload_high_intensity_lb_lower': ('lb', 13500),
      'deload_high_intensity_kg_upper': ('kg', 4500),
      'deload_high_intensity_kg_lower': ('kg', 6000),
    };
    for (final entry in expectedBases.entries) {
      final component = componentById[entry.key]!;
      final sets = _sets(component);
      expect(_map(sets[0]['repetitions']), {'type': 'fixed', 'count': 10});
      expect(_map(sets[0]['load']), {'type': 'unloaded'});
      expect(_map(sets[1]['repetitions']), {'type': 'fixed', 'count': 5});
      expect(_map(sets[1]['load']), {
        'type': 'fixed',
        'centiUnits': entry.value.$2,
        'unit': entry.value.$1,
      });
      expect(_map(sets[2]['load']), {
        'type': 'training_max_ramp',
        'anchor': 'warm_up_base',
        'anchorMultiplierBasisPoints': 11000,
        'stepBasisPoints': 1000,
        'maximumExclusiveBasisPoints': 9500,
      });
      expect(_map(sets[2]['repetitions']), {
        'type': 'percentage_thresholds',
        'thresholds': [
          {'maximumBasisPoints': 8000, 'count': 3},
          {'maximumBasisPoints': 10000, 'count': 1},
        ],
      });
      expect(_map(sets[3]['repetitions']), {'type': 'fixed', 'count': 1});
      expect(_map(sets[3]['load']), {
        'type': 'training_max_percentage',
        'basisPoints': 10000,
      });
    }
    expect(_ids(byUnit['kg']).toSet(), {
      'deload_high_intensity_kg_upper',
      'deload_high_intensity_kg_lower',
    });
    expect(_ids(byUnit['lb']).toSet(), {
      'deload_high_intensity_lb_upper',
      'deload_high_intensity_lb_lower',
    });
  });

  test('every public Classic and extended variant references the recipe', () {
    for (final path in [
      'catalog_src/classic/templates.json',
      'catalog_src/classic/extended/templates.json',
    ]) {
      final templates = _records(_read(path), 'templates');
      for (final variant in templates.expand(
        (template) => _maps(template['variants']),
      )) {
        expect(_map(variant['optionRecipeId']), {
          'id': 'classic_additional_options',
          'revision': 1,
        }, reason: '$path ${variant['id']}');
      }
    }
  });
}

Iterable<Map<String, Object?>> _recipeLeaves(
  Map<String, Object?> recipe,
) sync* {
  yield* _map(recipe['warmUp']).values.map(_map);
  yield* _map(recipe['deload']).values.map(_map);
}

List<Map<String, Object?>> _sets(Map<String, Object?> component) =>
    _maps(_map(component['block'])['sets']);

List<String> _prescription(Map<String, Object?> component) => _sets(component)
    .map((set) {
      final repetitions = _map(set['repetitions']);
      final load = _map(set['load']);
      return '${repetitions['type']}:${repetitions['count']}@${load['type']}:${load['basisPoints']}';
    })
    .toList(growable: false);

List<String> _ids(Object? value) =>
    _maps(value).map((item) => item['id'] as String).toList(growable: false);

Map<String, Object?> _read(String path) =>
    (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, Object?>();

List<Map<String, Object?>> _records(
  Map<String, Object?> document,
  String key,
) => _maps(document[key]);

List<Map<String, Object?>> _maps(Object? value) =>
    (value as List).map(_map).toList(growable: false);

Map<String, Object?> _map(Object? value) =>
    (value as Map).cast<String, Object?>();
