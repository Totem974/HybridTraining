import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/bootstrap/cycle_web_bootstrap.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/core_validation/application/core_validation_repository.dart';
import 'package:hybrid_training/features/core_validation/data/sqlite_core_validation_repository.dart';
import 'package:hybrid_training/features/core_validation/presentation/core_validation_controller.dart';
import 'package:hybrid_training/features/core_validation/presentation/core_validation_shell.dart';
import 'package:hybrid_training/features/poc_531/presentation/poc_531_routes.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_contract.dart';
import 'package:hybrid_training/features/cycle_web/presentation/cycle_web_page.dart';
import 'package:hybrid_training/features/cycle_web/presentation/cycle_web_route.dart';

class HybridTrainingApp extends StatefulWidget {
  const HybridTrainingApp({
    required this.environment,
    this.repository,
    this.cycleApplication,
    this.pocOnlyMode = kIsWeb,
    super.key,
  });

  final AppEnvironment environment;
  final CoreValidationRepository? repository;
  final CycleWebApplication? cycleApplication;
  final bool pocOnlyMode;

  @override
  State<HybridTrainingApp> createState() => _HybridTrainingAppState();
}

class _HybridTrainingAppState extends State<HybridTrainingApp> {
  CoreValidationController? controller;
  late final Future<CycleWebApplication>? cycleApplicationFuture;

  @override
  void initState() {
    super.initState();
    if (!widget.pocOnlyMode) {
      controller = CoreValidationController(
        widget.repository ??
            SqliteCoreValidationRepository(localDatabase: LocalDatabase()),
      );
      cycleApplicationFuture = null;
    } else {
      cycleApplicationFuture = widget.cycleApplication == null
          ? createCycleWebApplication()
          : Future.value(widget.cycleApplication);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (cycleApplicationFuture case final future?) {
      return FutureBuilder<CycleWebApplication>(
        future: future,
        builder: (context, snapshot) => _materialApp(
          cycleApplication: snapshot.data,
          startupError: snapshot.error,
        ),
      );
    }
    return _materialApp();
  }

  Widget _materialApp({
    CycleWebApplication? cycleApplication,
    Object? startupError,
  }) => MaterialApp(
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
    onGenerateRoute: (settings) =>
        (cycleApplication == null
            ? null
            : CycleWebRoute.build(
                settings: settings,
                application: cycleApplication,
              )) ??
        buildPoc531Route(settings),
    home: widget.pocOnlyMode
        ? cycleApplication == null
              ? Scaffold(
                  body: Center(
                    child: startupError == null
                        ? const CircularProgressIndicator()
                        : Text('Unable to open Cycle databases: $startupError'),
                  ),
                )
              : CycleWebPage(application: cycleApplication)
        : CoreValidationShell(
            environment: widget.environment,
            controller: controller!,
          ),
  );
}
