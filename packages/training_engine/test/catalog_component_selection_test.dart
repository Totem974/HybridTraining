import 'dart:convert';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  test('template surface and component selections decode strictly', () {
    final templates = const CatalogSourceDocumentCodec().decodeTemplates(
      jsonEncode({
        'schemaVersion': 1,
        'kind': 'templates',
        'templates': [
          {
            'id': 'template',
            'revision': 1,
            'labels': {'en': 'Template', 'fr': 'Template'},
            'sourceRuleIds': ['rule'],
            'surface': 'cyclePublic',
            'isDefault': true,
            'variants': [
              {
                'id': 'variant',
                'revision': 1,
                'labels': {'en': 'Variant', 'fr': 'Variant'},
                'sourceRuleIds': ['rule'],
                'optionSchemaId': {'id': 'options', 'revision': 1},
                'scheduleIds': [
                  {'id': 'schedule', 'revision': 1},
                ],
                'compatibilities': <String, Object?>{},
                'validExample': <String, Object?>{},
                'weekPlans': [
                  {
                    'weekNumber': 1,
                    'componentIds': [
                      {'id': 'target', 'revision': 1},
                    ],
                  },
                ],
                'componentSelections': [
                  {
                    'parameterId': 'phase',
                    'targetComponentId': {'id': 'target', 'revision': 1},
                    'choices': [
                      {
                        'value': 'one',
                        'componentId': {'id': 'selected', 'revision': 2},
                      },
                    ],
                  },
                ],
                'assistancePlanIds': [],
                'conditioningDefinitionIds': [],
              },
            ],
          },
        ],
      }),
    );

    expect(templates.single.surface, TemplateSurface.cyclePublic);
    expect(templates.single.isDefault, isTrue);
    expect(
      templates.single.variants.single.componentSelections.single.parameterId,
      'phase',
    );
  });

  test(
    'template isDefault is optional, boolean, and unknown keys stay rejected',
    () {
      Map<String, Object?> document(
        Object? isDefault, {
        bool unknown = false,
      }) => {
        'schemaVersion': 1,
        'kind': 'templates',
        'templates': [
          {
            'id': 'template',
            'revision': 1,
            'labels': {'en': 'Template', 'fr': 'Template'},
            'sourceRuleIds': ['rule'],
            'surface': 'cyclePublic',
            'isDefault': ?isDefault,
            if (unknown) 'unexpected': true,
            'variants': <Object?>[],
          },
        ],
      };
      const codec = CatalogSourceDocumentCodec();
      expect(
        codec.decodeTemplates(jsonEncode(document(null))).single.isDefault,
        isFalse,
      );
      expect(
        () => codec.decodeTemplates(jsonEncode(document('true'))),
        throwsFormatException,
      );
      expect(
        () => codec.decodeTemplates(jsonEncode(document(false, unknown: true))),
        throwsFormatException,
      );
    },
  );

  test('resolver replaces target from value or schema default without IDs', () {
    const target = ComponentReference('target', 1);
    const selected = ComponentReference('selected', 2);
    const variant = SourceVariant(
      id: 'variant',
      revision: 1,
      optionSchemaId: ComponentReference('options', 1),
      scheduleIds: [ComponentReference('schedule', 1)],
      weekPlans: [
        CatalogWeekPlan(weekNumber: 1, components: [target]),
      ],
      phases: [],
      compatibilities: {},
      componentSelections: [
        SourceComponentSelection(
          parameterId: 'phase',
          targetComponentId: target,
          choices: [
            SourceComponentSelectionChoice(value: 'one', componentId: selected),
          ],
        ),
      ],
    );
    const template = SourceTemplate(
      id: 'template',
      revision: 1,
      surface: TemplateSurface.cyclePublic,
      generation: SourceTemplateGeneration(
        id: 'classic',
        labels: {'en': 'Classic', 'fr': 'Classic'},
      ),
      variants: [variant],
    );
    const schedule = SourceSchedule(
      reference: ComponentReference('schedule', 1),
      sessions: [
        SourceSession(id: 'main', movementIds: ['squat']),
      ],
    );
    const component = SourceComponent(
      reference: selected,
      block: BlockDefinition(
        id: 'block',
        role: 'main_work',
        sets: [
          PrescribedSetDefinition(
            repetitions: FixedRepetitions(5),
            load: Unloaded(),
          ),
        ],
      ),
      constraints: {},
      compatibilities: {},
    );

    CatalogPlan resolve(
      Map<String, Object?> values,
      Map<String, Object?> defaults,
    ) => const CatalogPlanDataResolver().resolve(
      catalogVersion: 1,
      template: template,
      variant: variant,
      scheduleReference: const ComponentReference('schedule', 1),
      schedules: const [schedule],
      components: const [component],
      sourceReference: 'test',
      optionValues: values,
      optionDefaults: defaults,
    );

    expect(resolve({'phase': 'one'}, const {}).weekPlans.single.components, [
      selected,
    ]);
    expect(resolve(const {}, {'phase': 'one'}).weekPlans.single.components, [
      selected,
    ]);
    expect(
      () => resolve({'phase': 'unknown'}, const {}),
      throwsFormatException,
    );
  });

  test('template aliases reject non-scalar option overrides', () {
    final source = jsonEncode({
      'schemaVersion': 1,
      'kind': 'templateAliases',
      'templateAliases': [
        {
          'legacyTemplateId': 'old',
          'legacyVariantId': 'old-variant',
          'templateId': 'new',
          'variantId': 'new-variant',
          'optionOverrides': {
            'phase': ['not', 'scalar'],
          },
        },
      ],
    });
    expect(
      () => const CatalogSourceDocumentCodec().decodeTemplateAliases(source),
      throwsFormatException,
    );
  });
}
