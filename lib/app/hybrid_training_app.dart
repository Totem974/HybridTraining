import 'package:flutter/material.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_training_store.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/active_program/presentation/foundation_controller.dart';
import 'package:hybrid_training/features/active_program/presentation/training_home_screen.dart';
import 'package:hybrid_training/features/onboarding/presentation/profile_setup_screen.dart';

class HybridTrainingApp extends StatefulWidget {
  const HybridTrainingApp({required this.environment, this.store, super.key});

  final AppEnvironment environment;
  final TrainingStore? store;

  @override
  State<HybridTrainingApp> createState() => _HybridTrainingAppState();
}

class _HybridTrainingAppState extends State<HybridTrainingApp> {
  late final FoundationController controller;

  @override
  void initState() {
    super.initState();
    controller = FoundationController(
      widget.store ?? SqliteTrainingStore(localDatabase: LocalDatabase()),
    )..initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: widget.environment.detailedLogging,
      title: widget.environment.displayName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF42566F)),
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => switch (controller.state) {
          FoundationState.loading => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          FoundationState.onboarding => ProfileSetupScreen(
            onSubmit: controller.createProfile,
          ),
          FoundationState.ready => TrainingHomeScreen(
            snapshot: controller.snapshot!,
            onCompleteSet: controller.completeSet,
            onFinishSession: controller.finishSession,
          ),
          FoundationState.error => Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(const AppStrings().genericError),
                  TextButton(
                    onPressed: controller.initialize,
                    child: Text(const AppStrings().retry),
                  ),
                ],
              ),
            ),
          ),
        },
      ),
    );
  }
}
