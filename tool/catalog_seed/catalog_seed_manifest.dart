import 'dart:convert';

import 'package:hybrid_training/features/poc_531/catalog/catalog.dart';

const catalogSeedManifestVersion = 1;
const catalogSeedCanonicalizationVersion = 1;
const catalogSeedHashAlgorithm = 'SHA-256';

enum CatalogSeedAuthority { canonical, compatible, userCustom }

enum CatalogSeedReviewStatus { confirmed, needsReview, rejected }

enum CatalogSeedIssueSeverity { info, warning, publishBlocker, error }

enum CatalogSeedTarget { isolatedStaging }

final class CatalogSeedIssue {
  const CatalogSeedIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.catalogueId,
  });

  final CatalogSeedIssueSeverity severity;
  final String code;
  final String message;
  final String? catalogueId;
}

final class CatalogSeedRecord {
  CatalogSeedRecord(Map<String, Object?> values)
    : values = _deepFreezeMap(values),
      canonicalJson = _canonicalJson(values),
      recordHash = computeCatalogSeedSha256(_canonicalJson(values));

  final Map<String, Object?> values;
  final String canonicalJson;
  final String recordHash;
  String get id => values['catalogEntryKey']! as String;
}

final class CatalogSeedManifest {
  CatalogSeedManifest({
    required this.manifestVersion,
    required List<CatalogSeedRecord> records,
    required List<CatalogSeedIssue> issues,
  }) : records = List.unmodifiable(records),
       issues = List.unmodifiable(issues),
       sourceHash = computeCatalogSeedSha256(
         records.map((record) => '${record.id}:${record.recordHash}').join('|'),
       );

  final int manifestVersion;
  final String sourceHash;
  final List<CatalogSeedRecord> records;
  final List<CatalogSeedIssue> issues;
  final CatalogSeedTarget target = CatalogSeedTarget.isolatedStaging;
  final int canonicalizationVersion = catalogSeedCanonicalizationVersion;
  final String hashAlgorithm = catalogSeedHashAlgorithm;

  bool get isSafeToStage =>
      issues.every((issue) => issue.severity != CatalogSeedIssueSeverity.error);

  bool get isSafeToPublish => issues.every(
    (issue) =>
        issue.severity != CatalogSeedIssueSeverity.error &&
        issue.severity != CatalogSeedIssueSeverity.publishBlocker,
  );

  bool get isSafeToImportIntoRuntime => false;
}

CatalogSeedManifest buildCatalogSeedManifest({
  Iterable<CatalogRecord>? sourceRecords,
  Set<String> registeredGeneratorIds = catalogGeneratorStrategies,
  int expectedRecordCount = 354,
}) {
  final source = List<CatalogRecord>.of(
    sourceRecords ?? generatedCatalogEntries,
  );
  final issues = <CatalogSeedIssue>[];
  final records = <CatalogSeedRecord>[];
  final seenIds = <String>{};
  final seenGeneratorIds = <String>{};

  if (source.length != expectedRecordCount) {
    issues.add(
      CatalogSeedIssue(
        severity: CatalogSeedIssueSeverity.error,
        code: 'unexpected_record_count',
        message:
            'Expected $expectedRecordCount records, found ${source.length}.',
      ),
    );
  }

  for (final record in source) {
    final entry = record.definition;
    final attestation = _reviewedAttestations[entry.id];
    if (!RegExp(r'^(OR|BY|FV|PL)-[0-9]{3}$').hasMatch(entry.id)) {
      issues.add(
        CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.error,
          code: 'invalid_historical_id',
          message: 'Historical ID casing or shape was changed.',
          catalogueId: entry.id,
        ),
      );
    }
    if (!seenIds.add(entry.id)) {
      issues.add(
        CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.error,
          code: 'duplicate_catalogue_id',
          message: 'Catalogue id occurs more than once.',
          catalogueId: entry.id,
        ),
      );
    }
    final prefix = entry.id.split('-').first;
    final expected = _prefixClassification[prefix];
    if (expected == null ||
        expected.$1 != entry.generation?.name ||
        expected.$2 != entry.sourceKind.name) {
      issues.add(
        CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.error,
          code: 'prefix_classification_mismatch',
          message: 'ID prefix does not match generation/source classification.',
          catalogueId: entry.id,
        ),
      );
    }
    if (entry.sources.isEmpty ||
        entry.sources.any(
          (source) =>
              source.title.trim().isEmpty || source.pages.trim().isEmpty,
        )) {
      issues.add(
        CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.error,
          code: 'missing_source_provenance',
          message: 'Every staged source requires a title and page location.',
          catalogueId: entry.id,
        ),
      );
    }
    if (!entry.isExecutable &&
        (entry.nonExecutableReason == null ||
            entry.nonExecutableReason!.trim().isEmpty)) {
      issues.add(
        CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.error,
          code: 'missing_non_executable_reason',
          message: 'Non-executable catalogue row has no reason.',
          catalogueId: entry.id,
        ),
      );
    }
    if (entry.isExecutable &&
        entry.nonExecutableReason?.startsWith('NEEDS_REVIEW:') == true) {
      issues.add(
        CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.error,
          code: 'needs_review_marked_executable',
          message: 'A NEEDS_REVIEW row cannot be executable.',
          catalogueId: entry.id,
        ),
      );
    }
    if (entry.generatorId case final generatorId?) {
      if (!seenGeneratorIds.add(generatorId)) {
        issues.add(
          CatalogSeedIssue(
            severity: CatalogSeedIssueSeverity.error,
            code: 'duplicate_generator_id',
            message: 'Generator id is bound more than once.',
            catalogueId: entry.id,
          ),
        );
      }
      if (!registeredGeneratorIds.contains(generatorId)) {
        issues.add(
          CatalogSeedIssue(
            severity: CatalogSeedIssueSeverity.error,
            code: 'unresolved_generator_id',
            message: 'Generator id is not registered.',
            catalogueId: entry.id,
          ),
        );
      }
      if (attestation?.legacyGeneratorId != generatorId) {
        issues.add(
          CatalogSeedIssue(
            severity: CatalogSeedIssueSeverity.error,
            code: 'legacy_binding_attestation_mismatch',
            message: 'Legacy generator binding has no matching attestation.',
            catalogueId: entry.id,
          ),
        );
      }
    } else if (attestation != null) {
      issues.add(
        CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.error,
          code: 'legacy_binding_attestation_mismatch',
          message: 'Attested legacy generator binding is missing from source.',
          catalogueId: entry.id,
        ),
      );
    }

    final values = <String, Object?>{
      'catalogEntryKey': entry.id,
      // A domain identity is assigned only by an explicit reviewed mapping.
      // In particular, it must never be synthesized by lower-casing the key.
      'stableDomainId': null,
      'name': entry.name,
      'family': entry.family,
      'variant': entry.variant,
      'generation': entry.generation?.name,
      'sourceLifecycleStatus': entry.status.name,
      'sourceKind': entry.sourceKind.name,
      'entryKind': entry.entryKind.name,
      'nature': record.nature,
      'ambiguous': record.ambiguity,
      'authority': attestation?.authority.name,
      'reviewStatus':
          attestation?.reviewStatus.name ??
          CatalogSeedReviewStatus.needsReview.name,
      'editorialStatus': 'draft',
      'implementationStatus': attestation == null
          ? 'notStarted'
          : 'implemented',
      'executionStatus': attestation == null ? 'blocked' : 'executable',
      'productSurface': null,
      // Visibility is explicit and conservative: reviewed legacy executable
      // rows remain internal until licence and Cycle v5 mappings are approved.
      'visibility': attestation?.visibility ?? 'hidden',
      'licenseStatus': 'unknown',
      'frequencies': entry.frequencies.toList()..sort(),
      'levels': entry.levels.map((value) => value.name).toList()..sort(),
      'goals': entry.goals.map((value) => value.name).toList()..sort(),
      'sources': [for (final source in entry.sources) source.toJson()],
      'generatorId': entry.generatorId,
      'nonExecutableReason': entry.nonExecutableReason,
      'requiresLeaderAnchor': entry.requiresLeaderAnchor,
      'executable': entry.isExecutable,
      'relations': const <Object?>[],
      'engineBindings': [
        if (attestation?.legacyGeneratorId case final generatorId?)
          <String, Object?>{
            'kind': 'legacyGenerator',
            'engineId': generatorId,
            'reviewStatus': CatalogSeedReviewStatus.confirmed.name,
          },
      ],
      'cycleDefinitionId': null,
      'cycleVariantIds': null,
      'license': null,
    };
    final sensitive = _findSensitiveValue(values);
    if (sensitive != null) {
      issues.add(
        CatalogSeedIssue(
          severity: CatalogSeedIssueSeverity.error,
          code: 'protected_or_personal_data',
          message: 'Protected path or personal identifier found in output.',
          catalogueId: entry.id,
        ),
      );
    }
    records.add(CatalogSeedRecord(values));
  }

  issues.addAll(const [
    CatalogSeedIssue(
      severity: CatalogSeedIssueSeverity.publishBlocker,
      code: 'authority_review_attestations_missing',
      message:
          'Authority and positive review are absent unless explicitly '
          'attested; legacy sourceKind/executability are not evidence.',
    ),
    CatalogSeedIssue(
      severity: CatalogSeedIssueSeverity.warning,
      code: 'relationship_metadata_not_in_source',
      message: 'Parent/child and alias relationships require reviewed mapping.',
    ),
    CatalogSeedIssue(
      severity: CatalogSeedIssueSeverity.publishBlocker,
      code: 'cycle_engine_bindings_not_in_source',
      message: 'Cycle v5 definition/variant bindings require reviewed mapping.',
    ),
    CatalogSeedIssue(
      severity: CatalogSeedIssueSeverity.publishBlocker,
      code: 'stable_domain_ids_not_reviewed',
      message:
          'All stable domain ids require an explicit reviewed mapping; none '
          'is derived from historical catalogue keys.',
    ),
    CatalogSeedIssue(
      severity: CatalogSeedIssueSeverity.publishBlocker,
      code: 'license_metadata_not_in_source',
      message: 'Publication requires explicit licence metadata.',
    ),
  ]);
  if (records.any(
    (record) =>
        record.values['reviewStatus'] ==
        CatalogSeedReviewStatus.needsReview.name,
  )) {
    issues.add(
      const CatalogSeedIssue(
        severity: CatalogSeedIssueSeverity.publishBlocker,
        code: 'needs_review_records_present',
        message: 'NEEDS_REVIEW records may be staged but not published.',
      ),
    );
  }

  records.sort((left, right) => left.id.compareTo(right.id));
  return CatalogSeedManifest(
    manifestVersion: catalogSeedManifestVersion,
    records: records,
    issues: issues,
  );
}

const _prefixClassification = <String, (String, String)>{
  'OR': ('original', 'canonical'),
  'BY': ('beyond', 'canonical'),
  'FV': ('forever', 'canonical'),
  'PL': ('original', 'supplement'),
};

final class _ReviewedAttestation {
  const _ReviewedAttestation({
    required this.authority,
    required this.reviewStatus,
    required this.visibility,
    required this.legacyGeneratorId,
  });

  final CatalogSeedAuthority authority;
  final CatalogSeedReviewStatus reviewStatus;
  final String visibility;
  final String legacyGeneratorId;
}

const _reviewedAttestations = <String, _ReviewedAttestation>{
  'BY-026': _ReviewedAttestation(
    authority: CatalogSeedAuthority.canonical,
    reviewStatus: CatalogSeedReviewStatus.confirmed,
    visibility: 'internal',
    legacyGeneratorId: 'canonical-beyond',
  ),
  'FV-141': _ReviewedAttestation(
    authority: CatalogSeedAuthority.canonical,
    reviewStatus: CatalogSeedReviewStatus.confirmed,
    visibility: 'internal',
    legacyGeneratorId: 'canonical-bps',
  ),
  'FV-236': _ReviewedAttestation(
    authority: CatalogSeedAuthority.canonical,
    reviewStatus: CatalogSeedReviewStatus.confirmed,
    visibility: 'internal',
    legacyGeneratorId: 'canonical-forever-original-fsl',
  ),
  'PL-001': _ReviewedAttestation(
    authority: CatalogSeedAuthority.compatible,
    reviewStatus: CatalogSeedReviewStatus.confirmed,
    visibility: 'internal',
    legacyGeneratorId: 'canonical-powerlifting',
  ),
};

Map<String, Object?> _deepFreezeMap(Map<String, Object?> source) =>
    Map.unmodifiable({
      for (final entry in source.entries) entry.key: _deepFreeze(entry.value),
    });

Object? _deepFreeze(Object? value) => switch (value) {
  Map map => Map.unmodifiable({
    for (final entry in map.entries)
      entry.key.toString(): _deepFreeze(entry.value),
  }),
  Iterable iterable => List.unmodifiable(iterable.map(_deepFreeze)),
  _ => value,
};

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) => switch (value) {
  Map map => {
    for (final key in map.keys.map((key) => key.toString()).toList()..sort())
      key: _canonicalize(map[key]),
  },
  Iterable iterable => [for (final item in iterable) _canonicalize(item)],
  _ => value,
};

/// SHA-256 over UTF-8 bytes. Kept local so the neutral tool does not rely on
/// an undeclared transitive package dependency.
String computeCatalogSeedSha256(String value) {
  final bytes = utf8.encode(value).toList();
  final bitLength = bytes.length * 8;
  bytes.add(0x80);
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  for (var shift = 56; shift >= 0; shift -= 8) {
    bytes.add((bitLength >> shift) & 0xff);
  }

  final hash = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  final words = List<int>.filled(64, 0);
  for (var offset = 0; offset < bytes.length; offset += 64) {
    for (var index = 0; index < 16; index++) {
      final start = offset + index * 4;
      words[index] =
          (bytes[start] << 24) |
          (bytes[start + 1] << 16) |
          (bytes[start + 2] << 8) |
          bytes[start + 3];
    }
    for (var index = 16; index < 64; index++) {
      final s0 =
          _rotateRight(words[index - 15], 7) ^
          _rotateRight(words[index - 15], 18) ^
          (words[index - 15] >>> 3);
      final s1 =
          _rotateRight(words[index - 2], 17) ^
          _rotateRight(words[index - 2], 19) ^
          (words[index - 2] >>> 10);
      words[index] =
          (words[index - 16] + s0 + words[index - 7] + s1) & 0xffffffff;
    }

    var a = hash[0];
    var b = hash[1];
    var c = hash[2];
    var d = hash[3];
    var e = hash[4];
    var f = hash[5];
    var g = hash[6];
    var h = hash[7];
    for (var index = 0; index < 64; index++) {
      final sum1 =
          _rotateRight(e, 6) ^ _rotateRight(e, 11) ^ _rotateRight(e, 25);
      final choice = (e & f) ^ ((~e) & g);
      final temp1 =
          (h + sum1 + choice + _sha256Constants[index] + words[index]) &
          0xffffffff;
      final sum0 =
          _rotateRight(a, 2) ^ _rotateRight(a, 13) ^ _rotateRight(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (sum0 + majority) & 0xffffffff;
      h = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }
    final compressed = [a, b, c, d, e, f, g, h];
    for (var index = 0; index < 8; index++) {
      hash[index] = (hash[index] + compressed[index]) & 0xffffffff;
    }
  }
  return hash.map((word) => word.toRadixString(16).padLeft(8, '0')).join();
}

int _rotateRight(int value, int count) =>
    ((value >>> count) | (value << (32 - count))) & 0xffffffff;

const _sha256Constants = <int>[
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

String? _findSensitiveValue(Object? value) {
  for (final text in _strings(value)) {
    if (RegExp(
          r'(^|[\\/])\.SOURCE([\\/]|$)',
          caseSensitive: false,
        ).hasMatch(text) ||
        RegExp(
          r'(^|[\\/])reference([\\/]|$)',
          caseSensitive: false,
        ).hasMatch(text) ||
        RegExp(r'\b[A-Za-z]:[\\/]').hasMatch(text) ||
        RegExp(r'\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b').hasMatch(text) ||
        RegExp(
          r'firebase|api[_-]?key|certificate',
          caseSensitive: false,
        ).hasMatch(text)) {
      return text;
    }
  }
  return null;
}

Iterable<String> _strings(Object? value) sync* {
  switch (value) {
    case String text:
      yield text;
    case Map map:
      for (final entry in map.entries) {
        yield entry.key.toString();
        yield* _strings(entry.value);
      }
    case Iterable iterable:
      for (final item in iterable) {
        yield* _strings(item);
      }
  }
}
