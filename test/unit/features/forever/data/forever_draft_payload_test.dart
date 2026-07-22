import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/forever/data/forever_draft_payload.dart';
import 'package:hybrid_training/features/forever/data/forever_json_export.dart';
import 'package:hybrid_training/features/forever/data/sqlite_forever_draft_repository.dart';

void main() {
  const node = ForeverDraftNodePayload(
    id: 'c1',
    role: 'leader',
    templateId: 'bbb',
    variantId: 'leader',
    configuration: {
      'parameters': {'tmRatio': 85},
      'warmUp': true,
      'joker': false,
      'assistance': ['push', 'pull'],
      'conditioning': 'easy',
      'schedule': ['squat', 'bench'],
    },
  );

  test('v2 payload preserves complete custom editor state', () {
    final payload = ForeverDraftPayload(
      mode: ForeverDraftMode.custom,
      startDate: DateTime.utc(2026, 8, 1),
      architecture: const [node],
      trainingMaxCentiUnits: const {'squat': 10000, 'bench': 7500},
      equipment: const {
        'unit': 'kg',
        'barCentiUnits': 2000,
        'plates': [2500, 2000, 1500, 1000, 500, 250],
      },
      globalOptions: const {
        'roundingCentiUnits': 250,
        'trainingDays': [1, 3, 5],
      },
    );
    final decoded = ForeverDraftPayload.decode(
      payloadVersion: ForeverDraftPayload.currentVersion,
      definitionId: 'user-defined',
      payload: jsonDecode(payload.toCanonicalJson()) as Map<String, Object?>,
    );
    expect(decoded.mode, ForeverDraftMode.custom);
    expect(decoded.architecture.single.configuration, node.configuration);
    expect(decoded.trainingMaxCentiUnits, payload.trainingMaxCentiUnits);
    expect(decoded.equipment, payload.equipment);
    expect(decoded.globalOptions, payload.globalOptions);
  });

  test('legacy v1 draft upgrades without losing selections or maxes', () {
    final decoded = ForeverDraftPayload.decode(
      payloadVersion: 1,
      definitionId: 'forever-preset',
      payload: const {
        'startDate': '2026-08-01T00:00:00.000Z',
        'trainingMaxes': {'squat': 10000},
        'selectedCycles': {'leader': 'bbb/leader'},
      },
    );
    expect(decoded.mode, ForeverDraftMode.preset);
    expect(decoded.presetId, 'forever-preset');
    expect(decoded.architecture.single.templateId, 'bbb');
    expect(decoded.architecture.single.variantId, 'leader');
    expect(decoded.trainingMaxCentiUnits, {'squat': 10000});
  });

  test('configuration export is deterministic and round-trips', () {
    final stored = StoredForeverDraft(
      id: 'current',
      payloadVersion: 2,
      definitionId: 'user-defined',
      definitionRevision: 1,
      payload: ForeverDraftPayload(
        mode: ForeverDraftMode.custom,
        startDate: DateTime.utc(2026, 8, 1),
        architecture: const [node],
        trainingMaxCentiUnits: const {'squat': 10000},
        equipment: const {'unit': 'kg'},
        globalOptions: const {'rounding': 250},
      ).toJson(),
      updatedAt: DateTime.utc(2026, 8, 2),
    );
    final first = ForeverJsonExport.configuration(stored);
    final second = ForeverJsonExport.configuration(stored);
    expect(second, first);
    final imported = ForeverJsonExport.importConfiguration(first);
    expect(imported.mode, ForeverDraftMode.custom);
    expect(imported.architecture.single.configuration, node.configuration);
    expect(first, isNot(contains('updatedAt')));
  });

  test('unknown payload and export versions are rejected', () {
    expect(
      () => ForeverDraftPayload.decode(
        payloadVersion: 99,
        definitionId: 'x',
        payload: const {},
      ),
      throwsFormatException,
    );
    expect(
      () => ForeverJsonExport.importConfiguration(
        '{"schema":"hybrid-training.forever","schemaVersion":2,'
        '"kind":"configuration"}',
      ),
      throwsFormatException,
    );
  });
}
