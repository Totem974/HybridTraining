import 'dart:convert';

import 'forever_draft_payload.dart';
import 'sqlite_forever_draft_repository.dart';
import 'sqlite_forever_macrocycle_repository.dart';

final class ForeverJsonExport {
  const ForeverJsonExport._();

  static const schema = 'hybrid-training.forever';
  static const schemaVersion = 1;

  static String configuration(StoredForeverDraft draft) {
    final decoded = ForeverDraftPayload.decode(
      payloadVersion: draft.payloadVersion,
      definitionId: draft.definitionId,
      payload: draft.payload,
    );
    return canonicalJson({
      'schema': schema,
      'schemaVersion': schemaVersion,
      'kind': 'configuration',
      'definition': {
        'id': draft.definitionId,
        'revision': draft.definitionRevision,
      },
      'payloadVersion': ForeverDraftPayload.currentVersion,
      'payload': decoded.toJson(),
    });
  }

  static String result(StoredMacrocycle macrocycle) => canonicalJson({
    'schema': schema,
    'schemaVersion': schemaVersion,
    'kind': 'result',
    'definition': {
      'id': macrocycle.definitionId,
      'revision': macrocycle.definitionRevision,
    },
    'logicalHash': macrocycle.logicalHash,
    'snapshot': macrocycle.snapshot,
  });

  static ForeverDraftPayload importConfiguration(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('Invalid export.');
    final envelope = decoded.cast<String, Object?>();
    if (envelope['schema'] != schema ||
        envelope['schemaVersion'] != schemaVersion ||
        envelope['kind'] != 'configuration') {
      throw const FormatException('Unsupported Forever configuration export.');
    }
    final definition = (envelope['definition'] as Map?)
        ?.cast<String, Object?>();
    if (definition == null || definition['id'] is! String) {
      throw const FormatException('Missing Forever definition.');
    }
    final payload = (envelope['payload'] as Map?)?.cast<String, Object?>();
    if (payload == null) throw const FormatException('Missing payload.');
    return ForeverDraftPayload.decode(
      payloadVersion: envelope['payloadVersion'] as int,
      definitionId: definition['id']! as String,
      payload: payload,
    );
  }
}
