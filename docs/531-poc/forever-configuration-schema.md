# Schéma de configuration Forever v3

Le schéma 3 sépare le profil commun du brouillon propre au mode. L'ordre canonique
des champs est stable pour rendre l'export déterministe.

```json
{
  "schemaVersion": 3,
  "mode": "forever",
  "common": {
    "unit": "kg",
    "inputMode": "oneRm",
    "trainingMaxRatio": 0.85,
    "daysPerWeek": 4,
    "trainingWeekdays": [1, 2, 4, 5],
    "roundingIncrement": 2.5,
    "startDate": "2026-07-20",
    "lifts": {},
    "plateInventory": {"barWeight": 20, "plates": {}}
  },
  "forever": {
    "planKind": "macrocycle",
    "recipeId": "forever-2l1a",
    "nodes": []
  }
}
```

Pour `mode: cycle`, le champ `cycle` contient template, variante, deload et
options Classic. Pour `mode: forever`, le champ `forever` contient soit
`standaloneProgramId`, soit `recipeId` et la séquence typée.

Chaque nœud contient `id`, `kind`, rôle ou purpose, `templateRevisionId` et
`autoInserted`. Les exports de plan ajoutent règles appliquées, projections TM,
sources et avertissements.

## Compatibilité

- v1 reste lisible par l'adaptateur historique ;
- v2 est migré explicitement, jamais interprété comme v3 ;
- les IDs historiques sont résolus par aliases sans être supprimés ;
- une version inconnue est rejetée avec une erreur stable ;
- décoder puis encoder produit la forme canonique v3.
