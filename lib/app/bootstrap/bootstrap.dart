import 'package:flutter/widgets.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/hybrid_training_app.dart';
import 'package:hybrid_training/features/onboarding/domain/setup_entry_policy.dart';

void bootstrap(
  AppEnvironment environment, {
  SetupEntryMode setupEntryMode = SetupEntryMode.legacyCompatibility,
}) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    HybridTrainingApp(environment: environment, setupEntryMode: setupEntryMode),
  );
}
