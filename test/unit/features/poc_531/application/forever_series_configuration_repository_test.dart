import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/application/forever_series_configuration_repository.dart';

void main() {
  test(
    'save validates then gives the repository an immutable deep copy',
    () async {
      final repository = _FakeRepository();
      final store = ForeverSeriesConfigurationStore(repository);
      final configuration = _validConfiguration();

      await store.save('series-42', configuration);
      final saved = repository.saved!;
      configuration['mode'] = 'cycle';
      ((_series(configuration)['macrocycles'] as List).first as Map)['status'] =
          'completed';

      expect(saved['mode'], 'forever');
      expect(_firstMacrocycle(saved)['status'], 'active');
      expect(() => saved['mode'] = 'cycle', throwsUnsupportedError);
      expect(
        () => _firstMacrocycle(saved)['status'] = 'completed',
        throwsUnsupportedError,
      );
      expect(
        () => (_series(saved)['macrocycles'] as List).add(<String, Object?>{}),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'load validates stored values and returns an isolated snapshot',
    () async {
      final stored = _validConfiguration();
      final repository = _FakeRepository()..value = stored;
      final store = ForeverSeriesConfigurationStore(repository);

      final loaded = await store.load('series-42');
      _firstMacrocycle(stored)['status'] = 'completed';

      expect(_firstMacrocycle(loaded!)['status'], 'active');
      expect(
        () => _firstMacrocycle(loaded)['status'] = 'completed',
        throwsUnsupportedError,
      );
    },
  );

  test('load preserves absence', () async {
    final store = ForeverSeriesConfigurationStore(_FakeRepository());
    expect(await store.load('series-42'), isNull);
  });

  test(
    'rejects non-v4, non-Forever, standalone and mismatched series',
    () async {
      final store = ForeverSeriesConfigurationStore(_FakeRepository());
      final invalid = <Map<String, Object?>>[
        {..._validConfiguration(), 'schemaVersion': 3},
        {..._validConfiguration(), 'mode': 'cycle'},
        {
          'schemaVersion': 4,
          'mode': 'forever',
          'common': <String, Object?>{},
          'forever': {'standaloneProgramId': 'forever-beginner-prep-school-v1'},
        },
        _validConfiguration(seriesId: 'another-series'),
      ];

      for (final configuration in invalid) {
        await expectLater(
          store.save('series-42', configuration),
          throwsFormatException,
        );
      }
      await expectLater(
        store.save('', _validConfiguration()),
        throwsFormatException,
      );
    },
  );

  test('rejects an incoherent value returned by the repository', () async {
    final repository = _FakeRepository()
      ..value = _validConfiguration(seriesId: 'wrong-key');
    final store = ForeverSeriesConfigurationStore(repository);

    await expectLater(store.load('series-42'), throwsFormatException);
  });
}

final class _FakeRepository implements ForeverSeriesConfigurationRepository {
  Map<String, Object?>? value;
  Map<String, Object?>? saved;

  @override
  Future<Map<String, Object?>?> load(String seriesId) async => value;

  @override
  Future<void> save(String seriesId, Map<String, Object?> configuration) async {
    saved = configuration;
  }
}

Map<String, Object?> _validConfiguration({String seriesId = 'series-42'}) => {
  'schemaVersion': 4,
  'mode': 'forever',
  'common': <String, Object?>{'unit': 'kg'},
  'forever': <String, Object?>{
    'series': <String, Object?>{
      'id': seriesId,
      'terminated': false,
      'macrocycles': <Object?>[_validMacrocycle()],
    },
  },
};

Map<String, Object?> _validMacrocycle() => {
  'instanceId': 'M1',
  'intent': 'active',
  'status': 'active',
  'recipeId': 'forever-2l1a-v2',
  'slots': <Object?>[
    {
      'slotId': 'leader-1',
      'role': 'leader',
      'cycleTemplateRevisionId': 'forever-original-fsl-leader-v1',
    },
    {
      'slotId': 'leader-2',
      'role': 'leader',
      'cycleTemplateRevisionId': 'forever-original-fsl-leader-v1',
    },
    {
      'slotId': 'anchor-1',
      'role': 'anchor',
      'cycleTemplateRevisionId': 'forever-original-pr-set-anchor-v1',
    },
  ],
  'protocols': <Object?>[
    {
      'boundaryId': 'leaders-to-anchor',
      'protocolTemplateRevisionId': 'forever-seventh-week-deload-v1',
      'required': true,
    },
    {
      'boundaryId': 'macrocycle-end',
      'protocolTemplateRevisionId': 'forever-seventh-week-tm-test-v1',
      'required': true,
    },
  ],
  'trainingMaxStates': <String, Object?>{'squat': 'confirmed'},
};

Map<String, Object?> _series(Map<String, Object?> configuration) =>
    ((configuration['forever'] as Map)['series'] as Map)
        .cast<String, Object?>();

Map<String, Object?> _firstMacrocycle(Map<String, Object?> configuration) =>
    ((_series(configuration)['macrocycles'] as List).first as Map)
        .cast<String, Object?>();
