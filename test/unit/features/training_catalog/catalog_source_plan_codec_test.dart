import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/application/catalog_plan_resolver.dart';
import 'package:hybrid_training/features/cycle_generation/domain/catalog_cycle_primitives.dart';
import 'package:hybrid_training/features/training_catalog/data/catalog_plan_data_resolver.dart';
import 'package:hybrid_training/features/training_catalog/data/catalog_source_document_codec.dart';

void main() {
  const codec = CatalogSourceDocumentCodec();

  test('decodes strict source documents and resolves a generic plan', () {
    final components = codec.decodeComponents(
      File('catalog_src/shared/cycle_components_v1.json').readAsStringSync(),
    );
    final schedules = codec.decodeSchedules(
      File('catalog_src/schedules/cycle_schedules_v1.json').readAsStringSync(),
    );
    final templates = codec.decodeTemplates(
      File('catalog_src/classic/templates.json').readAsStringSync(),
    );
    final optionRecipes = codec.decodeCycleOptionRecipes(
      File('catalog_src/shared/cycle_option_recipes_v1.json').readAsStringSync(),
    );
    final template = templates.firstWhere((item) => item.id == 'classic_531');
    final variant = template.variants.firstWhere(
      (item) => item.id == 'four_day',
    );
    final plan = const CatalogPlanDataResolver().resolve(
      catalogVersion: 1,
      template: template,
      variant: variant,
      scheduleReference: const ComponentReference('schedule_four_day_fixed', 1),
      schedules: schedules,
      components: components,
      optionRecipes: optionRecipes,
      sourceReference: 'catalog-source:test',
    );
    final resolved = const CatalogPlanResolver().resolve(plan);
    expect(resolved.weeks, hasLength(4));
    expect(resolved.sessionMovementIds, hasLength(4));
    expect(resolved.weeks.first.sessions.first.blocks, hasLength(2));
  });

  test('rejects unknown keys instead of silently accepting them', () {
    expect(
      () => codec.decodeSchedules('''
        {"schemaVersion":1,"kind":"schedules","schedules":[
          {"id":"s","revision":1,"labels":{"en":"S","fr":"S"},
           "sourceRuleIds":["r"],"type":"fixed","sessions":[],
           "templateId":"forbidden"}
        ]}
      '''),
      throwsFormatException,
    );
  });

  test('extracts a reference from a complete schedule record', () {
    final schedules = codec.decodeSchedules('''
      {"schemaVersion":1,"kind":"schedules","schedules":[{
        "id":"schedule_four_day","revision":2,
        "labels":{"en":"Four day","fr":"Quatre jours"},
        "sourceRuleIds":["r"],"type":"fixed",
        "sessions":[{"id":"squat","role":"mainLift","movementIds":["squat"]}]
      }]}
    ''');
    expect(schedules.single.reference.id, 'schedule_four_day');
    expect(schedules.single.reference.revision, 2);
  });

  test('decodes finite phases without flattening them in the codec', () {
    final templates = codec.decodeTemplates('''
      {"schemaVersion":1,"kind":"templates","templates":[{
        "id":"finite","revision":1,"labels":{"en":"F","fr":"F"},
        "sourceRuleIds":["r"],"surface":"cyclePublic","variants":[{
          "id":"v","revision":1,"labels":{"en":"V","fr":"V"},
          "sourceRuleIds":["r"],"optionSchemaId":{"id":"o","revision":1},
          "scheduleIds":[{"id":"s","revision":1}],"compatibilities":{},
          "validExample":{},"phases":[{"id":"build","repeatCount":2,
          "weekPlans":[{"weekNumber":1,"componentIds":[{"id":"c","revision":1}]}]}]
        }]
      }]}
    ''');
    expect(templates.single.variants.single.phases.single.repeatCount, 2);
  });
}
