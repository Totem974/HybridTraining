import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import 'sqlite_training_catalog.dart';

/// Materializes the canonical declarative aggregate into a published SQLite
/// catalogue. Records are inserted in the aggregate's already-sorted order.
final class RuntimeCatalogBuilder {
  const RuntimeCatalogBuilder();

  Future<void> build({
    required Map<String, Object?> aggregate,
    required String outputPath,
    required DatabaseFactory factory,
  }) async {
    if (aggregate['schemaVersion'] != 1 || aggregate['status'] != 'published') {
      throw const FormatException('A published schemaVersion 1 is required.');
    }
    final documents = aggregate['documents'];
    if (documents is! List<Object?>) {
      throw const FormatException('documents must be a list.');
    }

    final output = File(outputPath);
    output.parent.createSync(recursive: true);
    if (output.existsSync()) {
      await factory.deleteDatabase(output.path);
    }
    final database = await factory.openDatabase(
      output.path,
      options: OpenDatabaseOptions(
        version: SqliteTrainingCatalog.databaseSchemaVersion,
        onCreate: (db, _) => SqliteTrainingCatalog.createSchema(db),
      ),
    );
    try {
      await _populate(database, documents);
    } catch (_) {
      await database.close();
      if (output.existsSync()) await factory.deleteDatabase(output.path);
      rethrow;
    }
    await database.close();
  }

  Future<void> _populate(Database db, List<Object?> documentValues) async {
    final records = <String, List<Map<String, Object?>>>{};
    for (final value in documentValues) {
      final document = _map(value, 'document');
      final content = _map(document['content'], 'document.content');
      final kind = content['kind'];
      if (kind is! String)
        throw const FormatException('kind must be a string.');
      final key = kind == 'inventory' ? 'entries' : kind;
      final values = content[key];
      if (values is! List<Object?>) {
        throw FormatException('$kind must contain $key.');
      }
      records
          .putIfAbsent(kind, () => [])
          .addAll(values.map((item) => _map(item, '$kind record')));
    }

    await db.transaction((txn) async {
      const version = 1;
      await txn.insert('catalog_versions', {
        'version': version,
        'status': 'draft',
        'source_reference': 'catalog_src/v1',
      });

      final movementLabels = <String, String>{};
      for (final movement in records['movements'] ?? const []) {
        movementLabels[movement['id']! as String] = _englishLabel(movement);
        await txn.insert('catalog_library_entries', {
          'version': version,
          'kind': 'movement',
          'id': movement['id'],
          'revision': movement['revision'],
          'payload_json': jsonEncode(movement),
        });
      }
      for (final schedule in records['schedules'] ?? const []) {
        for (final sessionValue in schedule['sessions']! as List<Object?>) {
          final session = _map(sessionValue, 'session');
          for (final id
              in (session['movementIds']! as List<Object?>).cast<String>()) {
            movementLabels.putIfAbsent(id, () => id);
          }
        }
      }
      for (final entry
          in movementLabels.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key))) {
        await txn.insert('catalog_movements', {
          'version': version,
          'id': entry.key,
          'name': entry.value,
        });
      }

      for (final source in records['sources'] ?? const []) {
        await txn.insert('catalog_rules', {
          'version': version,
          'rule_id': source['ruleId'],
          'work': source['work'],
          'edition': source['edition'],
          'section': source['section'],
          'review_status': source['reviewStatus'] == 'pending'
              ? 'pending'
              : 'reviewed',
        });
      }
      for (final entry in records['inventory'] ?? const []) {
        await txn.insert('catalog_inventory', {
          'version': version,
          'id': entry['id'],
          'generation': entry['generation'],
          'classification': entry['classification'],
          'title': entry['title'] is Map<String, Object?>
              ? _map(entry['title'], 'inventory title')['en']
              : entry['title'],
          'cycle_template_id': entry['cycleTemplateId'],
          'source_rule_ids_json': jsonEncode(entry['sourceRuleIds']),
        });
      }
      for (final schema in records['optionSchemas'] ?? const []) {
        await txn.insert('catalog_option_schemas', {
          'version': version,
          'id': schema['id'],
          'revision': schema['revision'],
          'payload_json': jsonEncode(schema),
        });
      }
      for (final schedule in records['schedules'] ?? const []) {
        await txn.insert('catalog_schedules_v2', {
          'version': version,
          'id': schedule['id'],
          'revision': schedule['revision'],
          'payload_json': jsonEncode(schedule),
        });
      }
      for (final kind in const [
        'exercises',
        'assistancePlans',
        'conditioningDefinitions',
      ]) {
        for (final entry in records[kind] ?? const []) {
          await txn.insert('catalog_library_entries', {
            'version': version,
            'kind': kind,
            'id': entry['id'],
            'revision': entry['revision'],
            'payload_json': jsonEncode(entry),
          });
        }
      }

      final components = <String, Map<String, Object?>>{};
      for (final component in records['components'] ?? const []) {
        components['${component['id']}@${component['revision']}'] = component;
        await txn.insert('catalog_components', {
          'version': version,
          'id': component['id'],
          'block_json': jsonEncode(component['block']),
          'rule_ids_json': jsonEncode(component['sourceRuleIds']),
        });
      }
      final schedules = {
        for (final schedule in records['schedules'] ?? const [])
          '${schedule['id']}@${schedule['revision']}': schedule,
      };
      for (final template in records['templates'] ?? const []) {
        final templateId = template['id']! as String;
        await txn.insert('catalog_templates', {
          'version': version,
          'id': templateId,
          'name': _englishLabel(template),
        });
        for (final variantValue in template['variants']! as List<Object?>) {
          final variant = _map(variantValue, 'variant');
          final variantId = variant['id']! as String;
          await txn.insert('catalog_variants', {
            'version': version,
            'template_id': templateId,
            'id': variantId,
            'name': _englishLabel(variant),
          });
          final scheduleRefs = (variant['scheduleIds']! as List<Object?>)
              .map((value) => _map(value, 'schedule reference'))
              .toList(growable: false);
          final selectedSchedule =
              schedules['${scheduleRefs.first['id']}@${scheduleRefs.first['revision']}'];
          if (selectedSchedule == null) {
            throw FormatException(
              'Missing schedule for $templateId/$variantId.',
            );
          }
          var sessionPosition = 0;
          for (final sessionValue
              in selectedSchedule['sessions']! as List<Object?>) {
            final session = _map(sessionValue, 'session');
            for (final movementId
                in (session['movementIds']! as List<Object?>).cast<String>()) {
              await txn.insert('catalog_sessions', {
                'version': version,
                'template_id': templateId,
                'variant_id': variantId,
                'position': sessionPosition++,
                'movement_id': movementId,
              });
            }
          }
          final weekPlans = _expandedWeekPlans(variant);
          for (final week in weekPlans) {
            final weekNumber = week['weekNumber']! as int;
            await txn.insert('catalog_weeks', {
              'version': version,
              'template_id': templateId,
              'variant_id': variantId,
              'week_number': weekNumber,
            });
            var blockPosition = 0;
            for (final referenceValue
                in week['componentIds']! as List<Object?>) {
              final reference = _map(referenceValue, 'component reference');
              final component =
                  components['${reference['id']}@${reference['revision']}'];
              if (component == null) {
                throw FormatException('Missing component ${reference['id']}.');
              }
              final block = _map(component['block'], 'component block');
              await txn.insert('catalog_variant_week_components', {
                'version': version,
                'template_id': templateId,
                'variant_id': variantId,
                'week_number': weekNumber,
                'position': blockPosition,
                'component_id': component['id'],
              });
              await txn.insert('catalog_blocks', {
                'version': version,
                'template_id': templateId,
                'variant_id': variantId,
                'week_number': weekNumber,
                'position': blockPosition,
                'id': block['id'],
                'role': block['role'],
              });
              var setPosition = 0;
              for (final setValue in block['sets']! as List<Object?>) {
                final set = _map(setValue, 'set');
                await txn.insert('catalog_sets', {
                  'version': version,
                  'template_id': templateId,
                  'variant_id': variantId,
                  'week_number': weekNumber,
                  'block_position': blockPosition,
                  'position': setPosition++,
                  'repetitions_json': jsonEncode(set['repetitions']),
                  'load_json': jsonEncode(set['load']),
                });
              }
              blockPosition++;
            }
          }
          final optionRef = _map(variant['optionSchemaId'], 'option schema');
          await txn.insert('catalog_variant_metadata', {
            'version': version,
            'template_id': templateId,
            'variant_id': variantId,
            'revision': variant['revision'],
            'labels_json': jsonEncode(template['labels']),
            'source_rule_ids_json': jsonEncode(variant['sourceRuleIds']),
            'option_schema_id': optionRef['id'],
            'schedule_ids_json': jsonEncode(
              scheduleRefs.map((item) => item['id']).toList(),
            ),
            'compatibility_json': jsonEncode(variant['compatibilities']),
            'valid_example_json': jsonEncode(variant['validExample']),
          });
        }
      }
      await txn.update(
        'catalog_versions',
        {'status': 'published'},
        where: 'version=?',
        whereArgs: [version],
      );
    });
  }

  List<Map<String, Object?>> _expandedWeekPlans(Map<String, Object?> variant) {
    final direct = variant['weekPlans'];
    if (direct is List<Object?>) {
      return direct.map((item) => _map(item, 'week plan')).toList();
    }
    final result = <Map<String, Object?>>[];
    for (final phaseValue in variant['phases']! as List<Object?>) {
      final phase = _map(phaseValue, 'phase');
      for (
        var iteration = 0;
        iteration < (phase['repeatCount']! as int);
        iteration++
      ) {
        for (final weekValue in phase['weekPlans']! as List<Object?>) {
          final week = _map(weekValue, 'week plan');
          result.add({
            'weekNumber': result.length + 1,
            'componentIds': week['componentIds'],
          });
        }
      }
    }
    return result;
  }

  String _englishLabel(Map<String, Object?> record) {
    final labels = _map(record['labels'], 'labels');
    return labels['en']! as String;
  }

  Map<String, Object?> _map(Object? value, String context) {
    if (value is! Map<String, Object?>) {
      throw FormatException('$context must be an object.');
    }
    return value;
  }
}
