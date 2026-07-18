import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/bootstrap/bootstrap.dart';
import 'package:hybrid_training/features/onboarding/domain/setup_entry_policy.dart';

const setupEntryMode = SetupEntryMode.legacyCompatibility;

void main() => bootstrap(AppEnvironment.dev, setupEntryMode: setupEntryMode);
