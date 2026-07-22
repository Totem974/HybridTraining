import 'dart:convert';

enum ForeverDraftMode { preset, custom }

final class ForeverDraftNodePayload {
  const ForeverDraftNodePayload({
    required this.id,
    required this.role,
    required this.templateId,
    required this.variantId,
    this.enabled = true,
    this.configuration = const {},
  });

  final String id;
  final String role;
  final String templateId;
  final String variantId;
  final bool enabled;
  final Map<String, Object?> configuration;

  Map<String, Object?> toJson() => {
    'id': id,
    'role': role,
    'templateId': templateId,
    'variantId': variantId,
    'enabled': enabled,
    'configuration': configuration,
  };

  factory ForeverDraftNodePayload.fromJson(Map<String, Object?> json) {
    final id = _string(json, 'id');
    final role = _string(json, 'role');
    final templateId = _string(json, 'templateId');
    final variantId = _string(json, 'variantId');
    final enabled = json['enabled'] ?? true;
    if (enabled is! bool) throw const FormatException('Invalid node enabled.');
    return ForeverDraftNodePayload(
      id: id,
      role: role,
      templateId: templateId,
      variantId: variantId,
      enabled: enabled,
      configuration: _map(json['configuration'] ?? const {}),
    );
  }
}

/// Versioned, UI-independent workspace representation of a Forever editor.
final class ForeverDraftPayload {
  const ForeverDraftPayload({
    required this.mode,
    required this.startDate,
    required this.architecture,
    required this.trainingMaxCentiUnits,
    required this.equipment,
    required this.globalOptions,
    this.presetId,
  });

  static const currentVersion = 2;

  final ForeverDraftMode mode;
  final String? presetId;
  final DateTime startDate;
  final List<ForeverDraftNodePayload> architecture;
  final Map<String, int> trainingMaxCentiUnits;
  final Map<String, Object?> equipment;
  final Map<String, Object?> globalOptions;

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    if (presetId != null) 'presetId': presetId,
    'startDate': startDate.toUtc().toIso8601String(),
    'architecture': architecture.map((node) => node.toJson()).toList(),
    'trainingMaxes': trainingMaxCentiUnits,
    'equipment': equipment,
    'globalOptions': globalOptions,
  };

  factory ForeverDraftPayload.decode({
    required int payloadVersion,
    required String definitionId,
    required Map<String, Object?> payload,
  }) {
    if (payloadVersion == 1) {
      final selected = _map(payload['selectedCycles']);
      return ForeverDraftPayload(
        mode: ForeverDraftMode.preset,
        presetId: definitionId,
        startDate: _date(payload, 'startDate'),
        architecture: selected.entries
            .map((entry) {
              final reference = entry.value;
              if (reference is! String || !reference.contains('/')) {
                throw const FormatException('Invalid legacy Cycle reference.');
              }
              final separator = reference.indexOf('/');
              return ForeverDraftNodePayload(
                id: entry.key,
                role: 'custom',
                templateId: reference.substring(0, separator),
                variantId: reference.substring(separator + 1),
              );
            })
            .toList(growable: false),
        trainingMaxCentiUnits: _intMap(payload['trainingMaxes']),
        equipment: const {},
        globalOptions: const {},
      );
    }
    if (payloadVersion != currentVersion) {
      throw FormatException(
        'Unsupported Forever draft version $payloadVersion.',
      );
    }
    final modeName = _string(payload, 'mode');
    final mode = ForeverDraftMode.values
        .where((value) => value.name == modeName)
        .firstOrNull;
    if (mode == null) throw FormatException('Invalid Forever mode $modeName.');
    final rawArchitecture = payload['architecture'];
    if (rawArchitecture is! List) {
      throw const FormatException('Invalid Forever architecture.');
    }
    final architecture = rawArchitecture
        .map((value) => ForeverDraftNodePayload.fromJson(_map(value)))
        .toList(growable: false);
    if (architecture.isEmpty) {
      throw const FormatException('Forever architecture cannot be empty.');
    }
    final rawPresetId = payload['presetId'];
    if (rawPresetId != null && rawPresetId is! String) {
      throw const FormatException('Invalid preset id.');
    }
    final presetId = rawPresetId as String?;
    if (mode == ForeverDraftMode.preset &&
        (presetId == null || presetId.isEmpty)) {
      throw const FormatException('Preset mode requires a preset id.');
    }
    return ForeverDraftPayload(
      mode: mode,
      presetId: presetId,
      startDate: _date(payload, 'startDate'),
      architecture: architecture,
      trainingMaxCentiUnits: _intMap(payload['trainingMaxes']),
      equipment: _map(payload['equipment']),
      globalOptions: _map(payload['globalOptions']),
    );
  }

  String toCanonicalJson() => canonicalJson(toJson());
}

String canonicalJson(Object? value) => jsonEncode(_canonical(value));

Object? _canonical(Object? value) {
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    return {for (final entry in entries) entry.key: _canonical(entry.value)};
  }
  if (value is List) return value.map(_canonical).toList(growable: false);
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw FormatException('Unsupported JSON value ${value.runtimeType}.');
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) throw const FormatException('Expected JSON object.');
  return value.map((key, item) {
    if (key is! String) throw const FormatException('Expected string key.');
    return MapEntry(key, item);
  });
}

Map<String, int> _intMap(Object? value) => _map(value).map((key, item) {
  if (item is! int) throw const FormatException('Expected integer value.');
  return MapEntry(key, item);
});

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

DateTime _date(Map<String, Object?> json, String key) {
  final value = _string(json, key);
  final date = DateTime.tryParse(value);
  if (date == null) throw FormatException('Invalid $key.');
  return date.toUtc();
}
