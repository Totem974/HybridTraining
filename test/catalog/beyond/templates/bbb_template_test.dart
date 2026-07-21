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
    final variant =
        (template['variants']! as List<Object?>).single as Map<String, Object?>;
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
  });
}
