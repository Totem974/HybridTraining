# Contrat du snapshot d'entraînement résolu v1

Le snapshot stocké avec un plan est une donnée de reproduction minimale. Il ne
contient ni donnée d'athlète, ni texte d'affichage, ni source, preuve ou extrait.
Ces informations restent dans leurs bases et contrats propriétaires.

## Structure fermée

La version 1 accepte uniquement cette structure. Chaque objet applique une
allowlist stricte : une clé supplémentaire invalide le snapshot.

```json
{
  "schemaVersion": 1,
  "catalogVersionId": "catalog-v1",
  "catalogContentHash": "sha256-du-catalogue",
  "template": {
    "id": "identifiant-stable",
    "revision": 1
  },
  "schedule": {
    "sessions": [
      {
        "id": "session-1",
        "sequence": 0,
        "offsetDays": 0,
        "blocks": [
          {"id": "block-1", "sequence": 0, "kind": "main"}
        ]
      }
    ]
  }
}
```

Les listes `sessions` et `blocks` sont non vides. Leurs séquences commencent à
zéro et suivent exactement l'ordre des tableaux. Les identifiants sont non
vides et uniques dans leur portée. La version et l'empreinte du catalogue
doivent être identiques aux métadonnées du plan.

## Canonisation et écriture

La canonicalisation v1 trie récursivement les clés, conserve l'ordre métier des
tableaux et normalise les nombres entiers et le zéro négatif. La frontière
d'écriture recalcule SHA-256 sur les octets UTF-8 de ce JSON canonique, compare
l'empreinte hexadécimale minuscule annoncée, puis stocke uniquement la forme
canonique. Un contrat, une clé ou une empreinte inconnus échouent fermés.

## Cycle de vie du plan

Les transitions autorisées sont :

- `draft` vers `scheduled` ou `cancelled` ;
- `scheduled` vers `active` ou `cancelled` ;
- `active` vers `completed` ou `cancelled`.

`completed` et `cancelled` sont terminaux. Une transition met à jour uniquement
la colonne `status`, dans une transaction qui vérifie aussi l'état de départ.
Un nouveau plan est toujours créé en `draft`, sans `completed_at`; aucun autre
état initial ne peut contourner cette machine d'état.
