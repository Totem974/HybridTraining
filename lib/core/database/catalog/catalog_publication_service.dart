import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

final class CatalogPublicationException implements Exception {
  const CatalogPublicationException(this.issues);

  final List<String> issues;
}

abstract interface class CatalogSignatureVerifier {
  Future<bool> verify({
    required Uint8List canonicalBytes,
    required String signature,
    required String keyId,
    required String algorithm,
  });
}

final class CatalogPublicationService {
  const CatalogPublicationService({this.signatureVerifier});

  final CatalogSignatureVerifier? signatureVerifier;

  Future<String> computeContentHash(
    DatabaseExecutor database, {
    required String catalogVersionId,
  }) async {
    final bytes = await computeCanonicalBytes(
      database,
      catalogVersionId: catalogVersionId,
    );
    return CatalogCanonicalHasher.sha256Hex(bytes);
  }

  Future<Uint8List> computeCanonicalBytes(
    DatabaseExecutor database, {
    required String catalogVersionId,
  }) async {
    final versions = await database.query(
      'catalog_versions',
      where: 'id=?',
      whereArgs: [catalogVersionId],
    );
    if (versions.length != 1) {
      throw const CatalogPublicationException(['version.not_found']);
    }
    final version = versions.single;
    final payload = <String, Object?>{
      'canonicalizationVersion': version['canonicalization_version'],
      'version': {
        for (final key in const [
          'id',
          'ordinal',
          'parent_version_id',
          'signature_key_id',
          'signature_algorithm',
          'trust_channel',
        ])
          key: version[key],
      },
      'tables': <String, Object?>{},
    };
    final tablesPayload = payload['tables']! as Map<String, Object?>;
    final tableRows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    for (final row in tableRows) {
      final table = row['name']! as String;
      if (table == 'catalog_versions' ||
          table == 'catalog_publication_validations' ||
          const {
            'books',
            'editions',
            'sources',
            'modules',
            'catalog_staging_entries',
            'catalog_import_blockers',
          }.contains(table)) {
        continue;
      }
      final columns = await database.rawQuery('PRAGMA table_info($table)');
      if (!columns.any((column) => column['name'] == 'catalog_version_id')) {
        continue;
      }
      tablesPayload[table] = _sortedRows(
        await database.query(
          table,
          where: 'catalog_version_id=?',
          whereArgs: [catalogVersionId],
        ),
      );
    }
    tablesPayload['sources'] = _sortedRows(
      await database.rawQuery(
        'SELECT DISTINCT s.* FROM sources s JOIN evidence e ON e.source_id=s.id WHERE e.catalog_version_id=?',
        [catalogVersionId],
      ),
    );
    tablesPayload['editions'] = _sortedRows(
      await database.rawQuery(
        'SELECT DISTINCT d.* FROM editions d JOIN sources s ON s.edition_id=d.id JOIN evidence e ON e.source_id=s.id WHERE e.catalog_version_id=?',
        [catalogVersionId],
      ),
    );
    tablesPayload['books'] = _sortedRows(
      await database.rawQuery(
        'SELECT DISTINCT b.* FROM books b JOIN editions d ON d.book_id=b.id JOIN sources s ON s.edition_id=d.id JOIN evidence e ON e.source_id=s.id WHERE e.catalog_version_id=?',
        [catalogVersionId],
      ),
    );
    tablesPayload['modules'] = _sortedRows(
      await database.rawQuery(
        'SELECT DISTINCT m.* FROM modules m JOIN module_versions mv ON mv.module_id=m.id WHERE mv.catalog_version_id=?',
        [catalogVersionId],
      ),
    );
    return Uint8List.fromList(utf8.encode(jsonEncode(_canonicalize(payload))));
  }

  Future<void> publish(
    Database database, {
    required String catalogVersionId,
    required String publishedAt,
  }) => database.transaction((transaction) async {
    final versions = await transaction.query(
      'catalog_versions',
      where: 'id=?',
      whereArgs: [catalogVersionId],
    );
    if (versions.length != 1) {
      throw const CatalogPublicationException(['version.not_found']);
    }
    final version = versions.single;
    final issues = <String>[];
    if (version['status'] != 'approved') issues.add('version.not_approved');
    if (version['canonicalization_version'] != 1) {
      issues.add('version.canonicalization_unsupported');
    }
    var signatureValid = false;
    if (version['trust_channel'] == 'signedRemote') {
      final signature = version['signature'] as String?;
      final keyId = version['signature_key_id'] as String?;
      final algorithm = version['signature_algorithm'] as String?;
      final verifier = signatureVerifier;
      if (signature == null ||
          keyId == null ||
          algorithm == null ||
          verifier == null) {
        issues.add('version.signature_unverified');
      } else {
        signatureValid = await verifier.verify(
          canonicalBytes: await computeCanonicalBytes(
            transaction,
            catalogVersionId: catalogVersionId,
          ),
          signature: signature,
          keyId: keyId,
          algorithm: algorithm,
        );
        if (!signatureValid) issues.add('version.signature_unverified');
      }
    }
    final computedHash = await computeContentHash(
      transaction,
      catalogVersionId: catalogVersionId,
    );
    if (version['content_hash'] != computedHash) {
      issues.add('version.hash_mismatch');
    }

    final blockingImports = await transaction.query(
      'catalog_import_blockers',
      columns: const ['issue_code'],
      where: 'catalog_version_id=? AND severity IN (?,?)',
      whereArgs: [catalogVersionId, 'publishBlocker', 'error'],
    );
    final blockersClear = blockingImports.isEmpty;
    if (!blockersClear) {
      issues.add('blockers.not_clear');
      issues.addAll({
        for (final blocker in blockingImports)
          'blocker.${blocker['issue_code']! as String}',
      });
    }

    final entries = await transaction.query(
      'catalog_entries',
      where: 'catalog_version_id=?',
      whereArgs: [catalogVersionId],
    );
    if (entries.isEmpty) issues.add('entries.empty');
    for (final entry in entries) {
      final id = entry['id']! as String;
      final visible = entry['visibility'] == 'visible';
      final executable = entry['execution_status'] == 'executable';
      if (visible && entry['review_status'] != 'confirmed') {
        issues.add('entry.$id.review');
      }
      if (visible &&
          !const {
            'ownedReference',
            'compatible',
          }.contains(entry['license_status'])) {
        issues.add('entry.$id.licence');
      }
      if (executable) {
        if ((await transaction.rawQuery(
          "SELECT 1 FROM evidence WHERE catalog_version_id=? AND subject_type='catalogEntry' AND subject_id=? AND review_status='confirmed' LIMIT 1",
          [catalogVersionId, id],
        )).isEmpty) {
          issues.add('entry.$id.evidence');
        }
        if ((await transaction.rawQuery(
          "SELECT 1 FROM templates t JOIN variants v ON v.template_id=t.id JOIN engine_bindings b ON b.variant_id=v.id WHERE t.catalog_entry_id=? AND t.catalog_version_id=? AND b.status='executable' LIMIT 1",
          [id, catalogVersionId],
        )).isEmpty) {
          issues.add('entry.$id.binding');
        }
        await _validateExecutableChildEvidence(
          transaction,
          catalogVersionId,
          id,
          issues,
        );
      }
    }
    await _validatePolymorphicReferences(transaction, catalogVersionId, issues);
    await _validateRuleEvidence(transaction, catalogVersionId, issues);
    await _validateExecutableGraphEvidence(
      transaction,
      catalogVersionId,
      issues,
    );
    if ((await transaction.rawQuery(
      "SELECT 1 FROM catalog_entry_relations r JOIN catalog_entries d ON d.id=r.to_entry_id WHERE r.catalog_version_id=? AND r.kind='dependency' AND (d.review_status!='confirmed' OR d.implementation_status!='implemented' OR d.execution_status='blocked' OR d.license_status NOT IN ('ownedReference','compatible')) LIMIT 1",
      [catalogVersionId],
    )).isNotEmpty) {
      issues.add('dependencies.invalid');
    }
    if ((await transaction.rawQuery(
      "SELECT 1 FROM module_versions WHERE catalog_version_id=? AND review_status!='confirmed' LIMIT 1",
      [catalogVersionId],
    )).isNotEmpty) {
      issues.add('modules.unconfirmed');
    }
    if (issues.isNotEmpty) {
      throw CatalogPublicationException(List.unmodifiable(issues));
    }

    await transaction.insert('catalog_publication_validations', {
      'catalog_version_id': catalogVersionId,
      'validated_content_hash': computedHash,
      'evidence_valid': 1,
      'licences_valid': 1,
      'dependencies_valid': 1,
      'children_valid': 1,
      'blockers_clear': blockersClear ? 1 : 0,
      'signature_valid': signatureValid ? 1 : 0,
      'validated_at': publishedAt,
    });
    if (version['trust_channel'] == 'signedRemote') {
      await transaction.update(
        'catalog_versions',
        {'signature_verified': signatureValid ? 1 : 0},
        where: 'id=?',
        whereArgs: [catalogVersionId],
      );
    }
    await transaction.update(
      'catalog_versions',
      {'status': 'published', 'published_at': publishedAt},
      where: 'id=?',
      whereArgs: [catalogVersionId],
    );
  });

  static Future<void> _validateRuleEvidence(
    DatabaseExecutor db,
    String versionId,
    List<String> issues,
  ) async {
    for (final rule in await db.query(
      'declarative_rules',
      columns: const ['id'],
      where: 'catalog_version_id=?',
      whereArgs: [versionId],
    )) {
      final id = rule['id']! as String;
      final evidence = await db.rawQuery(
        "SELECT 1 FROM evidence WHERE catalog_version_id=? AND subject_type='rule' AND subject_id=? AND review_status='confirmed' LIMIT 1",
        [versionId, id],
      );
      if (evidence.isEmpty) issues.add('rule.$id.evidence');
    }
  }

  static Future<void> _validateExecutableGraphEvidence(
    DatabaseExecutor db,
    String versionId,
    List<String> issues,
  ) async {
    const executableSubjects = <(String, String)>[
      (
        'variant',
        "SELECT id FROM variants WHERE catalog_version_id=? AND status='executable'",
      ),
      (
        'schedule',
        "SELECT s.id FROM schedules s JOIN variants v ON v.id=s.variant_id WHERE s.catalog_version_id=? AND v.status='executable'",
      ),
      (
        'finiteProgram',
        "SELECT f.id FROM finite_programs f JOIN templates t ON t.id=f.template_id JOIN catalog_entries e ON e.id=t.catalog_entry_id WHERE f.catalog_version_id=? AND e.execution_status='executable'",
      ),
      (
        'assistancePlan',
        "SELECT a.id FROM assistance_plans a JOIN variants v ON v.id=a.variant_id WHERE a.catalog_version_id=? AND v.status='executable'",
      ),
      (
        'policy',
        "SELECT p.id FROM policies p JOIN variants v ON v.id=p.variant_id WHERE p.catalog_version_id=? AND v.status='executable'",
      ),
    ];
    for (final (subjectType, query) in executableSubjects) {
      for (final row in await db.rawQuery(query, [versionId])) {
        final id = row['id']! as String;
        final evidence = await db.rawQuery(
          "SELECT 1 FROM evidence WHERE catalog_version_id=? AND subject_type=? AND subject_id=? AND review_status='confirmed' LIMIT 1",
          [versionId, subjectType, id],
        );
        if (evidence.isEmpty) issues.add('$subjectType.$id.evidence');
      }
    }
  }

  static Future<void> _validatePolymorphicReferences(
    DatabaseExecutor db,
    String versionId,
    List<String> issues,
  ) async {
    const owners = <String, String>{
      'catalogEntry': 'catalog_entries',
      'template': 'templates',
      'variant': 'variants',
      'moduleVersion': 'module_versions',
      'schedule': 'schedules',
      'finiteProgram': 'finite_programs',
      'movement': 'movements',
      'assistancePlan': 'assistance_plans',
      'policy': 'policies',
    };
    for (final rule in await db.query(
      'declarative_rules',
      where: 'catalog_version_id=?',
      whereArgs: [versionId],
    )) {
      final table = owners[rule['owner_type']];
      if (table == null ||
          (await db.query(
            table,
            columns: const ['id'],
            where: 'id=? AND catalog_version_id=?',
            whereArgs: [rule['owner_id'], versionId],
            limit: 1,
          )).isEmpty) {
        issues.add('rule.${rule['id']}.owner');
      }
    }
    const evidenceSubjects = <String, String>{
      ...owners,
      'rule': 'declarative_rules',
    };
    for (final evidence in await db.query(
      'evidence',
      where: 'catalog_version_id=?',
      whereArgs: [versionId],
    )) {
      final table = evidenceSubjects[evidence['subject_type']];
      if (table == null ||
          (await db.query(
            table,
            columns: const ['id'],
            where: 'id=? AND catalog_version_id=?',
            whereArgs: [evidence['subject_id'], versionId],
            limit: 1,
          )).isEmpty) {
        issues.add('evidence.${evidence['id']}.subject');
      }
    }
  }

  static Future<void> _validateExecutableChildEvidence(
    DatabaseExecutor db,
    String versionId,
    String entryId,
    List<String> issues,
  ) async {
    const children = <(String, String, String)>[
      ('templates', 'template', 'catalog_entry_id'),
      ('module_versions', 'moduleVersion', 'catalog_entry_id'),
      ('movements', 'movement', 'catalog_entry_id'),
    ];
    for (final (table, subjectType, ownerColumn) in children) {
      for (final child in await db.query(
        table,
        columns: const ['id'],
        where: 'catalog_version_id=? AND $ownerColumn=?',
        whereArgs: [versionId, entryId],
      )) {
        final childId = child['id']! as String;
        final evidence = await db.rawQuery(
          "SELECT 1 FROM evidence WHERE catalog_version_id=? AND subject_type=? AND subject_id=? AND review_status='confirmed' LIMIT 1",
          [versionId, subjectType, childId],
        );
        if (evidence.isEmpty) {
          issues.add('$subjectType.$childId.evidence');
        }
      }
    }
  }
}

List<Map<String, Object?>> _sortedRows(List<Map<String, Object?>> rows) {
  final copied = [for (final row in rows) Map<String, Object?>.from(row)];
  copied.sort(
    (a, b) =>
        jsonEncode(_canonicalize(a)).compareTo(jsonEncode(_canonicalize(b))),
  );
  return copied;
}

Object? _canonicalize(Object? value) => switch (value) {
  Map map => {
    for (final key in map.keys.map((key) => key.toString()).toList()..sort())
      key: _canonicalize(map[key]),
  },
  Iterable iterable => [for (final item in iterable) _canonicalize(item)],
  _ => value,
};

abstract final class CatalogCanonicalHasher {
  static String sha256Hex(List<int> input) {
    const initial = <int>[
      0x6a09e667,
      0xbb67ae85,
      0x3c6ef372,
      0xa54ff53a,
      0x510e527f,
      0x9b05688c,
      0x1f83d9ab,
      0x5be0cd19,
    ];
    const constants = <int>[
      0x428a2f98,
      0x71374491,
      0xb5c0fbcf,
      0xe9b5dba5,
      0x3956c25b,
      0x59f111f1,
      0x923f82a4,
      0xab1c5ed5,
      0xd807aa98,
      0x12835b01,
      0x243185be,
      0x550c7dc3,
      0x72be5d74,
      0x80deb1fe,
      0x9bdc06a7,
      0xc19bf174,
      0xe49b69c1,
      0xefbe4786,
      0x0fc19dc6,
      0x240ca1cc,
      0x2de92c6f,
      0x4a7484aa,
      0x5cb0a9dc,
      0x76f988da,
      0x983e5152,
      0xa831c66d,
      0xb00327c8,
      0xbf597fc7,
      0xc6e00bf3,
      0xd5a79147,
      0x06ca6351,
      0x14292967,
      0x27b70a85,
      0x2e1b2138,
      0x4d2c6dfc,
      0x53380d13,
      0x650a7354,
      0x766a0abb,
      0x81c2c92e,
      0x92722c85,
      0xa2bfe8a1,
      0xa81a664b,
      0xc24b8b70,
      0xc76c51a3,
      0xd192e819,
      0xd6990624,
      0xf40e3585,
      0x106aa070,
      0x19a4c116,
      0x1e376c08,
      0x2748774c,
      0x34b0bcb5,
      0x391c0cb3,
      0x4ed8aa4a,
      0x5b9cca4f,
      0x682e6ff3,
      0x748f82ee,
      0x78a5636f,
      0x84c87814,
      0x8cc70208,
      0x90befffa,
      0xa4506ceb,
      0xbef9a3f7,
      0xc67178f2,
    ];
    final bytes = BytesBuilder(copy: false)
      ..add(input)
      ..addByte(0x80);
    final bitLength = input.length * 8;
    while ((bytes.length + 8) % 64 != 0) {
      bytes.addByte(0);
    }
    final lengthBytes = ByteData(8)..setUint64(0, bitLength, Endian.big);
    bytes.add(lengthBytes.buffer.asUint8List());
    final data = bytes.takeBytes();
    final hash = List<int>.of(initial);
    int rotate(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xffffffff;
    for (var offset = 0; offset < data.length; offset += 64) {
      final words = List<int>.filled(64, 0);
      final chunk = ByteData.sublistView(data, offset, offset + 64);
      for (var i = 0; i < 16; i++) {
        words[i] = chunk.getUint32(i * 4, Endian.big);
      }
      for (var i = 16; i < 64; i++) {
        final s0 =
            rotate(words[i - 15], 7) ^
            rotate(words[i - 15], 18) ^
            (words[i - 15] >>> 3);
        final s1 =
            rotate(words[i - 2], 17) ^
            rotate(words[i - 2], 19) ^
            (words[i - 2] >>> 10);
        words[i] = (words[i - 16] + s0 + words[i - 7] + s1) & 0xffffffff;
      }
      var a = hash[0],
          b = hash[1],
          c = hash[2],
          d = hash[3],
          e = hash[4],
          f = hash[5],
          g = hash[6],
          h = hash[7];
      for (var i = 0; i < 64; i++) {
        final s1 = rotate(e, 6) ^ rotate(e, 11) ^ rotate(e, 25);
        final ch = (e & f) ^ ((~e) & g);
        final t1 = (h + s1 + ch + constants[i] + words[i]) & 0xffffffff;
        final s0 = rotate(a, 2) ^ rotate(a, 13) ^ rotate(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final t2 = (s0 + maj) & 0xffffffff;
        h = g;
        g = f;
        f = e;
        e = (d + t1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (t1 + t2) & 0xffffffff;
      }
      hash[0] = (hash[0] + a) & 0xffffffff;
      hash[1] = (hash[1] + b) & 0xffffffff;
      hash[2] = (hash[2] + c) & 0xffffffff;
      hash[3] = (hash[3] + d) & 0xffffffff;
      hash[4] = (hash[4] + e) & 0xffffffff;
      hash[5] = (hash[5] + f) & 0xffffffff;
      hash[6] = (hash[6] + g) & 0xffffffff;
      hash[7] = (hash[7] + h) & 0xffffffff;
    }
    return hash.map((word) => word.toRadixString(16).padLeft(8, '0')).join();
  }
}
