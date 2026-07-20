import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/data/forever_series_configuration_repository.dart';
import 'package:hybrid_training/features/poc_531/data/src/forever_series_storage.dart';

void main() {
  group('createSeriesStorageWithFallback', () {
    test('exposes unavailability when the platform getter throws', () {
      final storage = createSeriesStorageWithFallback<Object>(
        getCapability: () => throw StateError('Storage access denied'),
        createStorage: (_) => throw AssertionError('must not be called'),
      );

      expect(storage, isA<UnavailableForeverSeriesStorage>());
      expect(() => storage.read('key'), throwsStateError);
      expect(() => storage.write('key', 'value'), throwsStateError);
    });

    test('also falls back when the platform adapter cannot be created', () {
      final storage = createSeriesStorageWithFallback<Object>(
        getCapability: Object.new,
        createStorage: (_) => throw UnsupportedError('unavailable'),
      );

      expect(storage, isA<UnavailableForeverSeriesStorage>());
      expect(() => storage.read('key'), throwsStateError);
      expect(() => storage.write('key', 'value'), throwsStateError);
    });
  });

  group('LocalForeverSeriesConfigurationRepository', () {
    test('returns null for a missing series', () async {
      final repository = LocalForeverSeriesConfigurationRepository(
        MemoryForeverSeriesStorage(),
      );

      expect(await repository.load('series-a'), isNull);
    });

    test('round-trips and upserts JSON configurations', () async {
      final repository = LocalForeverSeriesConfigurationRepository(
        MemoryForeverSeriesStorage(),
      );
      final first = <String, Object?>{
        'schemaVersion': 4,
        'mode': 'forever',
        'nested': <String, Object?>{
          'values': <Object?>[1, true, 'first'],
        },
      };
      final second = <String, Object?>{
        ...first,
        'nested': <String, Object?>{
          'values': <Object?>[2, false, 'second'],
        },
      };

      await repository.save('series/a', first);
      expect(await repository.load('series/a'), equals(first));

      await repository.save('series/a', second);
      expect(await repository.load('series/a'), equals(second));
    });

    test('factory uses an isolated memory fallback on the VM', () async {
      final first = createLocalForeverSeriesConfigurationRepository();
      final second = createLocalForeverSeriesConfigurationRepository();
      await first.save('series-a', const {'value': 1});

      expect(await first.load('series-a'), const {'value': 1});
      expect(await second.load('series-a'), isNull);
    });

    test('rejects malformed or mismatched storage envelopes', () async {
      final values = <String, String>{};
      final repository = LocalForeverSeriesConfigurationRepository(
        MemoryForeverSeriesStorage(values),
      );
      const prefix = LocalForeverSeriesConfigurationRepository.storageKeyPrefix;

      values['${prefix}series-a'] = '{not-json';
      await expectLater(repository.load('series-a'), throwsFormatException);

      values['${prefix}series-a'] =
          '{"storageSchemaVersion":1,"seriesId":"other",'
          '"configuration":{}}';
      await expectLater(repository.load('series-a'), throwsFormatException);
    });
  });
}
