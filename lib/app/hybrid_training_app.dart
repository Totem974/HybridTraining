import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/core_validation/application/core_validation_repository.dart';
import 'package:hybrid_training/features/core_validation/data/sqlite_core_validation_repository.dart';
import 'package:hybrid_training/features/core_validation/presentation/core_validation_controller.dart';
import 'package:hybrid_training/features/core_validation/presentation/core_validation_shell.dart';
import 'package:hybrid_training/features/poc_531/presentation/poc_531_routes.dart';
import 'package:hybrid_training/features/poc_531/presentation/poc_531_landing_page.dart';

class HybridTrainingApp extends StatefulWidget {
  const HybridTrainingApp({
    required this.environment,
    this.repository,
    this.pocOnlyMode = kIsWeb,
    super.key,
  });

  final AppEnvironment environment;
  final CoreValidationRepository? repository;
  final bool pocOnlyMode;

  @override
  State<HybridTrainingApp> createState() => _HybridTrainingAppState();
}

class _HybridTrainingAppState extends State<HybridTrainingApp> {
  CoreValidationController? controller;

  @override
  void initState() {
    super.initState();
    if (!widget.pocOnlyMode) {
      controller = CoreValidationController(
        widget.repository ??
            SqliteCoreValidationRepository(localDatabase: LocalDatabase()),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: widget.environment.detailedLogging,
    title: widget.environment.displayName,
    supportedLocales: const [Locale('fr'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    onGenerateRoute: buildPoc531Route,
    home: widget.pocOnlyMode
        ? const Poc531LandingPage()
        : CoreValidationShell(
            environment: widget.environment,
            controller: controller!,
          ),
  );
}
