import 'package:flutter/material.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';
import 'package:hybrid_training/features/core_validation/presentation/core_validation_controller.dart';
import 'package:hybrid_training/features/workout_runtime/domain/workout_execution.dart';

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

class _EnginePanel extends StatefulWidget {
  const _EnginePanel({
    required this.strings,
    required this.controller,
    required this.allowFixture,
  });
  final AppStrings strings;
  final CoreValidationController controller;
  final bool allowFixture;

  @override
  State<_EnginePanel> createState() => _EnginePanelState();
}

class _EnginePanelState extends State<_EnginePanel> {
  final repetitions = TextEditingController();
  final load = TextEditingController();
  final rpe = TextEditingController();
  final notes = TextEditingController();
  final restSeconds = TextEditingController(text: '60');
  final nextPlanStart = TextEditingController();

  AppStrings get strings => widget.strings;
  CoreValidationController get controller => widget.controller;
  bool get allowFixture => widget.allowFixture;

  @override
  void dispose() {
    repetitions.dispose();
    load.dispose();
    rpe.dispose();
    notes.dispose();
    restSeconds.dispose();
    nextPlanStart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('engine-panel'),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
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
      if (controller.snapshot.hasProfile) ...[
        TextField(
          key: const Key('switch-start-date'),
          controller: nextPlanStart,
          decoration: InputDecoration(labelText: strings.nextPlanStart),
          onChanged: (_) => setState(() {}),
        ),
        FilledButton.tonal(
          key: const Key('preview-program-switch'),
          onPressed: DateTime.tryParse(nextPlanStart.text) == null
              ? null
              : () => controller.previewProgramSwitch(
                  DateTime.parse(nextPlanStart.text),
                ),
          child: Text(strings.switchPreview),
        ),
        if (controller.programSwitchPreview != null)
          Text(
            '${strings.switchPreviewReady}: '
            '${controller.programSwitchPreview!.currentPlanId} → '
            '${controller.programSwitchPreview!.nextPlanId}',
            key: const Key('program-switch-preview-ready'),
          ),
      ],
      if (allowFixture && !controller.snapshot.hasProfile)
        FilledButton(
          key: const Key('create-dev-fixture'),
          onPressed: controller.createDevelopmentFixture,
          child: Text(strings.createDevelopmentFixture),
        ),
      if (!allowFixture && !controller.snapshot.hasProfile)
        Text(strings.noProductionDemo, key: const Key('prod-no-demo')),
      if (controller.workout == null)
        Text(strings.noWorkout, key: const Key('no-workout'))
      else
        ..._workoutControls(context),
    ],
  );

  List<Widget> _workoutControls(BuildContext context) {
    final workout = controller.workout!;
    final actualReps = int.tryParse(repetitions.text);
    final actualLoad = double.tryParse(load.text.replaceAll(',', '.'));
    final actualRpe = rpe.text.trim().isEmpty
        ? null
        : double.tryParse(rpe.text.replaceAll(',', '.'));
    final validResult =
        workout.canRecord &&
        actualReps != null &&
        actualReps >= 0 &&
        actualLoad != null &&
        actualLoad >= 0 &&
        (actualRpe == null || (actualRpe >= 1 && actualRpe <= 10));
    final seconds = int.tryParse(restSeconds.text);
    return [
      const SizedBox(height: 24),
      Text(
        strings.firstWorkout,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Text(
        '${strings.workoutState}: ${workout.state.name}',
        key: const Key('workout-state'),
      ),
      Text(
        '${strings.currentSet}: ${workout.currentSetNumber}/${workout.totalSets}',
        key: const Key('workout-set-progress'),
      ),
      Text(
        '${strings.prescribed}: ${workout.prescribedRepetitions} × ${workout.prescribedLoad}',
      ),
      if (workout.canStart)
        FilledButton(
          key: const Key('start-workout'),
          onPressed: controller.startWorkout,
          child: Text(strings.startWorkout),
        ),
      if (workout.canRecord) ...[
        TextField(
          key: const Key('actual-repetitions'),
          controller: repetitions,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: strings.actualRepetitions),
          onChanged: (_) => setState(() {}),
        ),
        TextField(
          key: const Key('actual-load'),
          controller: load,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: strings.actualLoad),
          onChanged: (_) => setState(() {}),
        ),
        TextField(
          key: const Key('actual-rpe'),
          controller: rpe,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'RPE (1–10)'),
          onChanged: (_) => setState(() {}),
        ),
        TextField(
          key: const Key('set-notes'),
          controller: notes,
          decoration: InputDecoration(labelText: strings.notes),
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              key: const Key('record-success'),
              onPressed: validResult
                  ? () => _record(
                      SetOutcomeStatus.success,
                      actualReps,
                      actualLoad,
                      actualRpe,
                    )
                  : null,
              child: Text(strings.success),
            ),
            FilledButton.tonal(
              key: const Key('record-failure'),
              onPressed: validResult
                  ? () => _record(
                      SetOutcomeStatus.failure,
                      actualReps,
                      actualLoad,
                      actualRpe,
                    )
                  : null,
              child: Text(strings.failure),
            ),
            TextButton(
              key: const Key('record-skip'),
              onPressed: () => controller.recordSet(
                status: SetOutcomeStatus.skipped,
                notes: notes.text,
              ),
              child: Text(strings.skipSet),
            ),
          ],
        ),
      ],
      if ({
        WorkoutExecutionState.activeSet,
        WorkoutExecutionState.resting,
        WorkoutExecutionState.paused,
      }.contains(workout.state))
        FilledButton.tonal(
          key: const Key('pause-resume-workout'),
          onPressed: controller.pauseOrResumeWorkout,
          child: Text(
            workout.state == WorkoutExecutionState.paused
                ? strings.resume
                : strings.pause,
          ),
        ),
      if (workout.completedSets > 0 && !workout.isClosed)
        TextButton(
          key: const Key('undo-last-set'),
          onPressed: controller.undoLastSet,
          child: Text(strings.undoLast),
        ),
      if (workout.state == WorkoutExecutionState.activeSet ||
          workout.state == WorkoutExecutionState.resting) ...[
        TextField(
          key: const Key('rest-seconds'),
          controller: restSeconds,
          keyboardType: TextInputType.number,
          enabled: workout.state != WorkoutExecutionState.resting,
          decoration: InputDecoration(labelText: strings.restSeconds),
          onChanged: (_) => setState(() {}),
        ),
        TextButton(
          key: const Key('toggle-rest'),
          onPressed:
              workout.state == WorkoutExecutionState.resting ||
                  (seconds != null && seconds > 0)
              ? () => controller.toggleRest(Duration(seconds: seconds ?? 1))
              : null,
          child: Text(
            workout.state == WorkoutExecutionState.resting
                ? strings.endRest
                : strings.startRest,
          ),
        ),
      ],
      if (workout.canComplete)
        FilledButton(
          key: const Key('complete-workout'),
          onPressed: controller.completeWorkout,
          child: Text(strings.completeWorkout),
        ),
    ];
  }

  Future<void> _record(
    SetOutcomeStatus status,
    int actualRepetitions,
    double actualLoad,
    double? actualRpe,
  ) => controller.recordSet(
    status: status,
    actualRepetitions: actualRepetitions,
    actualLoad: actualLoad,
    rpe: actualRpe,
    notes: notes.text,
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

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({required this.strings, required this.controller});
  final AppStrings strings;
  final CoreValidationController controller;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  final importController = TextEditingController();

  AppStrings get strings => widget.strings;
  CoreValidationController get controller => widget.controller;

  @override
  void dispose() {
    importController.dispose();
    super.dispose();
  }

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
      const SizedBox(height: 24),
      Text(strings.importData, style: Theme.of(context).textTheme.titleMedium),
      TextField(
        key: const Key('import-source'),
        controller: importController,
        minLines: 2,
        maxLines: 5,
        decoration: InputDecoration(labelText: strings.backupJson),
        onChanged: (_) {
          controller.clearImportSimulation();
          setState(() {});
        },
      ),
      FilledButton.tonal(
        key: const Key('simulate-import'),
        onPressed: importController.text.trim().isEmpty
            ? null
            : () => controller.simulateImport(importController.text),
        child: Text(strings.simulateImport),
      ),
      if (controller.importReport != null) ...[
        Text(
          '${strings.importIssueCount}: ${controller.importReport!.issues.length}',
          key: const Key('import-issue-count'),
        ),
        Text(
          controller.importReport!.applied
              ? strings.importApplied
              : controller.canApplyImport
              ? strings.importSimulationReady
              : strings.importSimulationRejected,
          key: const Key('import-report-status'),
        ),
        for (final issue in controller.importReport!.issues)
          Text(
            '${issue.severity.name.toUpperCase()} ${issue.path}: ${issue.message}',
            key: ValueKey('import-issue-${issue.path}-${issue.message}'),
          ),
      ],
      FilledButton(
        key: const Key('apply-import'),
        onPressed: controller.canApplyImport
            ? controller.applySimulatedImport
            : null,
        child: Text(strings.applyImport),
      ),
      const SizedBox(height: 24),
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
            key: const Key('confirm-delete-data'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteAllData();
  }
}
