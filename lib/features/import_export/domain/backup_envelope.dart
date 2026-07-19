import 'dart:convert';

class BackupEnvelope {
  const BackupEnvelope({
    required this.exportedAt,
    required this.appVersion,
    required this.payload,
  });

  static const format = 'hybrid-training-backup';
  static const schemaVersion = 4;

  final DateTime exportedAt;
  final String appVersion;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'format': format,
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'payload': payload,
  };

  String encode() => jsonEncode(toJson());
}
