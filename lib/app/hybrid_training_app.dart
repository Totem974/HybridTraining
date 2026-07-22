import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/bootstrap/cycle_web_bootstrap.dart';
import 'package:hybrid_training/app/bootstrap/forever_web_bootstrap.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/core_validation/application/core_validation_repository.dart';
import 'package:hybrid_training/features/core_validation/data/sqlite_core_validation_repository.dart';
import 'package:hybrid_training/features/core_validation/presentation/core_validation_controller.dart';
import 'package:hybrid_training/features/core_validation/presentation/core_validation_shell.dart';
import 'package:hybrid_training/features/poc_531/presentation/poc_531_routes.dart';
import 'package:hybrid_training/features/cycle_web/application/cycle_web_contract.dart';
import 'package:hybrid_training/features/cycle_web/presentation/cycle_web_page.dart';
import 'package:hybrid_training/features/cycle_web/presentation/cycle_web_route.dart';
import 'package:hybrid_training/features/forever/presentation/forever_web_contract.dart';
import 'package:hybrid_training/features/forever/presentation/forever_web_route.dart';

class HybridTrainingApp extends StatefulWidget {
  const HybridTrainingApp({
    required this.environment,
    this.repository,
    this.cycleApplication,
    this.foreverApplication,
    this.pocOnlyMode = kIsWeb,
    super.key,
  });

  final AppEnvironment environment;
  final CoreValidationRepository? repository;
  final CycleWebApplication? cycleApplication;
  final ForeverWebApplication? foreverApplication;
  final bool pocOnlyMode;

  @override
  State<HybridTrainingApp> createState() => _HybridTrainingAppState();
}

class _HybridTrainingAppState extends State<HybridTrainingApp> {
  CoreValidationController? controller;
  late final Future<_WebApplications>? webApplicationsFuture;

  @override
  void initState() {
    super.initState();
    if (!widget.pocOnlyMode) {
      controller = CoreValidationController(
        widget.repository ??
            SqliteCoreValidationRepository(localDatabase: LocalDatabase()),
      );
      webApplicationsFuture = null;
    } else {
      webApplicationsFuture = _createWebApplications();
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (webApplicationsFuture case final future?) {
      return FutureBuilder<_WebApplications>(
        future: future,
        builder: (context, snapshot) => _materialApp(
          applications: snapshot.data,
          startupError: snapshot.error,
        ),
      );
    }
    return _materialApp();
  }

  Widget _materialApp({_WebApplications? applications, Object? startupError}) =>
      MaterialApp(
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
            (applications == null
                ? null
                : (applications.forever == null
                          ? null
                          : ForeverWebRoute.build(
                              settings: settings,
                              application: applications.forever!,
                            )) ??
                      CycleWebRoute.build(
                        settings: settings,
                        application: applications.cycle,
                        foreverRoute: ForeverWebRoute.path,
                      )) ??
            buildPoc531Route(settings),
        home: widget.pocOnlyMode
            ? applications == null
                  ? Scaffold(
                      body: Center(
                        child: startupError == null
                            ? const CircularProgressIndicator()
                            : Text(
                                'Unable to open local databases: $startupError',
                              ),
                      ),
                    )
                  : CycleWebPage(
                      application: applications.cycle,
                      foreverRoute: ForeverWebRoute.path,
                    )
            : CoreValidationShell(
                environment: widget.environment,
                controller: controller!,
              ),
      );

  Future<_WebApplications> _createWebApplications() async {
    final cycle = widget.cycleApplication ?? await createCycleWebApplication();
    final forever =
        widget.foreverApplication ??
        (widget.cycleApplication == null
            ? await createForeverWebApplication()
            : null);
    return _WebApplications(cycle: cycle, forever: forever);
  }
}

final class _WebApplications {
  const _WebApplications({required this.cycle, required this.forever});

  final CycleWebApplication cycle;
  final ForeverWebApplication? forever;
}
