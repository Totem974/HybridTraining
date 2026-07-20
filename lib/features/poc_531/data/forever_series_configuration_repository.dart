import 'dart:convert';

import '../application/forever_series_configuration_repository.dart';
import 'src/forever_series_storage.dart';
import 'src/forever_series_storage_stub.dart'
    if (dart.library.html) 'src/forever_series_storage_web.dart'
    as platform;

/// Creates the local-first repository used by the Forever composer.
///
/// On the Web, values survive browser restarts in `localStorage`. Other
/// platforms use an instance-local memory store until their durable adapter is
/// supplied; this keeps the domain and Android builds independent from Web APIs.
ForeverSeriesConfigurationRepository
createLocalForeverSeriesConfigurationRepository() =>
    LocalForeverSeriesConfigurationRepository(platform.createSeriesStorage());

/// JSON repository over the platform's local key/value storage.
final class LocalForeverSeriesConfigurationRepository
    implements ForeverSeriesConfigurationRepository {
  LocalForeverSeriesConfigurationRepository(this._storage);

  static const storageSchemaVersion = 1;
  static const storageKeyPrefix =
      'hybrid_training.forever_series_configuration.v1.';

  final ForeverSeriesStorage _storage;

  @override
  Future<Map<String, Object?>?> load(String seriesId) async {
    final payload = _storage.read(_key(seriesId));
    if (payload == null) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException catch (error) {
      throw FormatException(
        'Stored Forever series "$seriesId" is not valid JSON: '
        '${error.message}',
      );
    }
    if (decoded is! Map ||
        decoded['storageSchemaVersion'] != storageSchemaVersion ||
        decoded['seriesId'] != seriesId ||
        decoded['configuration'] is! Map) {
      throw FormatException(
        'Stored Forever series "$seriesId" has an invalid envelope.',
      );
    }
    return _stringMap(decoded['configuration']! as Map);
  }

  @override
  Future<void> save(String seriesId, Map<String, Object?> configuration) async {
    final payload = jsonEncode({
      'storageSchemaVersion': storageSchemaVersion,
      'seriesId': seriesId,
      'configuration': configuration,
    });
    _storage.write(_key(seriesId), payload);
  }

  static String _key(String seriesId) =>
      '$storageKeyPrefix${Uri.encodeComponent(seriesId)}';

  static Map<String, Object?> _stringMap(Map<Object?, Object?> source) => {
    for (final entry in source.entries)
      entry.key.toString(): _copyValue(entry.value),
  };

  static Object? _copyValue(Object? value) => switch (value) {
    Map map => _stringMap(map),
    List list => <Object?>[for (final item in list) _copyValue(item)],
    _ => value,
  };
}
