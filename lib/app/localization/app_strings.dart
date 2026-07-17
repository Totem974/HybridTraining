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
