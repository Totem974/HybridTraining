import 'dart:convert';
import 'dart:io';

const _root = 'catalog_src/classic/extended';

Future<void> main() async {
  await _rewriteTemplates();
  await _rewriteOptionSchemas();
  await _rewriteSchedules();
  await _rewriteComponents();
  await _writeAliases();
  await _writeSources();
}

Future<Map<String, Object?>> _read(String name) async =>
    (jsonDecode(await File('$_root/$name').readAsString()) as Map)
        .cast<String, Object?>();

Future<void> _write(String name, Object value) async {
  const encoder = JsonEncoder.withIndent('  ');
  await File('$_root/$name').writeAsString('${encoder.convert(value)}\n');
}

Map<String, Object?> _map(Object? value) =>
    (value as Map).cast<String, Object?>();
List<Object?> _list(Object? value) => (value as List).cast<Object?>();
Map<String, Object?> _ref(String id) => {'id': id, 'revision': 1};

Future<void> _rewriteTemplates() async {
  final document = await _read('templates.json');
  final templates = _list(document['templates']).map(_map).toList();
  final old = {
    for (final template in templates.where(
      (item) => (item['id'] as String).startsWith('classic_full_body_phase_'),
    ))
      template['id'] as String: template,
  };
  final beginner = templates.singleWhere(
    (item) => item['id'] == 'classic_for_beginners',
  );
  beginner['surface'] = 'cyclePublic';
  for (final variant in _list(beginner['variants']).map(_map)) {
    variant['optionRecipeId'] = _ref('classic_additional_options');
    variant['scheduleIds'] = [_ref('classic_for_beginners_three_day')];
    final example = _map(variant['validExample']);
    example['scheduleId'] = 'classic_for_beginners_three_day';
  }
  if (old.isEmpty &&
      templates.any((item) => item['id'] == 'classic_full_body')) {
    document['templates'] = templates;
    await _write('templates.json', document);
    return;
  }
  final phaseOne = _map(
    _list(
      _map(
        _list(old['classic_full_body_phase_1']!['variants']).single,
      )['phases'],
    ).single,
  );
  final baseWeeks = _list(phaseOne['weekPlans']).map(_map).toList();

  List<Map<String, Object?>> weeks({
    required String profile,
    required bool assistance,
    required bool fullBoring,
  }) => [
    for (final week in baseWeeks)
      {
        'weekNumber': week['weekNumber'],
        'componentIds': [
          ..._list(week['componentIds']).map(_map).where((reference) {
            final id = reference['id'] as String;
            return id.startsWith('classic_full_body_main_');
          }),
          if (fullBoring) ...[
            _ref('classic_full_body_profile_squat_$profile'),
            _ref('classic_full_body_profile_bench_$profile'),
            _ref('classic_full_body_profile_deadlift_65x3_75x3_85x3'),
          ] else
            _ref('classic_full_body_profile_squat_$profile'),
          if (assistance) ...[
            _ref('classic_full_body_assistance_dumbbell_press'),
            _ref('classic_full_body_assistance_dumbbell_row'),
            _ref('classic_full_body_assistance_chin_up'),
          ],
        ],
      },
  ];

  Map<String, Object?> selection(
    String parameterId,
    String movement,
    List<String> values,
  ) => {
    'parameterId': parameterId,
    'targetComponentId': _ref(
      'classic_full_body_profile_${movement}_${values.first}',
    ),
    'choices': [
      for (final value in values)
        {
          'value': value,
          'componentId': _ref('classic_full_body_profile_${movement}_$value'),
        },
    ],
  };

  const standardProfiles = [
    '65x5_75x5_85x5',
    '70x3_80x3_90x3',
    '75x5_85x3_95x1',
    '80x1_90x1_100x1',
  ];
  const deadliftProfiles = [
    '65x3_75x3_85x3',
    '70x3_80x3_90x3',
    '75x5_85x3_95x1',
    '80x1_90x1_100x1',
  ];

  final canonical = <String, Object?>{
    'id': 'classic_full_body',
    'revision': 1,
    'surface': 'cyclePublic',
    'labels': {'en': 'Full Body', 'fr': 'Full Body'},
    'sourceRuleIds': [
      'or.full_body.phase_1',
      'or.full_body.phase_2',
      'or.full_body.phase_3',
      'app.full_body.updated',
      'app.full_body.full_boring',
    ],
    'variants': [
      {
        'id': 'original',
        'revision': 1,
        'labels': {'en': 'Original', 'fr': 'Original'},
        'sourceRuleIds': [
          'or.full_body.phase_1',
          'or.full_body.phase_2',
          'or.full_body.phase_3',
        ],
        'weekPlans': weeks(
          profile: '40x5_50x5_60x5',
          assistance: true,
          fullBoring: false,
        ),
        'componentSelections': [
          {
            'parameterId': 'phase',
            'targetComponentId': _ref(
              'classic_full_body_profile_squat_40x5_50x5_60x5',
            ),
            'choices': [
              {
                'value': 'phase_one',
                'componentId': _ref(
                  'classic_full_body_profile_squat_40x5_50x5_60x5',
                ),
              },
              {
                'value': 'phase_two',
                'componentId': _ref(
                  'classic_full_body_profile_squat_65x3_75x3_85x3',
                ),
              },
              {
                'value': 'phase_three',
                'componentId': _ref(
                  'classic_full_body_profile_squat_75x3_85x3_95x1',
                ),
              },
            ],
          },
        ],
        'optionSchemaId': _ref('classic_full_body_original_options'),
        'optionRecipeId': _ref('classic_additional_options'),
        'scheduleIds': [_ref('classic_full_body_three_day')],
        'compatibilities': {
          'trainingMaxRequired': true,
          'sessionTargetingRequired': true,
          'minimumDurationMonths': 2,
        },
        'validExample': {
          'trainingMaxRatioBasisPoints': 9000,
          'scheduleId': 'classic_full_body_three_day',
          'phase': 'phase_one',
        },
      },
      {
        'id': 'updated',
        'revision': 1,
        'labels': {'en': 'Updated', 'fr': 'Updated'},
        'sourceRuleIds': ['app.full_body.updated'],
        'weekPlans': weeks(
          profile: standardProfiles.first,
          assistance: true,
          fullBoring: false,
        ),
        'componentSelections': [
          selection('squat_set_profile', 'squat', standardProfiles),
        ],
        'optionSchemaId': _ref('classic_full_body_updated_options'),
        'optionRecipeId': _ref('classic_additional_options'),
        'scheduleIds': [_ref('classic_full_body_three_day')],
        'compatibilities': {
          'trainingMaxRequired': true,
          'sessionTargetingRequired': true,
        },
        'validExample': {
          'trainingMaxRatioBasisPoints': 9000,
          'scheduleId': 'classic_full_body_three_day',
          'squatSetProfile': standardProfiles.first,
        },
      },
      {
        'id': 'full_boring',
        'revision': 1,
        'labels': {'en': 'Full Boring', 'fr': 'Full Boring'},
        'sourceRuleIds': ['app.full_body.full_boring'],
        'weekPlans': weeks(
          profile: standardProfiles.first,
          assistance: false,
          fullBoring: true,
        ),
        'componentSelections': [
          selection('squat_set_profile', 'squat', standardProfiles),
          selection('bench_set_profile', 'bench', standardProfiles),
          selection('deadlift_set_profile', 'deadlift', deadliftProfiles),
        ],
        'optionSchemaId': _ref('classic_full_body_full_boring_options'),
        'optionRecipeId': _ref('classic_additional_options'),
        'scheduleIds': [_ref('classic_full_body_full_boring_three_day')],
        'compatibilities': {
          'trainingMaxRequired': true,
          'sessionTargetingRequired': true,
        },
        'validExample': {
          'trainingMaxRatioBasisPoints': 9000,
          'scheduleId': 'classic_full_body_full_boring_three_day',
          'squatSetProfile': standardProfiles.first,
          'benchSetProfile': standardProfiles.first,
          'deadliftSetProfile': deadliftProfiles.first,
        },
      },
    ],
  };

  document['templates'] = [
    ...templates.where(
      (item) => !(item['id'] as String).startsWith('classic_full_body_phase_'),
    ),
    canonical,
  ];
  await _write('templates.json', document);
}

Map<String, Object?> _parameter({
  required String id,
  required String labelEn,
  required String labelFr,
  required Object defaultValue,
  required List<Object> allowedValues,
  Object? visibleWhen,
}) => {
  'id': id,
  'labelEn': labelEn,
  'labelFr': labelFr,
  'type': 'enumeration',
  'scope': 'global',
  'default': defaultValue,
  'minimum': null,
  'maximum': null,
  'step': null,
  'allowedValues': allowedValues,
  'visibleWhen': visibleWhen ?? {'type': 'always'},
  'enabledWhen': {'type': 'always'},
  'requiredWhen': {'type': 'always'},
};

Map<String, Object?> _tmParameter() => {
  'id': 'training_max_ratio',
  'type': 'percentage',
  'scope': 'global',
  'default': 9000,
  'minimum': 9000,
  'maximum': 9000,
  'step': null,
  'allowedValues': <Object>[],
  'presentationGroup': 'hidden',
  'visibleWhen': {'type': 'always'},
  'enabledWhen': {'type': 'always'},
  'requiredWhen': {'type': 'always'},
};

Future<void> _rewriteOptionSchemas() async {
  final document = await _read('option_schemas.json');
  final schemas = _list(document['optionSchemas']).map(_map).toList();
  const profiles = <Object>[
    '65x5_75x5_85x5',
    '70x3_80x3_90x3',
    '75x5_85x3_95x1',
    '80x1_90x1_100x1',
  ];
  const deadliftProfiles = <Object>[
    '65x3_75x3_85x3',
    '70x3_80x3_90x3',
    '75x5_85x3_95x1',
    '80x1_90x1_100x1',
  ];
  Map<String, Object?> schema(
    String id,
    List<String> rules,
    List<Map<String, Object?>> parameters,
  ) => {
    'id': id,
    'revision': 1,
    'sourceRuleIds': rules,
    'parameters': [_tmParameter(), ...parameters],
  };
  document['optionSchemas'] = [
    ...schemas.where((item) {
      final id = item['id'];
      return id != 'classic_extended_full_body_options' &&
          id != 'classic_full_body_original_options' &&
          id != 'classic_full_body_updated_options' &&
          id != 'classic_full_body_full_boring_options';
    }),
    schema(
      'classic_full_body_original_options',
      ['or.full_body.phase_1', 'or.full_body.phase_2', 'or.full_body.phase_3'],
      [
        _parameter(
          id: 'phase',
          labelEn: 'Phase',
          labelFr: 'Phase',
          defaultValue: 'phase_one',
          allowedValues: ['phase_one', 'phase_two', 'phase_three'],
        ),
      ],
    ),
    schema(
      'classic_full_body_updated_options',
      ['app.full_body.updated'],
      [
        _parameter(
          id: 'squat_set_profile',
          labelEn: 'Squat Sets',
          labelFr: 'Séries de squat',
          defaultValue: profiles.first,
          allowedValues: profiles,
        ),
      ],
    ),
    schema(
      'classic_full_body_full_boring_options',
      ['app.full_body.full_boring'],
      [
        _parameter(
          id: 'squat_set_profile',
          labelEn: 'Squat Sets',
          labelFr: 'Séries de squat',
          defaultValue: profiles.first,
          allowedValues: profiles,
        ),
        _parameter(
          id: 'bench_set_profile',
          labelEn: 'Bench Sets',
          labelFr: 'Séries de développé couché',
          defaultValue: profiles.first,
          allowedValues: profiles,
        ),
        _parameter(
          id: 'deadlift_set_profile',
          labelEn: 'Deadlift Sets',
          labelFr: 'Séries de soulevé de terre',
          defaultValue: deadliftProfiles.first,
          allowedValues: deadliftProfiles,
        ),
      ],
    ),
  ];
  await _write('option_schemas.json', document);
}

Future<void> _rewriteSchedules() async {
  final document = await _read('schedules.json');
  final schedules = _list(document['schedules']).map(_map).toList();
  document['schedules'] = [
    ...schedules.where((item) {
      final id = item['id'];
      return id != 'classic_extended_three_day_full_body' &&
          id != 'classic_full_body_three_day' &&
          id != 'classic_full_body_full_boring_three_day' &&
          id != 'classic_for_beginners_three_day';
    }),
    {
      'id': 'classic_for_beginners_three_day',
      'revision': 1,
      'labels': {
        'en': 'Three-day 5/3/1 for Beginners',
        'fr': '5/3/1 pour débutants sur trois jours',
      },
      'sourceRuleIds': ['or.beginner.full_body'],
      'type': 'multiMovement',
      'sessions': [
        {
          'id': 'monday',
          'role': 'fullBodyA',
          'movementIds': ['back_squat', 'bench_press'],
        },
        {
          'id': 'wednesday',
          'role': 'fullBodyB',
          'movementIds': ['deadlift', 'overhead_press'],
        },
        {
          'id': 'friday',
          'role': 'fullBodyC',
          'movementIds': ['bench_press', 'back_squat'],
        },
      ],
    },
    {
      'id': 'classic_full_body_three_day',
      'revision': 1,
      'labels': {
        'en': 'Three-day Full Body',
        'fr': 'Full Body sur trois jours',
      },
      'sourceRuleIds': [
        'or.full_body.phase_1',
        'or.full_body.phase_2',
        'or.full_body.phase_3',
        'app.full_body.updated',
      ],
      'type': 'multiMovement',
      'sessions': [
        {
          'id': 'monday',
          'role': 'fullBodyA',
          'movementIds': ['back_squat'],
        },
        {
          'id': 'wednesday',
          'role': 'fullBodyB',
          'movementIds': ['bench_press', 'back_squat'],
        },
        {
          'id': 'friday',
          'role': 'fullBodyC',
          'movementIds': ['deadlift', 'overhead_press', 'back_squat'],
        },
      ],
    },
    {
      'id': 'classic_full_body_full_boring_three_day',
      'revision': 1,
      'labels': {
        'en': 'Three-day Full Boring',
        'fr': 'Full Boring sur trois jours',
      },
      'sourceRuleIds': ['app.full_body.full_boring'],
      'type': 'multiMovement',
      'sessions': [
        {
          'id': 'monday',
          'role': 'fullBodyA',
          'movementIds': ['back_squat', 'bench_press', 'deadlift'],
        },
        {
          'id': 'wednesday',
          'role': 'fullBodyB',
          'movementIds': ['bench_press', 'back_squat', 'deadlift'],
        },
        {
          'id': 'friday',
          'role': 'fullBodyC',
          'movementIds': ['deadlift', 'back_squat', 'bench_press'],
        },
      ],
    },
  ];
  await _write('schedules.json', document);
}

Map<String, Object?> _profileComponent({
  required String movement,
  required String profile,
  required List<String> sessions,
  required List<int> reps,
  required List<int> percentages,
  required List<String> schemas,
  required List<String> rules,
}) => {
  'id': 'classic_full_body_profile_${movement}_$profile',
  'revision': 1,
  'role': 'supplemental_work',
  'labels': {
    'en': 'Full Body $movement profile $profile',
    'fr': 'Profil Full Body $movement $profile',
  },
  'sourceRuleIds': rules,
  'parameterSchemaIds': schemas,
  'constraints': {'setOrder': 'declared'},
  'compatibilities': {
    'sessionIds': sessions,
    'movementIds': [
      switch (movement) {
        'squat' => 'back_squat',
        'bench' => 'bench_press',
        _ => 'deadlift',
      },
    ],
  },
  'block': {
    'id': 'full_body_${movement}_profile_$profile',
    'role': 'supplemental_work',
    'sets': [
      for (var index = 0; index < 3; index++)
        {
          'repetitions': {'type': 'fixed', 'count': reps[index]},
          'load': {
            'type': 'training_max_percentage',
            'basisPoints': percentages[index] * 100,
          },
        },
    ],
  },
};

Future<void> _rewriteComponents() async {
  final document = await _read('components.json');
  final components = _list(document['components']).map(_map).toList();
  final retained = components.where(
    (item) =>
        !(item['id'] as String).startsWith('classic_full_body_phase_') &&
        !(item['id'] as String).startsWith('classic_full_body_profile_'),
  );
  final profiles = <String, (List<int>, List<int>)>{
    '40x5_50x5_60x5': ([5, 5, 5], [40, 50, 60]),
    '65x3_75x3_85x3': ([3, 3, 3], [65, 75, 85]),
    '75x3_85x3_95x1': ([3, 3, 1], [75, 85, 95]),
    '65x5_75x5_85x5': ([5, 5, 5], [65, 75, 85]),
    '70x3_80x3_90x3': ([3, 3, 3], [70, 80, 90]),
    '75x5_85x3_95x1': ([5, 3, 1], [75, 85, 95]),
    '80x1_90x1_100x1': ([1, 1, 1], [80, 90, 100]),
  };
  final generated = <Map<String, Object?>>[];
  for (final entry in profiles.entries) {
    generated.add(
      _profileComponent(
        movement: 'squat',
        profile: entry.key,
        sessions: ['wednesday', 'friday'],
        reps: entry.value.$1,
        percentages: entry.value.$2,
        schemas: [
          'classic_full_body_original_options',
          'classic_full_body_updated_options',
          'classic_full_body_full_boring_options',
        ],
        rules: [
          'or.full_body.phase_1',
          'or.full_body.phase_2',
          'or.full_body.phase_3',
          'app.full_body.updated',
          'app.full_body.full_boring',
        ],
      ),
    );
  }
  const profilesByMovement = {
    'bench': [
      '65x5_75x5_85x5',
      '70x3_80x3_90x3',
      '75x5_85x3_95x1',
      '80x1_90x1_100x1',
    ],
    'deadlift': [
      '65x3_75x3_85x3',
      '70x3_80x3_90x3',
      '75x5_85x3_95x1',
      '80x1_90x1_100x1',
    ],
  };
  for (final movement in profilesByMovement.keys) {
    for (final profile in profilesByMovement[movement]!) {
      final entry = MapEntry(profile, profiles[profile]!);
      generated.add(
        _profileComponent(
          movement: movement,
          profile: entry.key,
          sessions: movement == 'bench'
              ? ['monday', 'friday']
              : ['monday', 'wednesday'],
          reps: entry.value.$1,
          percentages: entry.value.$2,
          schemas: ['classic_full_body_full_boring_options'],
          rules: ['app.full_body.full_boring'],
        ),
      );
    }
  }
  document['components'] = [...retained, ...generated];
  await _write('components.json', document);
}

Future<void> _writeAliases() => _write('template_aliases.json', {
  'schemaVersion': 1,
  'kind': 'templateAliases',
  'templateAliases': [
    for (final phase in ['one', 'two', 'three'])
      {
        'legacyTemplateId':
            'classic_full_body_phase_${switch (phase) {
              'one' => 1,
              'two' => 2,
              _ => 3,
            }}',
        'legacyVariantId':
            'phase_${switch (phase) {
              'one' => 1,
              'two' => 2,
              _ => 3,
            }}',
        'templateId': 'classic_full_body',
        'variantId': 'original',
        'optionOverrides': {'phase': 'phase_$phase'},
      },
  ],
});

Future<void> _writeSources() => _write('sources.json', {
  'schemaVersion': 1,
  'kind': 'sources',
  'sources': [
    {
      'ruleId': 'app.full_body.updated',
      'work': 'fivethreeone.app calculator',
      'edition': 'Version 2.2, recovered local runtime',
      'section': 'Full Body / Updated',
      'reviewStatus': 'referenceAppObserved',
    },
    {
      'ruleId': 'app.full_body.full_boring',
      'work': 'fivethreeone.app calculator',
      'edition': 'Version 2.2, recovered local runtime',
      'section': 'Full Body / Full Boring',
      'reviewStatus': 'referenceAppObserved',
    },
  ],
});
