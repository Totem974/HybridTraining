import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Stable failure raised before an unverified plan snapshot reaches SQLite.
final class TrainingSnapshotWriteException implements Exception {
  const TrainingSnapshotWriteException(this.code);

  final String code;

  @override
  String toString() => 'TrainingSnapshotWriteException($code)';
}

/// Versioned canonicalization and integrity contract for persisted snapshots.
abstract final class TrainingSnapshotIntegrity {
  static const schemaVersion = 1;
  static const canonicalizationVersion = 1;
  static const hashAlgorithm = 'sha256';

  /// Returns canonical JSON v1: sorted object keys, stable array order and
  /// normalized integral/negative-zero numeric representations.
  static String canonicalize(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const TrainingSnapshotWriteException('snapshot.invalid_json');
    }
    if (decoded is! Map<String, Object?>) {
      throw const TrainingSnapshotWriteException('snapshot.not_object');
    }
    return jsonEncode(_canonicalizeValue(decoded));
  }

  /// Computes the lowercase hexadecimal SHA-256 digest of canonical JSON v1.
  static String hashCanonicalJson(String canonicalJson) =>
      _sha256(utf8.encode(canonicalJson));

  static String hash(String source) => hashCanonicalJson(canonicalize(source));

  static Object? _canonicalizeValue(Object? value) => switch (value) {
    Map<String, Object?> map => {
      for (final key in map.keys.toList()..sort())
        key: _canonicalizeValue(map[key]),
    },
    List<Object?> list => [for (final item in list) _canonicalizeValue(item)],
    double number when number == 0 => 0,
    double number
        when number.abs() <= 9007199254740991 &&
            number == number.truncateToDouble() =>
      number.toInt(),
    _ => value,
  };
}

final class TrainingPlanSnapshotWrite {
  const TrainingPlanSnapshotWrite({
    required this.id,
    required this.athleteId,
    required this.catalogVersionId,
    required this.catalogContentHash,
    required this.snapshotSchemaVersion,
    required this.snapshotCanonicalizationVersion,
    required this.snapshotHashAlgorithm,
    required this.resolvedSnapshotHash,
    required this.resolvedSnapshotJson,
    required this.startsOn,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String athleteId;
  final String catalogVersionId;
  final String catalogContentHash;
  final int snapshotSchemaVersion;
  final int snapshotCanonicalizationVersion;
  final String snapshotHashAlgorithm;
  final String resolvedSnapshotHash;
  final String resolvedSnapshotJson;
  final String startsOn;
  final String status;
  final String createdAt;
  final String? completedAt;
}

/// The only training plan insertion boundary that attests snapshot integrity.
final class TrainingPlanSnapshotRepository {
  const TrainingPlanSnapshotRepository();

  Future<void> create(
    DatabaseExecutor database,
    TrainingPlanSnapshotWrite write,
  ) async {
    _requireSupportedContract(write);
    if (write.status != 'draft' || write.completedAt != null) {
      throw const TrainingSnapshotWriteException('plan.invalid_initial_status');
    }
    final canonicalJson = TrainingSnapshotIntegrity.canonicalize(
      write.resolvedSnapshotJson,
    );
    _ResolvedTrainingSnapshotV1.validate(canonicalJson, write);
    final calculatedHash = TrainingSnapshotIntegrity.hashCanonicalJson(
      canonicalJson,
    );
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(write.resolvedSnapshotHash)) {
      throw const TrainingSnapshotWriteException('snapshot.hash_not_canonical');
    }
    if (write.resolvedSnapshotHash != calculatedHash) {
      throw const TrainingSnapshotWriteException('snapshot.hash_mismatch');
    }

    await database.insert('plans', {
      'id': write.id,
      'athlete_id': write.athleteId,
      'catalog_version_id': write.catalogVersionId,
      'catalog_content_hash': write.catalogContentHash,
      'snapshot_schema_version': write.snapshotSchemaVersion,
      'snapshot_canonicalization_version':
          write.snapshotCanonicalizationVersion,
      'snapshot_hash_algorithm': write.snapshotHashAlgorithm,
      'resolved_snapshot_hash': calculatedHash,
      'resolved_snapshot_json': canonicalJson,
      'starts_on': write.startsOn,
      'status': write.status,
      'created_at': write.createdAt,
      'completed_at': write.completedAt,
    });
  }

  void _requireSupportedContract(TrainingPlanSnapshotWrite write) {
    if (write.snapshotSchemaVersion !=
        TrainingSnapshotIntegrity.schemaVersion) {
      throw const TrainingSnapshotWriteException(
        'snapshot.unsupported_schema_version',
      );
    }
    if (write.snapshotCanonicalizationVersion !=
        TrainingSnapshotIntegrity.canonicalizationVersion) {
      throw const TrainingSnapshotWriteException(
        'snapshot.unsupported_canonicalization_version',
      );
    }
    if (write.snapshotHashAlgorithm !=
        TrainingSnapshotIntegrity.hashAlgorithm) {
      throw const TrainingSnapshotWriteException(
        'snapshot.unsupported_hash_algorithm',
      );
    }
  }
}

abstract final class _ResolvedTrainingSnapshotV1 {
  static void validate(String canonicalJson, TrainingPlanSnapshotWrite write) {
    final root = jsonDecode(canonicalJson) as Map<String, Object?>;
    _requireOnlyKeys(root, const {
      'schemaVersion',
      'catalogVersionId',
      'catalogContentHash',
      'template',
      'schedule',
    });
    if (_requiredInt(root, 'schemaVersion') !=
        TrainingSnapshotIntegrity.schemaVersion) {
      throw const TrainingSnapshotWriteException(
        'snapshot.unsupported_schema_version',
      );
    }
    if (_requiredString(root, 'catalogVersionId') != write.catalogVersionId ||
        _requiredString(root, 'catalogContentHash') !=
            write.catalogContentHash) {
      throw const TrainingSnapshotWriteException('snapshot.identity_mismatch');
    }

    final template = _requiredObject(root, 'template');
    _requireOnlyKeys(template, const {'id', 'revision'});
    _requiredString(template, 'id');
    if (_requiredInt(template, 'revision') <= 0) {
      _invalidStructure();
    }

    final schedule = _requiredObject(root, 'schedule');
    _requireOnlyKeys(schedule, const {'sessions'});
    final sessions = _requiredList(schedule, 'sessions');
    if (sessions.isEmpty) _invalidStructure();
    final sessionIds = <String>{};
    for (var sessionIndex = 0; sessionIndex < sessions.length; sessionIndex++) {
      final session = _object(sessions[sessionIndex]);
      _requireOnlyKeys(session, const {
        'id',
        'sequence',
        'offsetDays',
        'blocks',
      });
      if (!sessionIds.add(_requiredString(session, 'id')) ||
          _requiredInt(session, 'sequence') != sessionIndex ||
          _requiredInt(session, 'offsetDays') < 0) {
        _invalidStructure();
      }
      final blocks = _requiredList(session, 'blocks');
      if (blocks.isEmpty) _invalidStructure();
      final blockIds = <String>{};
      for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
        final block = _object(blocks[blockIndex]);
        _requireOnlyKeys(block, const {'id', 'sequence', 'kind'});
        if (!blockIds.add(_requiredString(block, 'id')) ||
            _requiredInt(block, 'sequence') != blockIndex) {
          _invalidStructure();
        }
        _requiredString(block, 'kind');
      }
    }
  }

  static void _requireOnlyKeys(
    Map<String, Object?> object,
    Set<String> allowed,
  ) {
    if (object.keys.any((key) => !allowed.contains(key))) {
      throw const TrainingSnapshotWriteException('snapshot.unknown_key');
    }
  }

  static Map<String, Object?> _requiredObject(
    Map<String, Object?> object,
    String key,
  ) => _object(object[key]);

  static Map<String, Object?> _object(Object? value) {
    if (value is! Map<String, Object?>) _invalidStructure();
    return value;
  }

  static List<Object?> _requiredList(Map<String, Object?> object, String key) {
    final value = object[key];
    if (value is! List<Object?>) _invalidStructure();
    return value;
  }

  static String _requiredString(Map<String, Object?> object, String key) {
    final value = object[key];
    if (value is! String || value.trim().isEmpty || value != value.trim()) {
      _invalidStructure();
    }
    return value;
  }

  static int _requiredInt(Map<String, Object?> object, String key) {
    final value = object[key];
    if (value is! int) _invalidStructure();
    return value;
  }

  static Never _invalidStructure() =>
      throw const TrainingSnapshotWriteException('snapshot.invalid_structure');
}

String _sha256(List<int> input) {
  final bytes = List<int>.of(input);
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
      final first =
          _rotateRight(words[index - 15], 7) ^
          _rotateRight(words[index - 15], 18) ^
          (words[index - 15] >>> 3);
      final second =
          _rotateRight(words[index - 2], 17) ^
          _rotateRight(words[index - 2], 19) ^
          (words[index - 2] >>> 10);
      words[index] =
          (words[index - 16] + first + words[index - 7] + second) & 0xffffffff;
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
      final temporary1 =
          (h + sum1 + choice + _sha256Constants[index] + words[index]) &
          0xffffffff;
      final sum0 =
          _rotateRight(a, 2) ^ _rotateRight(a, 13) ^ _rotateRight(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final temporary2 = (sum0 + majority) & 0xffffffff;
      h = g;
      g = f;
      f = e;
      e = (d + temporary1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temporary1 + temporary2) & 0xffffffff;
    }
    final compressed = [a, b, c, d, e, f, g, h];
    for (var index = 0; index < hash.length; index++) {
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
