# Migration Forever

## Configuration v2 vers v3

Le migrateur extrait unité, lifts, mode de saisie, ratio TM, jours, plaques,
arrondi et options communes. Les options Classic rejoignent `cycle`; la sélection
Forever rejoint `forever`.

Aliases conservés :

- `forever-original-531-fsl-2l1a-v1` → preset `FV-236` → recette
  `forever-2l1a` ;
- `forever-original-fsl-v1` → même recette ;
- `forever-beginner-prep-school-v1` → `FV-141` → programme autonome.

Une sélection inconnue reste non exécutable et produit une erreur ; elle n'est
jamais remplacée silencieusement par un défaut.

## Résultat historique

Le golden `forever-original-fsl-2l1a.golden.json` est la référence fonctionnelle.
La nouvelle recette conserve C1 Leader, C2 Leader, Deload, C3 Anchor et TM Test,
ainsi que prescriptions, provenance et ordre. Les nouveaux IDs de nœuds et états
TM enrichissent l'export sans supprimer les anciens IDs/snapshots.

## Déploiement

Les anciens générateurs deviennent des adaptateurs de lecture/génération. Après
validation des goldens, l'UI et le calculateur ne reconstruisent plus la séquence.
