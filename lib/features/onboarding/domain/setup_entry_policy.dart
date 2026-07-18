import 'package:hybrid_training/app/bootstrap/app_environment.dart';

enum SetupEntryMode {
  legacyCompatibility,
  developmentBootstrap,
  recommendationV2Disabled,
}

class SetupEntryPolicy {
  const SetupEntryPolicy._();

  static SetupEntryMode resolve({
    required AppEnvironment environment,
    required SetupEntryMode requestedMode,
  }) {
    if (requestedMode == SetupEntryMode.developmentBootstrap &&
        environment == AppEnvironment.dev) {
      return SetupEntryMode.developmentBootstrap;
    }
    return SetupEntryMode.legacyCompatibility;
  }
}
