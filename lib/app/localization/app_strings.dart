class AppStrings {
  const AppStrings() : languageCode = 'fr';
  const AppStrings.english() : languageCode = 'en';

  final String languageCode;
  bool get _fr => languageCode == 'fr';

  String get setupTitle =>
      _fr ? 'Créer votre profil local' : 'Create your local profile';
  String get displayName => _fr ? 'Prénom ou pseudonyme' : 'Name or nickname';
  String get unit => _fr ? 'Unité' : 'Unit';
  String get maxInstructions => _fr
      ? 'Saisissez votre 1RM pour les quatre mouvements.'
      : 'Enter your one-rep max for all four lifts.';
  String get selectedProgram =>
      '${_fr ? 'Programme' : 'Program'} : Original 5/3/1 + First Set Last';
  String get createCycle => _fr ? 'Créer mon cycle' : 'Create my cycle';
  String get workout => _fr ? 'Séance' : 'Workout';
  String get history => _fr ? 'Historique' : 'History';
  String get noSession =>
      _fr ? 'Aucune séance planifiée.' : 'No planned workout.';
  String get noHistory =>
      _fr ? 'Aucune séance terminée.' : 'No completed workout.';
  String get finishSession => _fr ? 'Terminer la séance' : 'Finish workout';
  String get done => _fr ? 'Fait' : 'Done';
  String get retry => _fr ? 'Réessayer' : 'Retry';
  String get genericError =>
      _fr ? 'Une erreur locale est survenue.' : 'A local error occurred.';
  List<String> get onboardingTitles => _fr
      ? ['Votre profil', 'Programme', 'Calendrier', 'Tout est prêt']
      : ['Your profile', 'Program', 'Schedule', 'Ready'];
  String get requiredField => _fr ? 'Champ obligatoire' : 'Required field';
  String get positiveValueRequired =>
      _fr ? 'Valeur positive obligatoire' : 'Positive value required';
  String get back => _fr ? 'Retour' : 'Back';
  String get continueLabel => _fr ? 'Continuer' : 'Continue';
  String get creating => _fr ? 'Création…' : 'Creating…';
  String get programPrompt =>
      _fr ? 'Choisissez votre point de départ' : 'Choose your starting point';
  String get foundationProgram => '5/3/1 + First Set Last';
  String get foundationProgramDescription => _fr
      ? 'Le programme validé pour ce premier POC.'
      : 'The program validated for this first POC.';
  String get pocProgramNotice => _fr
      ? 'Les autres variantes seront ajoutées progressivement.'
      : 'Other variants will be added progressively.';
  String get startPrompt =>
      _fr ? 'Quand voulez-vous commencer ?' : 'When do you want to start?';
  String get startDate => _fr ? 'Date de début' : 'Start date';
  String get frequencyPrompt =>
      _fr ? 'Combien de jours par semaine ?' : 'How many days per week?';
  String get threeDays => _fr ? '3 jours' : '3 days';
  String get fourDays => _fr ? '4 jours' : '4 days';
  String get readyMessage => _fr
      ? 'Votre premier cycle est prêt à être créé.'
      : 'Your first cycle is ready to be created.';
  String get frequency => _fr ? 'Jours par semaine' : 'Days per week';
  String get settings => _fr ? 'Réglages' : 'Settings';
  String get settingsComingSoon => _fr
      ? 'Les réglages arrivent dans le prochain lot.'
      : 'Settings are coming in the next batch.';
  String get hello => _fr ? 'Bonjour' : 'Hello';
  String get thisWeek => _fr ? 'Cette semaine' : 'This week';
  String get currentCycle => _fr ? 'Cycle en cours' : 'Current cycle';
  String get edit => _fr ? 'Modifier' : 'Edit';
  String get cycleDescription => _fr
      ? 'Cycle local de trois semaines · progression sauvegardée automatiquement.'
      : 'Local three-week cycle · progress saved automatically.';
  String get topSet => _fr ? 'Série max' : 'Top set';
  String get mainSets => _fr ? 'Séries principales' : 'Main sets';
  String get firstSetLast => 'First Set Last';
  String get startWorkout => _fr ? 'Commencer' : 'Start';
  String get activeWorkout => _fr ? 'Séance en cours' : 'Active workout';
  String get next => _fr ? 'Suivant' : 'Next';
  String get workoutComplete => _fr ? 'Séance terminée' : 'Workout complete';
  String get rest => _fr ? 'Repos' : 'Rest';
  String get skipRest => _fr ? 'Passer le repos' : 'Skip rest';
  String get sessionNotes => _fr ? 'Notes de séance' : 'Workout notes';
  String get setComplete => _fr ? 'Série terminée' : 'Set complete';
  String get setsCompleted => _fr ? 'séries terminées' : 'sets completed';
  String get amrapRepetitions =>
      _fr ? 'Répétitions réalisées' : 'Completed repetitions';
  String get setFailed => _fr ? 'Échec' : 'Failed';
  String get skipSet => _fr ? 'Passer' : 'Skip';
  String get successfulSets => _fr ? 'réussies' : 'successful';
  String get failedSets => _fr ? 'échouées' : 'failed';
  String get skippedSets => _fr ? 'passées' : 'skipped';
  String get perSide => _fr ? 'Par côté' : 'Per side';
  String get emptyBar => _fr ? 'barre seule' : 'empty bar';
  String get noExactPlateLoad => _fr
      ? 'Charge exacte indisponible avec les plaques par défaut.'
      : 'Exact load unavailable with the default plates.';
  String get notifications => _fr ? 'Notifications' : 'Notifications';
  String get statistics => _fr ? 'Statistiques' : 'Statistics';
  String get sessions => _fr ? 'séances' : 'workouts';
  String get cycleWeek => _fr ? 'semaine cycle' : 'cycle week';
  String get recordsComingFromWorkouts => _fr
      ? 'Les statistiques détaillées apparaîtront au fil des séances enregistrées.'
      : 'Detailed statistics will appear as workouts are recorded.';
  String get profile => _fr ? 'Profil' : 'Profile';
  String get editLoads => _fr ? 'Modifier mes charges' : 'Edit my loads';
  String get preferences => _fr ? 'PRÉFÉRENCES' : 'PREFERENCES';
  String get units => _fr ? 'Unités' : 'Units';
  String get program => _fr ? 'PROGRAMME' : 'PROGRAM';
  String get manageProgram => _fr ? 'Gérer mon programme' : 'Manage my program';
  String get editCycle => _fr ? 'Modifier le cycle' : 'Edit cycle';

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
