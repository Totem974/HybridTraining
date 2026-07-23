import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Beyond BBB composes shared blocks across two cycles and a deload', () {
    final document =
        jsonDecode(
              File(
                'catalog_src/beyond/templates/bbb.v1.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final template =
        (document['templates']! as List<Object?>).single
            as Map<String, Object?>;
    final variants = template['variants']! as List<Object?>;
    final variant = variants
        .cast<Map<String, Object?>>()
        .where((candidate) => candidate['id'] == 'same_lift_5x10_50_two_cycles')
        .single;
    final phases = variant['phases']! as List<Object?>;
    final plans = phases
        .expand(
          (phase) =>
              ((phase! as Map<String, Object?>)['weekPlans']! as List<Object?>),
        )
        .toList();

    expect(plans, hasLength(7));
    expect(variant.containsKey('componentIds'), isFalse);
    expect(jsonEncode(variant), isNot(contains('5x10 @')));
    expect(jsonEncode(variant), contains('supplemental_bbb_original_5x10_50'));
    expect(
      (variant['compatibilities']!
          as Map<String, Object?>)['trainingMaxCheckpointAfterWeek'],
      3,
    );
    expect(
      variants
          .cast<Map<String, Object?>>()
          .map((candidate) => candidate['id'])
          .toSet(),
      hasLength(variants.length),
    );
  });

  test(
    'Beyond BBB variations preserve their exact sourced weekly prescriptions',
    () {
      final templateDocument =
          jsonDecode(
                File(
                  'catalog_src/beyond/templates/bbb.v1.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final componentDocument =
          jsonDecode(
                File(
                  'catalog_src/beyond/templates/components/bbb_variations.v1.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final template =
          (templateDocument['templates']! as List<Object?>).single
              as Map<String, Object?>;
      final variants = <String, Map<String, Object?>>{
        for (final raw in template['variants']! as List<Object?>)
          (raw! as Map<String, Object?>)['id']! as String:
              raw as Map<String, Object?>,
      };
      final components = {
        for (final raw in componentDocument['components']! as List<Object?>)
          (raw! as Map<String, Object?>)['id']: raw as Map<String, Object?>,
      };

      void expectPrescription(String componentId, int reps, int basisPoints) {
        final block =
            (components[componentId]!['block']! as Map<String, Object?>);
        final sets = block['sets']! as List<Object?>;
        expect(sets, hasLength(5));
        for (final rawSet in sets) {
          final set = rawSet! as Map<String, Object?>;
          expect((set['repetitions']! as Map<String, Object?>)['count'], reps);
          expect(
            (set['load']! as Map<String, Object?>)['basisPoints'],
            basisPoints,
          );
        }
      }

      expect(
        variants.keys,
        containsAll({
          'variation_i_5x10_wave',
          'variation_ii_descending_volume',
        }),
      );
      expectPrescription('beyond_bbb_variation_i_5x10_65', 10, 6500);
      expectPrescription('beyond_bbb_variation_i_5x10_70', 10, 7000);
      expectPrescription('beyond_bbb_variation_i_5x10_75', 10, 7500);
      expectPrescription('beyond_bbb_variation_ii_5x10_65', 10, 6500);
      expectPrescription('beyond_bbb_variation_ii_5x8_70', 8, 7000);
      expectPrescription('beyond_bbb_variation_ii_5x5_75', 5, 7500);

      List<String> supplementalSequence(String variantId) {
        final variant = variants[variantId]!;
        return (variant['phases']! as List<Object?>)
            .expand(
              (phase) =>
                  (phase! as Map<String, Object?>)['weekPlans']!
                      as List<Object?>,
            )
            .map((week) => (week! as Map<String, Object?>)['componentIds']!)
            .cast<List<Object?>>()
            .map(
              (references) => references
                  .map(
                    (item) => (item! as Map<String, Object?>)['id'] as String,
                  )
                  .firstWhere(
                    (id) => id.startsWith('beyond_bbb_variation_'),
                    orElse: () => 'deload',
                  ),
            )
            .toList(growable: false);
      }

      expect(supplementalSequence('variation_i_5x10_wave'), [
        'beyond_bbb_variation_i_5x10_65',
        'beyond_bbb_variation_i_5x10_70',
        'beyond_bbb_variation_i_5x10_75',
        'beyond_bbb_variation_i_5x10_65',
        'beyond_bbb_variation_i_5x10_70',
        'beyond_bbb_variation_i_5x10_75',
        'deload',
      ]);
      expect(supplementalSequence('variation_ii_descending_volume'), [
        'beyond_bbb_variation_ii_5x10_65',
        'beyond_bbb_variation_ii_5x8_70',
        'beyond_bbb_variation_ii_5x5_75',
        'beyond_bbb_variation_ii_5x10_65',
        'beyond_bbb_variation_ii_5x8_70',
        'beyond_bbb_variation_ii_5x5_75',
        'deload',
      ]);
    },
  );
}
