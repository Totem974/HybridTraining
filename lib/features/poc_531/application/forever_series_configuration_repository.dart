import 'poc_531_configuration_codec.dart';

/// Persistence boundary for a finite Forever-series configuration.
///
/// Implementations may use SQLite, files, or memory. The application contract
/// deliberately exposes transport values so it stays independent from Flutter
/// and from any persistence technology.
abstract interface class ForeverSeriesConfigurationRepository {
  Future<Map<String, Object?>?> load(String seriesId);

  Future<void> save(String seriesId, Map<String, Object?> configuration);
}

/// Validates and isolates v4 Forever-series values at the persistence boundary.
final class ForeverSeriesConfigurationStore {
  const ForeverSeriesConfigurationStore(
    this._repository, {
    this._codec = const Poc531ConfigurationCodec(),
  });

  final ForeverSeriesConfigurationRepository _repository;
  final Poc531ConfigurationCodec _codec;

  Future<Map<String, Object?>?> load(String seriesId) async {
    _validateSeriesId(seriesId);
    final stored = await _repository.load(seriesId);
    if (stored == null) return null;
    return _validatedSnapshot(seriesId, stored);
  }

  Future<void> save(String seriesId, Map<String, Object?> configuration) async {
    _validateSeriesId(seriesId);
    final snapshot = _validatedSnapshot(seriesId, configuration);
    await _repository.save(seriesId, snapshot);
  }

  Map<String, Object?> _validatedSnapshot(
    String seriesId,
    Map<String, Object?> configuration,
  ) {
    if (configuration['schemaVersion'] != Poc531Configuration.schemaVersion) {
      throw const FormatException(
        'A persisted Forever series must use schema version 4.',
      );
    }
    if (configuration['mode'] != 'forever') {
      throw const FormatException(
        'A persisted Forever series must use forever mode.',
      );
    }

    final decoded = _codec.decodeMap(_mutableCopy(configuration));
    final forever = decoded.forever;
    final series = forever?['series'];
    if (series is! Map) {
      throw const FormatException(
        'A persisted Forever series must contain forever.series.',
      );
    }
    if (series['id'] != seriesId) {
      throw FormatException(
        'The configuration series ID (${series['id']}) does not match '
        'the repository key ($seriesId).',
      );
    }
    return _freezeMap(decoded.toJson());
  }

  static void _validateSeriesId(String seriesId) {
    if (seriesId.trim().isEmpty) {
      throw const FormatException('The series ID must not be empty.');
    }
  }
}

Map<String, Object?> _mutableCopy(Map<String, Object?> source) => {
  for (final entry in source.entries) entry.key: _copyValue(entry.value),
};

Object? _copyValue(Object? value) => switch (value) {
  Map map => <String, Object?>{
    for (final entry in map.entries)
      entry.key.toString(): _copyValue(entry.value),
  },
  List list => <Object?>[for (final item in list) _copyValue(item)],
  _ => value,
};

Map<String, Object?> _freezeMap(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable({
      for (final entry in source.entries) entry.key: _freezeValue(entry.value),
    });

Object? _freezeValue(Object? value) => switch (value) {
  Map map => Map<String, Object?>.unmodifiable({
    for (final entry in map.entries)
      entry.key.toString(): _freezeValue(entry.value),
  }),
  List list => List<Object?>.unmodifiable(
    list.map<Object?>((item) => _freezeValue(item)),
  ),
  _ => value,
};
