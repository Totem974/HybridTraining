# Carte de navigation de l’application d’origine

La carte représente uniquement les destinations observées. Les surfaces Android
système sont séparées des écrans de l’application.

```mermaid
flowchart TD
    Launch["Lancement Five/Three/One"]
    Intro["Introduction Cinq/Trois/Un"]
    Exercises["Exercices et rep max"]
    Plans["Catalogue des plans"]
    Date["Date de début"]
    Frequency["Fréquence 3 ou 4 jours"]
    Days["Jours et affectation des mouvements"]
    Ready["Tout est prêt !"]
    Home["Accueil Cinq/Trois/Un"]

    Launch -->|"aucun cycle"| Intro
    Launch -->|"cycle existant"| Home
    Intro -->|"Commencer / Sauter pour l'instant"| Exercises
    Exercises --> Plans
    Plans --> Date
    Date --> Frequency
    Frequency --> Days
    Days --> Ready
    Ready -->|"Allons-y"| Home

    DatePicker["Android : sélecteur de date"]
    Date --> DatePicker
    DatePicker --> Date

    Schedule["Détail hebdomadaire"]
    Calendar["Calendrier du cycle"]
    Workout["Détail de séance"]
    WorkoutMenu["Feuille : actions séance"]
    FutureDialog["Changer à aujourd'hui ?"]
    Active["Séance en cours"]
    Notes["Feuille Notes"]
    Failure["Dialogue reps après échec"]
    MaxReps["Dialogue reps série max"]
    Joker["Panneau Séries Joker"]
    FslReps["Dialogue reps AMRAP FSL"]
    Rest["Repos"]
    Quit["Sauter les séries restantes ?"]
    Completed["Détail terminé"]
    EditResults["Modifier les résultats"]

    Home -->|"Plus de détails"| Schedule
    Schedule --> Calendar
    Schedule --> Workout
    Home -->|"carte séance"| Workout
    Workout --> WorkoutMenu
    WorkoutMenu --> DatePicker
    WorkoutMenu -->|"Skip"| Completed
    Workout -->|"Commencer séance future"| FutureDialog
    FutureDialog -->|"Commencer"| Active
    Active --> Notes
    Active -->|"Échec"| Failure
    Active -->|"Succès série 5+"| MaxReps
    MaxReps --> Joker
    Joker -->|"Pass"| Rest
    Rest -->|"Série suivante"| Active
    Active -->|"Succès AMRAP"| FslReps
    FslReps --> Rest
    Active --> Quit
    Quit -->|"Annuler"| Active
    Quit -->|"Sauter les séries"| Completed
    Completed --> WorkoutMenu
    WorkoutMenu --> EditResults

    Settings["Réglages"]
    RestPicker["Sélecteur de durée"]
    Plate["Nouvel / éditer ensemble"]
    PlateOrder["Réorganiser ensembles"]
    Bar["Nouvelle barre"]
    ExportShare["Android : partage de fiveThreeOne.json"]
    ImportPicker["Android : sélecteur JSON"]
    DeleteDialog["Supprimer tous vos cycles ?"]
    Purchase["Restaurer les achats"]

    Home -->|"engrenage"| Settings
    Settings --> RestPicker
    Settings --> Plate
    Settings --> PlateOrder
    Settings --> Bar
    Settings -->|"Exporter"| ExportShare
    Settings -->|"Importer"| ImportPicker
    Settings -->|"Supprimer"| DeleteDialog
    DeleteDialog -->|"Annuler"| Settings
    Settings --> Purchase

    CycleEditor["Modifier Cycle"]
    PlanMenu["Menu des treize plans"]
    Stats["Progrès & Statistiques"]

    Home -->|"Modifier"| CycleEditor
    WorkoutMenu -->|"Modifier le cycle"| CycleEditor
    CycleEditor --> PlanMenu
    Home -->|"Plus de détails stats"| Stats
```

## Règles de retour observées

| Depuis | Retour interne / Android | Destination ou effet |
|---|---|---|
| Introduction | Retour Android | Lanceur Android |
| Onboarding incomplet | Retour Android puis relance | Introduction, valeurs perdues |
| Sélecteur de date | Retour ou toucher hors zone | Écran appelant, valeur inchangée |
| Détail hebdomadaire | Flèche interne | Accueil |
| Calendrier du cycle | Retour | Détail hebdomadaire |
| Séance active | Flèche interne / relance | Accueil avec séance EN COURS, reprise possible |
| Feuille Notes | Retour | Séance active, note conservée |
| Dialogue de fin anticipée | Annuler | Séance active intacte |
| Éditeur de résultats | Retour | Détail terminé sans changement |
| Réglages | Croix / retour | Accueil |
| Sélecteur d’import | Retour Android | Réglages, données conservées |
| Sharesheet export | Retour Android | Réglages, aucun export choisi |
| Statistiques détaillées | Retour Android lors du test | Sortie de l’application |

## Destinations non reliées car non trouvées

Profil, compte, bibliothèque autonome, fiche de programme, historique autonome,
records, notifications détaillées, RPE, aide, licences, refaire l’introduction,
arrêter le cycle et nouveau cycle manuel sont
`NOT_FOUND_AFTER_SYSTEMATIC_SEARCH`.
