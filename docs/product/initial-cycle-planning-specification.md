# Spécification du planning du premier cycle

Le planning utilise les jours ISO 1 (lundi) à 7 (dimanche). La date de début est
une borne inclusive : la première séance utilise ce jour s’il est sélectionné,
sinon le prochain jour choisi.

Une semaine de programmation contient quatre séances et ne correspond pas
nécessairement à une semaine calendaire. En trois jours, douze séances forment
trois semaines de programmation et occupent normalement quatre semaines
calendaires.

## Modes

`fixedWeekdayAssignment`, à quatre jours, affecte chaque mouvement à un jour
stable pendant trois semaines. `rotatingAcrossSelectedDays`, à trois jours,
parcourt les jours choisis et répète l’ordre explicite des quatre mouvements.
Une seule séance est produite par date.

Le générateur parcourt les dates locales depuis la borne de début et produit
douze créneaux strictement chronologiques. Aucun offset fixe n’est utilisé.

## Persistance et compatibilité

`training_cycles.settings_json` conserve `scheduleVersion`, `scheduleMode`,
`selectedWeekdays`, `liftOrder`, `weekdayAssignments` et la fréquence. Le schéma
SQLite reste en version 1. Un ancien cycle conserve ses dates et séances ; son
résumé est dérivé sans régénération.
