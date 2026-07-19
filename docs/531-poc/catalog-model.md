# Modèle du catalogue 5/3/1

Le catalogue du POC est un index documentaire typé construit depuis le classeur
protégé `catalogue_exhaustif_531_3_livres.xlsx`. Le classeur n'est ni copié ni
commité. Le script `tool/531_catalog/import_catalog.ps1` lit directement les
feuilles « Catalogue 3 livres » et « POWERLIFTING SUPPL. » au format Open XML,
valide le nombre de lignes puis régénère le manifeste Dart et le rapport JSON.

Le manifeste réutilise les types publics du CORE (`ProgramDefinition`,
`Generation`, `SourceKind`, `CatalogEntryKind`) et ajoute seulement
`CatalogRecord`, qui conserve la nature documentaire d'origine et le marqueur
d'ambiguïté. Il n'existe donc pas de second modèle de génération concurrent.

## Classification

Chaque ligne reçoit exactement une classe : template exécutable, composant,
règle, schedule, protocole, transition ou documentation. La classification des
lignes non exécutables est une classification d'index, pas une validation de
prescription. Elle est reproductible à partir des colonnes `Nature` et `Famille`.

Quatre correspondances seulement sont exécutables, car elles disposent déjà
d'une stratégie Core v5 validée :

| Ligne | Stratégie |
| --- | --- |
| PL-001 | `canonical-powerlifting` |
| BY-026 | `canonical-beyond` |
| FV-141 | `canonical-bps` |
| FV-236 | `canonical-forever-original-fsl` |

Powerlifting utilise `SourceKind.supplement` et n'ajoute aucune quatrième valeur
à `Generation`. Pour permettre le rattachement au moteur sans prétendre créer une
génération Powerlifting, ses lignes sont rattachées techniquement à `original` et
restent toujours distinguées par leur source de type supplément.

Toutes les autres lignes portent une raison `NEEDS_REVIEW`. Une ligne
documentaire, même nommée « Programme / template » dans la source, n'est pas
automatiquement une prescription générable.

## Régénération

```powershell
.\tool\531_catalog\import_catalog.ps1 `
  -SourceXlsx .SOURCE\catalogue_exhaustif_531_3_livres.xlsx
```

Le chemin source est fourni explicitement afin qu'aucun chemin local ne soit
inscrit dans les artefacts. L'import échoue si le total n'est pas 354 ou si les
quatre correspondances exécutables ne sont pas présentes.
