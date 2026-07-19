# Schéma logique Core v5

Le schéma v5 est une migration additive. Les tables v1 à v4 restent intactes
pour la lecture des sauvegardes historiques, la preuve de préservation et un
rollback sûr. Leur retrait éventuel relève d'une migration ultérieure.

## Métadonnées de plan conservées

- `training_plans` conserve l'édition source et la génération du ruleset ;
- `training_blocks` distingue type structurel, rôle, numéro de bloc et finalité
  typée du 7th Week Protocol ;
- cycles et séances conservent leurs numéros de programmation et la position de
  séance, indépendamment de la date calendaire.

Les colonnes ajoutées sont nullables afin que les lignes historiques restent
lisibles sans inventer de provenance lors d'une migration.

## Prescriptions et résultats génériques

`activity_prescriptions` couvre séries chargées, séries au poids du corps,
répétitions totales, durée, distance, rounds, completion et objectif qualitatif.
Chaque ligne conserve mouvement ou activité, position, type, règle, édition,
génération, référence source et calcul de charge lorsqu'il existe.

`activity_results` sépare le résultat réel de la prescription et conserve statut,
valeurs réelles structurées, RPE, notes et horodatages.

## Timeline et modifications versionnées

- `training_max_timeline` représente les décisions prévisualisées ou confirmées,
  leur motif, leur source et le point après lequel elles deviennent effectives ;
- `plan_amendments` conserve version, motif, état, snapshots avant/après et diff ;
- `plan_transitions_v5` conserve les transitions et leur provenance ;
- `planned_events_v5` conserve les événements planifiés ou survenus sans aplatir
  la semaine de programmation.

## Migrations validées

Les chemins v1 → v5, v2 → v5, v3 → v5 et v4 → v5 sont couverts. Les tests
vérifient la conservation d'une ligne historique, la création des tables v5, la
conversion du runtime v3 vers v4 avant ajout v5 et le rollback transactionnel en
cas d'interruption.

