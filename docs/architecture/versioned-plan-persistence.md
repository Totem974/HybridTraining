# Persistance des plans d’entraînement versionnés

## Décision

Le schéma v1 reste la représentation d’exécution des cycles historiques. Il ne
suffit pas pour les plans composables : il impose une séance à un mouvement,
confond prescription et résultat, et ne représente ni macrocycle, ni blocs, ni
transitions. Le schéma v2 ajoute donc un modèle relationnel requêtable. Aucune
table v1 n’est supprimée ou réécrite.

## Agrégat v2

`training_plans` référence l’identité et la version du blueprint ainsi qu’un
`program_definition_snapshots` immuable. Un plan contient des
`training_blocks` ordonnés (Prep, Leader, 7th Week, Anchor), des
`plan_training_cycles`, des `plan_training_sessions`, puis plusieurs
`session_blocks` par séance. Les `set_prescriptions` figent la charge, le
Training Max utilisé, l’arrondi et la provenance. Les `set_performances`
contiennent uniquement le résultat observé.

`plan_events` conserve les transitions, la proposition de progression des
Training Max et les valeurs confirmées. La provenance est stockée au niveau du
snapshot, du bloc de séance, de la prescription et de l’évènement, afin que le
contexte historique ne dépende jamais de la bibliothèque courante.

## Invariants transactionnels

- La génération et la validation du plan précèdent l’ouverture de la transaction.
- La création de tout l’agrégat est atomique.
- Un snapshot existant pour un couple blueprint/version doit être identique ; il
  n’est jamais mis à jour.
- Une transition termine exactement un bloc actif, active exactement un bloc
  planifié et écrit exactement un évènement dans la même transaction.
- Une progression de Training Max est proposée puis confirmée explicitement.
- Les contraintes d’unicité portent sur les positions dans chaque parent.
- Les écritures d’état vérifient le nombre de lignes affectées.

## Lecture compatible

Les parcours v1 continuent à lire `training_cycles`, `training_sessions` et
`training_sets`. Ils ne sont pas convertis ni régénérés : charges, résultats,
records, notes et repos restent inchangés. Les nouveaux parcours utilisent les
tables préfixées `plan_` et les tables relationnelles v2. Cette séparation évite
toute interprétation ambiguë et permet une adaptation de lecture explicite.

Les bases dev et prod restent séparées par les points d’entrée et noms de base
existants ; le schéma ne contient aucune donnée de démonstration.
