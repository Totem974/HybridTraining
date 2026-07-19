import 'package:flutter/material.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';
import 'package:hybrid_training/features/core_validation/presentation/core_validation_controller.dart';

class CoreValidationShell extends StatefulWidget {
  const CoreValidationShell({
    required this.environment,
    required this.controller,
    super.key,
  });

  final AppEnvironment environment;
  final CoreValidationController controller;

  @override
  State<CoreValidationShell> createState() => _CoreValidationShellState();
}

class _CoreValidationShellState extends State<CoreValidationShell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.forLanguage(
      Localizations.localeOf(context).languageCode,
    );
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        if (controller.state == CoreValidationState.loading) {
          return const Scaffold(
            key: Key('core-validation-loading'),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (controller.state == CoreValidationState.error) {
          return Scaffold(
            key: const Key('core-validation-error'),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.genericError),
                  TextButton(
                    onPressed: controller.initialize,
                    child: Text(strings.retry),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          key: const Key('core-validation-shell'),
          appBar: AppBar(
            title: Text(strings.coreValidationTitle),
            bottom: widget.environment == AppEnvironment.dev
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(28),
                    child: Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.errorContainer,
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        strings.developmentValidationBanner,
                        key: const Key('dev-validation-banner'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : null,
          ),
          body: IndexedStack(
            index: index,
            children: [
              _EnginePanel(
                strings: strings,
                controller: controller,
                allowFixture: widget.environment == AppEnvironment.dev,
              ),
              _TrackingPanel(strings: strings, controller: controller),
              _ProfilePanel(strings: strings, controller: controller),
              _SettingsPanel(strings: strings, controller: controller),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: [
              NavigationDestination(
                key: const Key('destination-engine'),
                icon: const Icon(Icons.settings_suggest),
                label: strings.engine,
              ),
              NavigationDestination(
                key: const Key('destination-tracking'),
                icon: const Icon(Icons.query_stats),
                label: strings.tracking,
              ),
              NavigationDestination(
                key: const Key('destination-profile'),
                icon: const Icon(Icons.person_outline),
                label: strings.profile,
              ),
              NavigationDestination(
                key: const Key('destination-settings'),
                icon: const Icon(Icons.tune),
                label: strings.settings,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EnginePanel extends StatelessWidget {
  const _EnginePanel({
    required this.strings,
    required this.controller,
    required this.allowFixture,
  });
  final AppStrings strings;
  final CoreValidationController controller;
  final bool allowFixture;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('engine-panel'),
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Beginner Prep School',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(strings.onlyReviewedPreset),
      const SizedBox(height: 16),
      Text(
        '${strings.activePlans}: ${controller.snapshot.activePlans}',
        key: const Key('active-plan-count'),
      ),
      Text(
        '${strings.plannedSessions}: ${controller.snapshot.plannedSessions}',
        key: const Key('planned-session-count'),
      ),
      if (allowFixture && !controller.snapshot.hasProfile)
        FilledButton(
          key: const Key('create-dev-fixture'),
          onPressed: controller.createDevelopmentFixture,
          child: Text(strings.createDevelopmentFixture),
        ),
      if (!allowFixture && !controller.snapshot.hasProfile)
        Text(strings.noProductionDemo, key: const Key('prod-no-demo')),
    ],
  );
}

class _TrackingPanel extends StatelessWidget {
  const _TrackingPanel({required this.strings, required this.controller});
  final AppStrings strings;
  final CoreValidationController controller;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('tracking-panel'),
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        '${strings.completedSessions}: ${controller.snapshot.completedSessions}',
      ),
      Text(
        '${strings.successfulSetCount}: ${controller.snapshot.successfulSets}',
      ),
      Text('${strings.failedSetCount}: ${controller.snapshot.failedSets}'),
      Text('${strings.skippedSetCount}: ${controller.snapshot.skippedSets}'),
      Text(
        controller.snapshot.actualTonnage == null
            ? strings.actualTonnageUnavailable
            : '${strings.actualTonnage}: ${controller.snapshot.actualTonnage}',
        key: const Key('actual-tonnage'),
      ),
    ],
  );
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.strings, required this.controller});
  final AppStrings strings;
  final CoreValidationController controller;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('profile-panel'),
    padding: const EdgeInsets.all(16),
    children: [
      Text(controller.snapshot.profileName ?? strings.noLocalProfile),
      if (controller.snapshot.unit != null)
        Text('${strings.unit}: ${controller.snapshot.unit}'),
    ],
  );
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.strings, required this.controller});
  final AppStrings strings;
  final CoreValidationController controller;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('settings-panel'),
    padding: const EdgeInsets.all(16),
    children: [
      FilledButton.tonal(
        key: const Key('export-backup'),
        onPressed: controller.exportBackup,
        child: Text(strings.exportData),
      ),
      if (controller.exportedBackup != null)
        Text(strings.exportReady, key: const Key('export-ready')),
      FilledButton.tonal(
        key: const Key('delete-all-data'),
        onPressed: () => _confirmDelete(context),
        child: Text(strings.deleteData),
      ),
    ],
  );

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteData),
        content: Text(strings.deleteDataWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteAllData();
  }
}
