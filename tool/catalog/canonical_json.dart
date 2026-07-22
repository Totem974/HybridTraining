import 'dart:convert';

/// Encodes JSON with recursively sorted object keys and no insignificant space.
String canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

String logicalJsonHash(Object? value) {
  final bytes = utf8.encode(canonicalJson(value));
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  for (final byte in bytes) {
    hash ^= BigInt.from(byte);
    hash = (hash * prime) & mask;
  }
  return 'fnv1a64-${hash.toRadixString(16).padLeft(16, '0')}';
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) return value.map(_canonicalize).toList(growable: false);
  return value;
}
