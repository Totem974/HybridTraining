# Format des définitions de programme

## Enveloppe version 1

Une définition utilise un identifiant interne stable, indépendant de la langue.
Structure cible :

```json
{
  "format": "hybrid-training-program",
  "schemaVersion": 1,
  "id": "forever-original-fsl-v1",
  "nameKey": "program.originalFsl",
  "source": {"work": "forever", "pages": "168-170"},
  "trainingMax": {"minimumRatio": 0.85, "maximumRatio": 0.90},
  "weeks": [],
  "assistance": [],
  "conditioning": {"status": "NEEDS_REVIEW"}
}
```

Les objets Dart fortement typés sont la source exécutable de la Base0. Le JSON
stocké avec le cycle garde l'identifiant et la version utilisés, afin qu'une
évolution du catalogue ne modifie pas rétroactivement l'historique.

## Validation obligatoire

- `format`, `schemaVersion`, `id` et `weeks` sont obligatoires ;
- un pourcentage est compris entre 0 et 1 ;
- séries et répétitions sont positives ;
- les identifiants de mouvements viennent d'une liste stable ;
- chaque règle a une source et un statut ;
- une règle `NEEDS_REVIEW` n'est pas exécutable ;
- une version inconnue est refusée explicitement.

## Évolution

Les nouvelles versions sont ajoutées, jamais réinterprétées. Une migration de
définition doit être distincte d'une migration de base SQLite. Le catalogue peut
ainsi croître programme par programme sans conditions dans les widgets.

