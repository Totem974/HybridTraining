import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/features/onboarding/domain/setup_entry_policy.dart';

void main() {
  test('prod always keeps the legacy compatibility entry', () {
    for (final requestedMode in SetupEntryMode.values) {
      expect(
        SetupEntryPolicy.resolve(
          environment: AppEnvironment.prod,
          requestedMode: requestedMode,
        ),
        SetupEntryMode.legacyCompatibility,
      );
    }
  });

  test('dev enables only the deterministic development bootstrap', () {
    expect(
      SetupEntryPolicy.resolve(
        environment: AppEnvironment.dev,
        requestedMode: SetupEntryMode.developmentBootstrap,
      ),
      SetupEntryMode.developmentBootstrap,
    );
    expect(
      SetupEntryPolicy.resolve(
        environment: AppEnvironment.dev,
        requestedMode: SetupEntryMode.recommendationV2Disabled,
      ),
      SetupEntryMode.legacyCompatibility,
    );
  });
}
