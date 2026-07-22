import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final document = _read('catalog_src/classic/templates.json');
  final templates = (document['templates']! as List).cast<Map>();

  Map template(String id) => templates.singleWhere((item) => item['id'] == id);
  Map variant(String templateId, String variantId) =>
      (template(templateId)['variants']! as List).cast<Map>().singleWhere(
        (item) => item['id'] == variantId,
      );

  test('classic source-backed families remain separate canonical templates', () {
    expect(
      templates.map((item) => item['id']),
      containsAll(<String>[
        'classic_531',
        'classic_boring_but_big',
        'classic_triumvirate',
        'classic_periodization_bible',
        'classic_bodyweight',
        'classic_simplest_strength',
      ]),
    );
    for (final id in <String>[
      'classic_531',
      'classic_boring_but_big',
      'classic_triumvirate',
      'classic_periodization_bible',
      'classic_bodyweight',
      'classic_simplest_strength',
    ]) {
      expect(template(id)['sourceRuleIds'], isNotEmpty, reason: id);
      expect(template(id)['variants'], isNotEmpty, reason: id);
    }
  });

  test('BBB exposes only the component-backed same-lift recipe', () {
    final bbb = template('classic_boring_but_big');
    expect((bbb['variants']! as List).cast<Map>().map((item) => item['id']), [
      'same_lift_5x10',
    ]);
    final original = variant('classic_boring_but_big', 'same_lift_5x10');
    expect(original['labels'], {
      'en': 'Same lift, 5 x 10 at 50%',
      'fr': 'Même mouvement, 5 × 10 à 50 %',
    });
    expect(
      _scheduleIds(original),
      {'schedule_four_day_fixed', 'schedule_three_day_rotating'},
    );
    final components = (original['weekPlans']! as List)
        .cast<Map>()
        .expand((week) => (week['componentIds']! as List).cast<Map>())
        .map((reference) => reference['id']);
    expect(components, contains('supplemental_bbb_original_5x10_50'));
    expect(
      components.where((id) => '$id'.contains('bbb')).toSet(),
      {'supplemental_bbb_original_5x10_50'},
    );
  });

  test('source-default assistance templates offer three or four days', () {
    for (final entry in <(String, String)>[
      ('classic_triumvirate', 'four_day'),
      ('classic_periodization_bible', 'four_day'),
      ('classic_bodyweight', 'four_day'),
    ]) {
      expect(
        _scheduleIds(variant(entry.$1, entry.$2)),
        {'schedule_four_day_fixed', 'schedule_three_day_rotating'},
        reason: entry.$1,
      );
    }
  });

  test('Bodyweight uses its own volume schema without changing assistance', () {
    final bodyweight = variant('classic_bodyweight', 'four_day');
    expect(
      (bodyweight['optionSchemaId']! as Map)['id'],
      'classic_bodyweight_options',
    );
    expect(
      (bodyweight['assistancePlanIds']! as List).cast<Map>().single['id'],
      'original_bodyweight',
    );
  });

  test('French labels contain no legacy encoding artifacts', () {
    final text = jsonEncode(document);
    expect(text, isNot(contains('Ã')));
    expect(text, isNot(contains('â€™')));
  });
}

Set<Object?> _scheduleIds(Map variant) =>
    (variant['scheduleIds']! as List).cast<Map>().map((item) => item['id']).toSet();

Map<String, Object?> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
