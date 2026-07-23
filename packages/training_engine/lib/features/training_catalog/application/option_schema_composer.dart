import '../../cycle_generation/domain/catalog_cycle_primitives.dart';

typedef OptionSchemaKey = ({String id, int revision});

/// Resolves additive option-schema includes into one deterministic parameter
/// sequence.
///
/// Included schemas are expanded recursively in declaration order before the
/// including schema's own parameters. The graph and flattened parameter
/// namespace are strict: missing or duplicate schemas, cycles, and duplicate
/// parameter identifiers are rejected.
final class OptionSchemaComposer {
  const OptionSchemaComposer();

  Map<OptionSchemaKey, List<Map<String, Object?>>> composeAll(
    Iterable<Map<String, Object?>> schemas,
  ) {
    final records = List<Map<String, Object?>>.of(schemas);
    final byKey = _index(records);
    return Map<OptionSchemaKey, List<Map<String, Object?>>>.unmodifiable({
      for (final entry in byKey.entries)
        entry.key: List<Map<String, Object?>>.unmodifiable(
          _flatten(entry.key, byKey, stack: const [], parameterIds: <String>{}),
        ),
    });
  }

  List<Map<String, Object?>> compose({
    required Iterable<Map<String, Object?>> schemas,
    required ComponentReference reference,
  }) {
    final byKey = _index(List<Map<String, Object?>>.of(schemas));
    return List<Map<String, Object?>>.unmodifiable(
      _flatten(
        (id: reference.id, revision: reference.revision),
        byKey,
        stack: const [],
        parameterIds: <String>{},
      ),
    );
  }

  Map<OptionSchemaKey, Map<String, Object?>> _index(
    List<Map<String, Object?>> schemas,
  ) {
    final result = <OptionSchemaKey, Map<String, Object?>>{};
    for (final schema in schemas) {
      final key = _recordKey(schema, 'option schema');
      if (result.containsKey(key)) {
        throw FormatException('DUPLICATE_OPTION_SCHEMA:${_format(key)}');
      }
      result[key] = schema;
    }
    return result;
  }

  List<Map<String, Object?>> _flatten(
    OptionSchemaKey key,
    Map<OptionSchemaKey, Map<String, Object?>> schemas, {
    required List<OptionSchemaKey> stack,
    required Set<String> parameterIds,
  }) {
    if (stack.contains(key)) {
      throw FormatException(
        'OPTION_SCHEMA_CYCLE:'
        '${[...stack, key].map(_format).join('->')}',
      );
    }
    final schema = schemas[key];
    if (schema == null) {
      throw FormatException(
        'OPTION_SCHEMA_REFERENCE_NOT_FOUND:${_format(key)}',
      );
    }

    final result = <Map<String, Object?>>[];
    final nextStack = [...stack, key];
    if (schema.containsKey('includeSchemaIds')) {
      final rawIncludes = schema['includeSchemaIds'];
      if (rawIncludes is! List<Object?> || rawIncludes.isEmpty) {
        throw const FormatException('OPTION_SCHEMA_INCLUDES_MUST_BE_NON_EMPTY');
      }
      final includedKeys = <OptionSchemaKey>{};
      for (final rawReference in rawIncludes) {
        final reference = _object(rawReference, 'included option schema');
        if (reference.keys.toSet().difference(const {
              'id',
              'revision',
            }).isNotEmpty ||
            !reference.keys.toSet().containsAll(const {'id', 'revision'})) {
          throw const FormatException('INVALID_OPTION_SCHEMA_REFERENCE');
        }
        final includedKey = _recordKey(reference, 'included option schema');
        if (!includedKeys.add(includedKey)) {
          throw FormatException(
            'DUPLICATE_OPTION_SCHEMA_REFERENCE:${_format(includedKey)}',
          );
        }
        result.addAll(
          _flatten(
            includedKey,
            schemas,
            stack: nextStack,
            parameterIds: parameterIds,
          ),
        );
      }
    }

    final rawParameters = schema['parameters'];
    if (rawParameters is! List<Object?>) {
      throw const FormatException('OPTION_SCHEMA_PARAMETERS_MUST_BE_A_LIST');
    }
    for (final rawParameter in rawParameters) {
      final parameter = _object(rawParameter, 'option parameter');
      final id = parameter['id'];
      if (id is! String || id.trim().isEmpty) {
        throw const FormatException('OPTION_PARAMETER_ID_REQUIRED');
      }
      if (!parameterIds.add(id)) {
        throw FormatException('DUPLICATE_OPTION_PARAMETER_ID:$id');
      }
      result.add(parameter);
    }
    return result;
  }

  OptionSchemaKey _recordKey(Map<String, Object?> value, String label) {
    final id = value['id'];
    final revision = value['revision'];
    if (id is! String || id.trim().isEmpty) {
      throw FormatException('$label id must be a non-empty string.');
    }
    if (revision is! int || revision <= 0) {
      throw FormatException('$label revision must be positive.');
    }
    return (id: id, revision: revision);
  }

  Map<String, Object?> _object(Object? value, String label) =>
      value is Map<String, Object?>
      ? value
      : throw FormatException('$label must be an object.');

  String _format(OptionSchemaKey key) => '${key.id}@${key.revision}';
}
