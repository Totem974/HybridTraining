import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/database_schema.dart';
import 'package:hybrid_training/features/import_export/domain/backup_envelope.dart';
import 'package:hybrid_training/features/poc_531/application/poc_531_configuration_codec.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/canonical_plan_generator.dart';

void main() {
  test('version namespaces keep their independent authority', () {
    expect(DatabaseSchema.version, 5, reason: 'SQLite schema version');
    expect(
      BackupEnvelope.schemaVersion,
      5,
      reason: 'native backup envelope schema version',
    );
    expect(
      canonicalTrainingPlanSchemaVersion,
      5,
      reason: 'Core training plan schema version',
    );
    expect(
      Poc531Configuration.schemaVersion,
      4,
      reason: 'POC 5/3/1 configuration schema version',
    );
  });
}
