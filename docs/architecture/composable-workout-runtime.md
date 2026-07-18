# Moteur de séance composable

Le moteur d’exécution est isolé sous `lib/features/workout_runtime/`. Son domaine
est en Dart pur : il décrit les rôles de bloc, les cibles, les trois niveaux
d’état et le résumé, sans dépendre de Flutter ni de SQLite.

## Modèle

Une séance contient uniquement les blocs ordonnés fournis par son blueprint.
Plusieurs blocs `mainWork` peuvent donc porter des mouvements différents. Une
activité utilise exactement une cible : séries/répétitions/charge, répétitions
totales, durée, distance, tours ou validation simple.

Les états persistés sont :

- séance : `planned`, `started`, `completed`, `abandoned`, `skipped` ;
- bloc : `pending`, `active`, `completed`, `skipped` ;
- prescription : `pending`, `success`, `failure`, `skipped`.

## Persistance et reprise

La migration SQLite v3 est additive. Les tables v1 restent l’historique
immuable et les prescriptions v2 restent le plan. Les tables
`workout_runtime_*` et `workout_activities` portent uniquement l’état mutable.
Chaque démarrage, navigation, résultat, correction, annulation, repos, note,
abandon ou saut est écrit immédiatement. Les opérations qui touchent plusieurs
lignes sont transactionnelles ; après un arrêt forcé, `load` restitue la
position active et tous les résultats déjà confirmés.

Le repos est stocké par bloc sous forme d’échéance UTC. Une échéance passée est
donc reconnue comme expirée au rechargement sans notification système.

## Présentation

`ComposableWorkoutScreen` constitue la première extraction de l’ancien écran
actif. Il sépare visuellement les blocs, ne fabrique aucun rôle absent et reste
défilable à 390 × 844. Les libellés devront rejoindre le catalogue bilingue lors
du raccordement définitif au parcours principal.
