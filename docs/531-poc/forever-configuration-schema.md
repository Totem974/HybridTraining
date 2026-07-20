# Schéma de configuration Forever v4

La configuration POC courante porte `schemaVersion: 4`. Elle sépare le profil
commun de la configuration propre au mode et représente Forever soit par un
programme autonome, soit par une série finie de macrocycles. L'ordre canonique
des champs est stable afin que l'export reste déterministe.

## Forme macrocycle

```json
{
  "schemaVersion": 4,
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
    "series": {
      "id": "series-42",
      "terminated": false,
      "macrocycles": [
        {
          "instanceId": "M1",
          "intent": "active",
          "status": "active",
          "recipeId": "forever-2l1a-v2",
          "slots": [],
          "protocols": [],
          "trainingMaxStates": {}
        }
      ]
    }
  }
}
```

Les trois slots et les deux protocoles obligatoires de `forever-2l1a-v2` sont
des objets typés et identifiés. Ils ne sont pas reconstruits depuis leur texte
visible. `trainingMaxStates` conserve les décisions par lift et par frontière.
Une série terminée ne peut contenir aucun macrocycle actif ou futur.

## Forme autonome

Pour Beginner Prep School, `forever` contient uniquement :

```json
{"standaloneProgramId": "forever-beginner-prep-school-v1"}
```

`standaloneProgramId` et `series` sont exclusifs. Une configuration qui fournit
les deux, aucun des deux, un identifiant dupliqué ou une recette
`needsReview` est rejetée.

## Compatibilité

- la v2 est migrée vers la v3 transitoire, puis vers la v4 ;
- la v3 historique est migrée directement vers la v4 ;
- les aliases historiques sont conservés comme informations de transport ;
- `forever-2l1a` devient la recette canonique `forever-2l1a-v2` ;
- une version inconnue est rejetée avec une erreur stable ;
- décoder puis encoder produit toujours la forme canonique v4.

La forme détaillée et ses invariants sont protégés par
`poc_531_configuration_codec_test.dart`. Les migrations sont décrites dans
[Migration Forever](forever-migration.md).
