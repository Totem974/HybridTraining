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
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF5821F),
          onPrimary: Color(0xFF1A0E00),
          secondary: Color(0xFF3ECB6A),
          onSecondary: Color(0xFF06210F),
          surface: Color(0xFF171716),
          onSurface: Color(0xFFF2F1EE),
          error: Color(0xFFE2503B),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0B0C),
        cardTheme: const CardThemeData(
          color: Color(0xFF171716),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0B0C),
          foregroundColor: Color(0xFFF2F1EE),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFFF5821F),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF0F0F0F),
          indicatorColor: Color(0x33F5821F),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3ECB6A),
            foregroundColor: const Color(0xFF06210F),
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF171716),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0x18FFFFFF)),
          ),
        ),
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
            onUpdateNotes: controller.updateSessionNotes,
            onStartSession: controller.startSession,
            onRecordSet: controller.recordSet,
            onSetRestUntil: controller.setRestUntil,
            onUpdateTrainingMaxes: controller.updateTrainingMaxes,
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
