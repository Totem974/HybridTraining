# Cœur Forever canonique

## Limites exécutables

- Preset actif : `forever-beginner-prep-school-v1`, version 1.
- Générateur : `ForeverMacrocycleGenerator` avec snapshot immuable.
- Adaptateur Original + FSL : compatibilité historique uniquement, non activable.
- Toute règle `NEEDS_REVIEW` est rejetée avant génération.

## Agrégats

- `VersionedTrainingPlan` fige blueprint, version, provenance, blocs, cycles,
  dates, séances, blocs de séance et prescriptions.
- `WorkoutExecution` porte l’état, la série active, les résultats, le repos,
  la pause et la pile d’annulation.
- `TmAdjustmentDecision` porte mouvement, ancien/nouveau TM, type, motif,
  `RuleId`, génération et source.
- `TrainingStatistics` sépare strictement travail prescrit et réalisé.

## Invariants principaux

- Génération et persistance sont deux opérations distinctes.
- Les mêmes entrées, date, politique d’arrondi et seed donnent le même plan.
- Le domaine ne dépend ni de Flutter ni de SQLite et ne lit pas l’horloge.
- Seul un preset complet, versionné et disponible est générable.
- Une mutation runtime et son événement sont enregistrés dans une transaction.
- Le tonnage réel exige répétitions et charge réellement saisies.
- Une progression TM ne dépasse pas le plafond revu et ne remplace jamais
  l’historique précédent.
