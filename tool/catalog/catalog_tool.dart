import 'dart:convert';
import 'dart:io';

import 'package:hybrid_training/features/training_catalog/data/runtime_catalog_builder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _documentArrays = <String>{
  'inventory',
  'sources',
  'components',
  'schedules',
  'templates',
  'optionSchemas',
  'movements',
  'exercises',
  'assistancePlans',
  'conditioningDefinitions',
};
String _arrayName(String kind) => kind == 'inventory' ? 'entries' : kind;
const _placeholders = <String>{
  'todo',
  'placeholder',
  'stub',
  'needs_review',
  'blocked',
  'comingsoon',
  'coming_soon',
  'not_implemented',
};

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty ||
      !{'lint', 'coverage', 'verify', 'build'}.contains(arguments.first)) {
    stderr.writeln(
      'Usage: dart run tool/catalog/catalog_tool.dart <lint|coverage|verify|build> [output]',
    );
    exitCode = 64;
    return;
  }
  final catalog = _Catalog.load(Directory('catalog_src'));
  final errors = catalog.lint();
  if (errors.isNotEmpty) {
    for (final error in errors) stderr.writeln(error);
    exitCode = 1;
    return;
  }
  switch (arguments.first) {
    case 'lint':
      stdout.writeln(
        'catalog lint passed (${catalog.documents.length} documents)',
      );
    case 'coverage':
      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert(catalog.coverage()),
      );
    case 'verify':
      final coverage = catalog.coverage();
      final errors = <String>[];
      if (coverage['inventoryEntries'] != 354) {
        errors.add(
          'inventoryEntries must be 354, got ${coverage['inventoryEntries']}',
        );
      }
      for (final key in const [
        'unresolvedCycleEntries',
        'missingVariants',
        'missingOptionSchemas',
        'missingSchedules',
        'missingReferences',
        'unsupportedPrimitives',
        'placeholderEntries',
        'compileFailures',
      ]) {
        if (coverage[key] != 0)
          errors.add('$key must be zero, got ${coverage[key]}');
      }
      if (errors.isNotEmpty) {
        for (final error in errors) stderr.writeln(error);
        exitCode = 1;
      } else {
        stdout.writeln('catalog verification passed');
      }
    case 'build':
      final outputPath = arguments.length > 1
          ? arguments[1]
          : 'build/catalog/catalog.db';
      stdout.writeln(await buildCatalogDatabase(outputPath));
  }
}

Future<String> buildCatalogDatabase(
  String outputPath, {
  String sourcePath = 'catalog_src',
}) async {
  final catalog = _Catalog.load(Directory(sourcePath));
  final errors = catalog.lint();
  if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
  sqfliteFfiInit();
  await const RuntimeCatalogBuilder().build(
    aggregate: catalog.buildDocument(),
    outputPath: outputPath,
    factory: databaseFactoryFfi,
  );
  return outputPath;
}

List<String> lintCatalog({String sourcePath = 'catalog_src'}) =>
    _Catalog.load(Directory(sourcePath)).lint();

Map<String, int> catalogCoverage({String sourcePath = 'catalog_src'}) =>
    _Catalog.load(Directory(sourcePath)).coverage();

String buildCatalogSeed(
  String outputPath, {
  String sourcePath = 'catalog_src',
}) {
  final catalog = _Catalog.load(Directory(sourcePath));
  final errors = catalog.lint();
  if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
  final output = File(outputPath)..parent.createSync(recursive: true);
  output.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(catalog.buildDocument()),
  );
  return output.path;
}

final class _Document {
  const _Document(this.path, this.kind, this.records);
  final String path;
  final String kind;
  final List<Map<String, Object?>> records;
}

final class _Catalog {
  _Catalog(this.documents, this.loadErrors);
  final List<_Document> documents;
  final List<String> loadErrors;

  factory _Catalog.load(Directory root) {
    final documents = <_Document>[];
    final errors = <String>[];
    final rootPrefix = root.path.endsWith(Platform.pathSeparator)
        ? root.path
        : '${root.path}${Platform.pathSeparator}';
    final files =
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      try {
        final value = jsonDecode(file.readAsStringSync());
        if (value is! Map<String, Object?>)
          throw const FormatException('root must be an object');
        final kindValue = value['kind'];
        final arrayName = kindValue is String ? _arrayName(kindValue) : '';
        _exact(value, {
          'schemaVersion',
          'kind',
          arrayName,
        }, '${file.path}:root');
        if (value['schemaVersion'] != 1)
          throw const FormatException('schemaVersion must be 1');
        final kind = value['kind'];
        if (kind is! String || !_documentArrays.contains(kind)) {
          throw FormatException('unknown kind $kind');
        }
        final list = value[arrayName];
        if (list is! List<Object?>)
          throw FormatException('$kind must be an array');
        documents.add(
          _Document(
            file.path.startsWith(rootPrefix)
                ? file.path.substring(rootPrefix.length)
                : file.path,
            kind,
            list
                .map((item) {
                  if (item is! Map<String, Object?>)
                    throw FormatException('$kind record must be an object');
                  return item;
                })
                .toList(growable: false),
          ),
        );
      } catch (error) {
        errors.add('${file.path}: $error');
      }
    }
    return _Catalog(documents, errors);
  }

  List<String> lint() {
    final errors = [...loadErrors];
    final identities = <String>{};
    for (final document in documents) {
      for (var i = 0; i < document.records.length; i++) {
        final record = document.records[i];
        final at = '${document.path}:${document.kind}[$i]';
        try {
          _lintRecord(document.kind, record, at);
          _rejectPlaceholder(record, at);
          final identity = document.kind == 'sources'
              ? 'sources:${record['ruleId']}'
              : document.kind == 'inventory'
              ? 'inventory:${record['id']}'
              : '${document.kind}:${record['id']}@${record['revision']}';
          if (!identities.add(identity)) {
            throw FormatException('duplicate identity $identity');
          }
        } catch (error) {
          errors.add('$at: $error');
        }
      }
    }
    return errors;
  }

  Map<String, int> coverage() {
    final byKind = <String, List<Map<String, Object?>>>{};
    for (final document in documents) {
      byKind.putIfAbsent(document.kind, () => []).addAll(document.records);
    }
    final entries = byKind['inventory'] ?? const [];
    final templates = byKind['templates'] ?? const [];
    final sources = (byKind['sources'] ?? const [])
        .map((r) => r['ruleId'])
        .toSet();
    final components = (byKind['components'] ?? const [])
        .map((r) => '${r['id']}@${r['revision']}')
        .toSet();
    final options = (byKind['optionSchemas'] ?? const [])
        .map((r) => '${r['id']}@${r['revision']}')
        .toSet();
    final schedules = (byKind['schedules'] ?? const [])
        .map((r) => '${r['id']}@${r['revision']}')
        .toSet();
    final assistancePlans = (byKind['assistancePlans'] ?? const [])
        .map((r) => '${r['id']}@${r['revision']}')
        .toSet();
    final conditioningDefinitions =
        (byKind['conditioningDefinitions'] ?? const [])
            .map((r) => '${r['id']}@${r['revision']}')
            .toSet();
    var variants = 0,
        missingVariants = 0,
        missingOptions = 0,
        missingSchedules = 0;
    var missingReferences = 0, compileFailures = 0;
    for (final template in templates) {
      final list = template['variants'] as List<Object?>;
      variants += list.length;
      if (list.isEmpty) missingVariants++;
      for (final raw in list) {
        final variant = raw! as Map<String, Object?>;
        final option = variant['optionSchemaId']! as Map<String, Object?>;
        if (!options.contains('${option['id']}@${option['revision']}'))
          missingOptions++;
        final scheduleRefs = variant['scheduleIds']! as List<Object?>;
        if (scheduleRefs.isEmpty) missingSchedules++;
        final allowedScheduleIds = <String>{};
        for (final rawRef in scheduleRefs) {
          final ref = rawRef! as Map<String, Object?>;
          allowedScheduleIds.add(ref['id']! as String);
          if (!schedules.contains('${ref['id']}@${ref['revision']}'))
            missingSchedules++;
        }
        final componentRefs = <Object?>[];
        void collectPlans(List<Object?> plans) {
          for (final rawPlan in plans) {
            componentRefs.addAll(
              (_object(rawPlan, 'weekPlan')['componentIds']! as List<Object?>),
            );
          }
        }

        if (variant['weekPlans'] case final List<Object?> plans)
          collectPlans(plans);
        if (variant['phases'] case final List<Object?> phases) {
          for (final rawPhase in phases) {
            collectPlans(
              _object(rawPhase, 'phase')['weekPlans']! as List<Object?>,
            );
          }
        }
        for (final rawRef in componentRefs) {
          final ref = rawRef! as Map<String, Object?>;
          if (!components.contains('${ref['id']}@${ref['revision']}'))
            missingReferences++;
        }
        for (final pair in [
          ('assistancePlanIds', assistancePlans),
          ('conditioningDefinitionIds', conditioningDefinitions),
        ]) {
          final refs = variant[pair.$1];
          if (refs is List<Object?>) {
            for (final rawRef in refs) {
              final ref = rawRef! as Map<String, Object?>;
              if (!pair.$2.contains('${ref['id']}@${ref['revision']}')) {
                missingReferences++;
              }
            }
          }
        }
        final example = variant['validExample']! as Map<String, Object?>;
        if (example.isEmpty ||
            example['scheduleId'] is! String ||
            !allowedScheduleIds.contains(example['scheduleId']))
          compileFailures++;
      }
    }
    for (final document in documents) {
      for (final record in document.records) {
        final ids = record['sourceRuleIds'];
        if (ids is List<Object?>) {
          missingReferences += ids.where((id) => !sources.contains(id)).length;
        }
      }
    }
    final templateIds = templates.map((r) => r['id']).toSet();
    final cycleEntries = entries
        .where((r) => r['classification'] == 'cycleTemplate')
        .toList();
    final unresolved = cycleEntries
        .where((r) => !templateIds.contains(r['cycleTemplateId']))
        .length;
    return {
      'inventoryEntries': entries.length,
      'classifiedEntries': entries
          .where((r) => r['classification'] != null)
          .length,
      'cycleTemplates': templates.length,
      'cycleVariants': variants,
      'sharedComponents': byKind['components']?.length ?? 0,
      'optionSchemas': byKind['optionSchemas']?.length ?? 0,
      'schedules': byKind['schedules']?.length ?? 0,
      'movements': byKind['movements']?.length ?? 0,
      'exercises': byKind['exercises']?.length ?? 0,
      'assistancePlans': byKind['assistancePlans']?.length ?? 0,
      'conditioningDefinitions': byKind['conditioningDefinitions']?.length ?? 0,
      'unresolvedCycleEntries': unresolved,
      'missingVariants': missingVariants,
      'missingOptionSchemas': missingOptions,
      'missingSchedules': missingSchedules,
      'missingReferences': missingReferences,
      'unsupportedPrimitives': lint()
          .where((e) => e.contains('primitive'))
          .length,
      'placeholderEntries': _placeholderCount(),
      'compileFailures': compileFailures,
    };
  }

  Map<String, Object?> buildDocument() => {
    'schemaVersion': 1,
    'catalogVersion': 1,
    'status': 'published',
    'documents': [
      for (final document in documents)
        {
          'path': document.path.replaceAll('\\', '/'),
          'content': {
            'schemaVersion': 1,
            'kind': document.kind,
            _arrayName(document.kind): document.records,
          },
        },
    ],
    'coverage': coverage(),
  };

  int _placeholderCount() {
    var count = 0;
    for (final document in documents) {
      for (final record in document.records) {
        if (_containsPlaceholder(record)) count++;
      }
    }
    return count;
  }
}

void _lintRecord(String kind, Map<String, Object?> value, String at) {
  switch (kind) {
    case 'inventory':
      _exact(
        value,
        {
          'id',
          'generation',
          'classification',
          'title',
          'cycleTemplateId',
          'sourceRuleIds',
        },
        at,
        optional: {'cycleTemplateId'},
      );
      _labels(value['title'], '$at.title');
      _strings(value['sourceRuleIds'], '$at.sourceRuleIds');
      if (!const {
        'cycleTemplate',
        'sharedComponent',
        'rule',
        'schedule',
        'protocol',
        'transition',
        'documentation',
      }.contains(value['classification'])) {
        throw FormatException(
          'unknown classification ${value['classification']}',
        );
      }
      if (value['classification'] == 'cycleTemplate' &&
          value['cycleTemplateId'] is! String) {
        throw const FormatException('cycleTemplate requires cycleTemplateId');
      }
    case 'sources':
      _exact(value, {
        'ruleId',
        'work',
        'edition',
        'section',
        'reviewStatus',
      }, at);
      if (!const {
        'reviewed',
        'referenceAppObserved',
      }.contains(value['reviewStatus']))
        throw FormatException('unknown reviewStatus ${value['reviewStatus']}');
      final section = value['section'];
      if (section is! String ||
          section.trim().isEmpty ||
          RegExp(r'PDF p\.\s+-').hasMatch(section)) {
        throw const FormatException(
          'source section requires precise pagination',
        );
      }
    case 'components':
      _exact(value, {
        'id',
        'revision',
        'role',
        'labels',
        'sourceRuleIds',
        'parameterSchemaIds',
        'constraints',
        'compatibilities',
        'block',
      }, at);
      _common(value, at);
      _strings(value['parameterSchemaIds'], '$at.parameterSchemaIds');
      _object(value['constraints'], '$at.constraints');
      _object(value['compatibilities'], '$at.compatibilities');
      _block(value['block'], '$at.block');
    case 'schedules':
      _exact(value, {
        'id',
        'revision',
        'labels',
        'sourceRuleIds',
        'type',
        'sessions',
      }, at);
      _common(value, at);
      if (!const {
        'fixed',
        'rotating',
        'multiMovement',
        'finite',
      }.contains(value['type']))
        throw FormatException('unknown schedule type ${value['type']}');
      final sessions = _objects(value['sessions'], '$at.sessions');
      for (var i = 0; i < sessions.length; i++) {
        _exact(sessions[i], {'id', 'role', 'movementIds'}, '$at.sessions[$i]');
        _strings(sessions[i]['movementIds'], '$at.sessions[$i].movementIds');
      }
    case 'templates':
      _exact(value, {
        'id',
        'revision',
        'labels',
        'sourceRuleIds',
        'variants',
      }, at);
      _common(value, at);
      final variants = _objects(value['variants'], '$at.variants');
      for (var i = 0; i < variants.length; i++) {
        final v = variants[i], vat = '$at.variants[$i]';
        _exact(
          v,
          {
            'id',
            'revision',
            'labels',
            'sourceRuleIds',
            'weekPlans',
            'phases',
            'optionSchemaId',
            'scheduleIds',
            'assistancePlanIds',
            'conditioningDefinitionIds',
            'compatibilities',
            'validExample',
          },
          vat,
          optional: {
            'weekPlans',
            'phases',
            'assistancePlanIds',
            'conditioningDefinitionIds',
          },
        );
        _common(v, vat);
        if (v.containsKey('weekPlans') == v.containsKey('phases')) {
          throw const FormatException(
            'variant requires exactly one weekPlans or phases',
          );
        }
        if (v['weekPlans'] case final List<Object?> plans) {
          _weekPlans(plans, '$vat.weekPlans');
        }
        if (v['phases'] case final List<Object?> phases) {
          for (final rawPhase in phases) {
            final phase = _object(rawPhase, '$vat.phases');
            _exact(phase, {'id', 'repeatCount', 'weekPlans'}, '$vat.phase');
            _weekPlans(
              phase['weekPlans']! as List<Object?>,
              '$vat.phase.weekPlans',
            );
          }
        }
        _ref(v['optionSchemaId'], '$vat.optionSchemaId');
        _refs(v['scheduleIds'], '$vat.scheduleIds');
        if (v['assistancePlanIds'] != null) {
          _refs(v['assistancePlanIds'], '$vat.assistancePlanIds');
        }
        if (v['conditioningDefinitionIds'] != null) {
          _refs(
            v['conditioningDefinitionIds'],
            '$vat.conditioningDefinitionIds',
          );
        }
        _object(v['compatibilities'], '$vat.compatibilities');
        _object(v['validExample'], '$vat.validExample');
      }
    case 'optionSchemas':
      _exact(value, {'id', 'revision', 'sourceRuleIds', 'parameters'}, at);
      _identity(value, at);
      _strings(value['sourceRuleIds'], '$at.sourceRuleIds');
      final parameters = _objects(value['parameters'], '$at.parameters');
      for (var i = 0; i < parameters.length; i++)
        _parameter(parameters[i], '$at.parameters[$i]');
    case 'movements':
      _exact(value, {
        'id',
        'revision',
        'labels',
        'sourceRuleIds',
        'pattern',
        'trainingMaxEligible',
        'requiredCapabilities',
      }, at);
      _common(value, at);
      _strings(value['requiredCapabilities'], '$at.requiredCapabilities');
    case 'exercises':
      _exact(value, {
        'id',
        'revision',
        'labels',
        'sourceRuleIds',
        'categories',
        'measurementModes',
        'requiredCapabilities',
        'loadingModes',
      }, at);
      _common(value, at);
      for (final key in const [
        'categories',
        'measurementModes',
        'requiredCapabilities',
        'loadingModes',
      ])
        _strings(value[key], '$at.$key');
    case 'assistancePlans':
      _exact(
        value,
        {
          'id',
          'revision',
          'labels',
          'sourceRuleIds',
          'slots',
          'constraints',
          'compatibleExerciseCategories',
          'prescription',
        },
        at,
        optional: {'prescription'},
      );
      _common(value, at);
      _strings(value['constraints'], '$at.constraints');
      _strings(
        value['compatibleExerciseCategories'],
        '$at.compatibleExerciseCategories',
      );
      for (final slot in _objects(value['slots'], '$at.slots')) {
        if (slot.containsKey('category')) {
          _exact(slot, {
            'category',
            'minimumTotal',
            'maximumTotal',
            'unit',
            'minimumExercises',
            'maximumExercises',
          }, '$at.slot');
        } else {
          _exact(
            slot,
            {
              'id',
              'sessionRole',
              'minimumExercises',
              'maximumExercises',
              'allowedCategories',
              'prescriptions',
              'recommendedExerciseIds',
            },
            '$at.slot',
            optional: {'prescriptions', 'recommendedExerciseIds'},
          );
          _strings(slot['allowedCategories'], '$at.slot.allowedCategories');
          if (slot['recommendedExerciseIds'] != null) {
            _strings(
              slot['recommendedExerciseIds'],
              '$at.slot.recommendedExerciseIds',
            );
          }
          if (slot['prescriptions'] != null &&
              slot['prescriptions'] is! List<Object?>) {
            throw FormatException('$at.slot.prescriptions must be an array');
          }
        }
      }
      if (value['prescription'] != null) {
        _object(value['prescription'], '$at.prescription');
      }
    case 'conditioningDefinitions':
      _exact(value, {
        'id',
        'revision',
        'labels',
        'sourceRuleIds',
        'intensity',
        'modality',
        'measurementModes',
        'frequency',
        'prescription',
        'placement',
        'requiredCapabilities',
      }, at);
      _common(value, at);
      for (final key in const [
        'measurementModes',
        'placement',
        'requiredCapabilities',
      ])
        _strings(value[key], '$at.$key');
      _exact(_object(value['frequency'], '$at.frequency'), {
        'minimumPerWeek',
        'maximumPerWeek',
      }, '$at.frequency');
      _object(value['prescription'], '$at.prescription');
  }
}

void _parameter(Map<String, Object?> value, String at) {
  _exact(value, {
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
  }, at);
  if (!const {
    'boolean',
    'enumeration',
    'integer',
    'percentage',
    'weight',
    'movement',
    'exercise',
    'prescription',
  }.contains(value['type']))
    throw FormatException('unknown parameter type ${value['type']}');
  if (!const {'global', 'perMovement', 'perSession'}.contains(value['scope']))
    throw FormatException('unknown parameter scope ${value['scope']}');
  if (value['allowedValues'] is! List<Object?>)
    throw const FormatException('allowedValues must be an array');
  for (final key in const ['visibleWhen', 'enabledWhen', 'requiredWhen'])
    _condition(value[key], '$at.$key');
}

void _weekPlans(List<Object?> raw, String at) {
  if (raw.isEmpty) throw FormatException('$at must not be empty');
  for (var i = 0; i < raw.length; i++) {
    final plan = _object(raw[i], '$at[$i]');
    _exact(plan, {'weekNumber', 'componentIds'}, '$at[$i]');
    if (plan['weekNumber'] is! int || (plan['weekNumber']! as int) < 1) {
      throw FormatException('$at[$i] invalid weekNumber');
    }
    _refs(plan['componentIds'], '$at[$i].componentIds');
  }
}

void _condition(Object? raw, String at) {
  final value = _object(raw, at);
  final type = value['type'];
  final keys = switch (type) {
    'always' => {'type'},
    'present' => {'type', 'parameterId'},
    'equals' => {'type', 'parameterId', 'value'},
    'not' => {'type', 'condition'},
    'all' || 'any' => {'type', 'conditions'},
    'in' => {'type', 'parameterId', 'values'},
    'range' => {'type', 'parameterId', 'minimum', 'maximum'},
    _ => throw FormatException('unknown condition type $type'),
  };
  _exact(value, keys, at);
  if (type == 'not') _condition(value['condition'], '$at.condition');
  if (type == 'all' || type == 'any')
    for (final condition in (value['conditions']! as List<Object?>))
      _condition(condition, '$at.conditions');
}

void _block(Object? raw, String at) {
  final value = _object(raw, at);
  _exact(
    value,
    {'id', 'role', 'sets', 'movementId'},
    at,
    optional: {'movementId'},
  );
  final sets = _objects(value['sets'], '$at.sets');
  for (var i = 0; i < sets.length; i++) {
    final set = sets[i];
    _exact(set, {'repetitions', 'load'}, '$at.sets[$i]');
    final reps = _object(set['repetitions'], '$at.sets[$i].repetitions');
    switch (reps['type']) {
      case 'fixed':
        _exact(reps, {'type', 'count'}, '$at primitive repetitions');
      case 'range':
        _exact(reps, {
          'type',
          'minimum',
          'maximum',
        }, '$at primitive repetitions');
      case 'total':
        _exact(reps, {'type', 'total'}, '$at primitive repetitions');
      case 'amrap':
        _exact(
          reps,
          {'type', 'minimum'},
          '$at primitive repetitions',
          optional: {'minimum'},
        );
      default:
        throw FormatException('unknown primitive repetition ${reps['type']}');
    }
    final load = _object(set['load'], '$at.sets[$i].load');
    switch (load['type']) {
      case 'training_max_percentage' || 'one_rep_max_percentage':
        _exact(load, {'type', 'basisPoints'}, '$at primitive load');
      case 'parameterized_training_max_percentage':
        _exact(load, {
          'type',
          'parameterId',
          'defaultBasisPoints',
          'minimumBasisPoints',
          'maximumBasisPoints',
        }, '$at primitive load');
      case 'relative_set':
        _exact(load, {
          'type',
          'position',
          'multiplierBasisPoints',
        }, '$at primitive load');
        if (!const {'first', 'second', 'top'}.contains(load['position'])) {
          throw FormatException(
            'unknown relative set position ${load['position']}',
          );
        }
      case 'fixed':
        _exact(load, {'type', 'centiUnits', 'unit'}, '$at primitive load');
      case 'bodyweight' || 'unloaded':
        _exact(load, {'type'}, '$at primitive load');
      default:
        throw FormatException('unknown primitive load ${load['type']}');
    }
  }
}

void _common(Map<String, Object?> value, String at) {
  _identity(value, at);
  _labels(value['labels'], '$at.labels');
  _strings(value['sourceRuleIds'], '$at.sourceRuleIds');
}

void _identity(Map<String, Object?> value, String at) {
  if (value['id'] is! String ||
      value['revision'] is! int ||
      (value['revision']! as int) < 1)
    throw FormatException('$at invalid identity');
}

void _labels(Object? raw, String at) {
  final value = _object(raw, at);
  _exact(value, {'en', 'fr'}, at);
  if (value.values.any((v) => v is! String || (v).trim().isEmpty))
    throw FormatException('$at labels must be non-empty strings');
}

void _ref(Object? raw, String at) {
  final value = _object(raw, at);
  _exact(value, {'id', 'revision'}, at);
  _identity(value, at);
}

void _refs(Object? raw, String at) {
  final list = raw;
  if (list is! List<Object?>) throw FormatException('$at must be an array');
  for (final value in list) _ref(value, at);
}

List<Map<String, Object?>> _objects(Object? raw, String at) {
  if (raw is! List<Object?>) throw FormatException('$at must be an array');
  return raw.map((v) => _object(v, at)).toList();
}

Map<String, Object?> _object(Object? raw, String at) =>
    raw is Map<String, Object?>
    ? raw
    : throw FormatException('$at must be an object');
void _strings(Object? raw, String at) {
  if (raw is! List<Object?> || raw.any((v) => v is! String))
    throw FormatException('$at must be a string array');
}

void _exact(
  Map<String, Object?> value,
  Set<Object?> keys,
  String at, {
  Set<String> optional = const {},
}) {
  final allowed = keys.whereType<String>().toSet();
  final unknown = value.keys.where((k) => !allowed.contains(k));
  if (unknown.isNotEmpty)
    throw FormatException('$at unknown key ${unknown.first}');
  final missing = allowed.where(
    (k) => !optional.contains(k) && !value.containsKey(k),
  );
  if (missing.isNotEmpty)
    throw FormatException('$at missing key ${missing.first}');
}

bool _containsPlaceholder(Object? value) {
  if (value is String) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z_]'), '');
    return _placeholders.any(normalized.contains);
  }
  if (value is List<Object?>) return value.any(_containsPlaceholder);
  if (value is Map<String, Object?>)
    return value.entries.any(
      (e) => _containsPlaceholder(e.key) || _containsPlaceholder(e.value),
    );
  return false;
}

void _rejectPlaceholder(Object? value, String at) {
  if (_containsPlaceholder(value))
    throw FormatException('$at contains a forbidden placeholder marker');
}
