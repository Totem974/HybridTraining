# Migration Forever

## Versions à ne pas confondre

- la **configuration POC v4** est le JSON décodé par
  `Poc531ConfigurationCodec` ;
- le **plan Core v5** est le résultat métier canonique produit à partir de cette
  configuration ;
- le **schéma SQLite v5** persiste les structures Core et conserve les tables
  historiques ;
- la **sauvegarde v5** est l'enveloppe d'export/import, distincte du fichier
  SQLite.

La matrice des upgrades de base, leur atomicité et les preuves de conservation
sont dans [Traçabilité SQLite v1 vers v5](../migration/sqlite-v1-v5.md).

## Configuration v2 vers v4

Le codec accepte les configurations v2 et v3, applique successivement les
transformations v2→v3 puis v3→v4, et décode directement v4. Le migrateur extrait
unité, lifts, mode de saisie, ratio TM, jours, plaques, arrondi et options
communes. Les options Classic rejoignent `cycle`; la sélection Forever rejoint
`forever`. La v4 ajoute la représentation de série Forever sans changer la
version de la base SQLite.

Aliases conservés :

- `forever-original-531-fsl-2l1a-v1` → preset `FV-236` → recette v3
  `forever-2l1a` → recette canonique v4 `forever-2l1a-v2` ;
- `forever-original-fsl-v1` → même chaîne de migration ;
- `forever-beginner-prep-school-v1` → `FV-141` → programme autonome.

Une sélection inconnue reste non exécutable et produit une erreur ; elle n'est
jamais remplacée silencieusement par un défaut.

## Résultat historique

Le golden `forever-original-fsl-2l1a.golden.json` est la référence fonctionnelle.
La nouvelle recette conserve C1 Leader, C2 Leader, Deload, C3 Anchor et TM Test,
ainsi que prescriptions, provenance et ordre. Les nouveaux IDs de nœuds et états
TM enrichissent l'export sans supprimer les anciens IDs/snapshots.

Les confirmations de Training Max qui autorisent la progression Forever sont
désormais indexées par l'identifiant du nœud compilé. Pour la séquence
historique adaptée, les clés de compatibilité restent `C1`, `C2` et `C3` ; une
confirmation indexée uniquement par numéro de semaine ne fait plus avancer
Forever. Le support des confirmations hebdomadaires reste inchangé pour Beyond.

`_LegacyForeverIdentityAdapter` reste volontairement en place afin de préserver
les identifiants et snapshots historiques. Ce changement ne définit aucun
calendrier de retrait de cet adaptateur.

## Déploiement

Les anciens générateurs deviennent des adaptateurs de lecture/génération. Après
validation des goldens, l'UI et le calculateur ne reconstruisent plus la séquence.
