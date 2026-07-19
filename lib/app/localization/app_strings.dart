class AppStrings {
  const AppStrings() : languageCode = 'fr';
  const AppStrings.english() : languageCode = 'en';

  factory AppStrings.forLanguage(String languageCode) =>
      languageCode == 'fr' ? const AppStrings() : const AppStrings.english();

  final String languageCode;
  bool get _fr => languageCode == 'fr';

  String get coreValidationTitle =>
      _fr ? 'Validation du moteur' : 'Engine validation';
  String get developmentValidationBanner => _fr
      ? 'OUTIL DEV — DONNÉES FICTIVES DE VALIDATION'
      : 'DEV TOOL — FICTIONAL VALIDATION DATA';
  String get engine => _fr ? 'Moteur' : 'Engine';
  String get tracking => _fr ? 'Suivi' : 'Tracking';
  String get profile => _fr ? 'Profil' : 'Profile';
  String get settings => _fr ? 'Réglages' : 'Settings';
  String get onlyReviewedPreset => _fr
      ? 'Seul le preset entièrement revu est activable.'
      : 'Only the fully reviewed preset is executable.';
  String get activePlans => _fr ? 'Plans actifs' : 'Active plans';
  String get plannedSessions => _fr ? 'Séances planifiées' : 'Planned workouts';
  String get firstWorkout => _fr ? 'Première séance' : 'First workout';
  String get noWorkout =>
      _fr ? 'Aucune séance disponible' : 'No workout available';
  String get startWorkout => _fr ? 'Démarrer la séance' : 'Start workout';
  String get workoutState => _fr ? 'État' : 'State';
  String get currentSet => _fr ? 'Série' : 'Set';
  String get prescribed => _fr ? 'Prescrit' : 'Prescribed';
  String get actualRepetitions =>
      _fr ? 'Répétitions réelles' : 'Actual repetitions';
  String get actualLoad => _fr ? 'Charge réelle' : 'Actual load';
  String get notes => _fr ? 'Notes' : 'Notes';
  String get success => _fr ? 'Réussite' : 'Success';
  String get failure => _fr ? 'Échec' : 'Failure';
  String get skipSet => _fr ? 'Sauter la série' : 'Skip set';
  String get pause => _fr ? 'Pause' : 'Pause';
  String get resume => _fr ? 'Reprendre' : 'Resume';
  String get undoLast =>
      _fr ? 'Annuler la dernière validation' : 'Undo last result';
  String get restSeconds => _fr ? 'Repos (secondes)' : 'Rest (seconds)';
  String get startRest => _fr ? 'Lancer le repos' : 'Start rest';
  String get endRest => _fr ? 'Terminer le repos' : 'End rest';
  String get completeWorkout => _fr ? 'Terminer la séance' : 'Complete workout';
  String get switchPreview =>
      _fr ? 'Simuler un nouveau plan' : 'Preview a new plan';
  String get nextPlanStart =>
      _fr ? 'Date de départ (AAAA-MM-JJ)' : 'Start date (YYYY-MM-DD)';
  String get switchPreviewReady => _fr
      ? 'Aperçu prêt, aucune écriture effectuée'
      : 'Preview ready, no data written';
  String get completedSessions =>
      _fr ? 'Séances terminées' : 'Completed workouts';
  String get successfulSetCount => _fr ? 'Séries réussies' : 'Successful sets';
  String get failedSetCount => _fr ? 'Séries échouées' : 'Failed sets';
  String get skippedSetCount => _fr ? 'Séries sautées' : 'Skipped sets';
  String get actualTonnage => _fr ? 'Tonnage réel' : 'Actual tonnage';
  String get actualTonnageUnavailable => _fr
      ? 'Tonnage réel indisponible : aucune charge réalisée.'
      : 'Actual tonnage unavailable: no performed load recorded.';
  String get createDevelopmentFixture => _fr
      ? 'Créer le profil fictif DEV et générer le plan'
      : 'Create DEV fixture profile and generate plan';
  String get noProductionDemo => _fr
      ? 'Aucune donnée de démonstration n’est créée en production.'
      : 'No demo data is created in production.';
  String get noLocalProfile => _fr ? 'Aucun profil local' : 'No local profile';
  String get unit => _fr ? 'Unité' : 'Unit';
  String get importData => _fr ? 'Importer une sauvegarde' : 'Import backup';
  String get backupJson =>
      _fr ? 'Contenu JSON de la sauvegarde' : 'Backup JSON';
  String get simulateImport => _fr ? 'Simuler l’import' : 'Simulate import';
  String get applyImport => _fr ? 'Appliquer l’import' : 'Apply import';
  String get importSimulationReady => _fr
      ? 'Simulation valide. Aucune donnée n’a encore été modifiée.'
      : 'Simulation valid. No data has been changed yet.';
  String get importApplied =>
      _fr ? 'Import appliqué atomiquement.' : 'Import applied atomically.';
  String get importSimulationRejected => _fr
      ? 'Simulation refusée. Les données locales sont inchangées.'
      : 'Simulation rejected. Local data is unchanged.';
  String get importIssueCount => _fr ? 'Problèmes signalés' : 'Reported issues';
  String get exportData => _fr ? 'Exporter les données' : 'Export data';
  String get exportReady => _fr ? 'Sauvegarde prête' : 'Backup ready';
  String get deleteData => _fr ? 'Effacer les données' : 'Delete data';
  String get deleteDataWarning => _fr
      ? 'Cette action efface le profil, les plans, les séances et les résultats locaux.'
      : 'This deletes the local profile, plans, workouts, and results.';
  String get cancel => _fr ? 'Annuler' : 'Cancel';
  String get delete => _fr ? 'Effacer' : 'Delete';
  String get retry => _fr ? 'Réessayer' : 'Retry';
  String get genericError =>
      _fr ? 'Une erreur locale est survenue.' : 'A local error occurred.';
  String get rulesReviewed => _fr ? 'Règles vérifiées' : 'Rules reviewed';
  String get compatibilityPresetNotice => _fr
      ? 'Preset de compatibilité disponible pendant la construction du moteur Forever.'
      : 'Compatibility preset available while the Forever engine is being built.';

  String programLabel(String key) => switch (key) {
    'program.forever_original_fsl' =>
      '5/3/1 Forever — Original + First Set Last',
    'program.beginner_prep_school' => 'Beginner Prep School',
    _ => key,
  };

  String lift(String id) => switch ((languageCode, id)) {
    (_, 'squat') => 'Squat',
    ('fr', 'benchPress') => 'Développé couché',
    ('fr', 'deadlift') => 'Soulevé de terre',
    ('fr', 'overheadPress') => 'Développé militaire',
    (_, 'benchPress') => 'Bench press',
    (_, 'deadlift') => 'Deadlift',
    (_, 'overheadPress') => 'Overhead press',
    _ => id,
  };
}
