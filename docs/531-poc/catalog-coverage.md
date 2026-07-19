# Couverture du catalogue

Le rapport machine lisible se trouve dans
`tool/531_catalog/catalog-coverage.json` (schéma 1).

## Résultat importé

| Mesure | Nombre |
| --- | ---: |
| Entrées importées | 354 |
| Entrées classées | 354 |
| Entrées canoniques | 329 |
| Original — Second Edition | 40 |
| Beyond | 107 |
| Forever | 182 |
| Supplément Powerlifting | 25 |
| Templates reliés à une stratégie exécutable | 4 |
| Entrées non exécutables | 350 |
| Entrées ambiguës / `NEEDS_REVIEW` | 350 |

La couverture de **classification** est de 100 % : aucune ligne importée n'est
ignorée. La couverture **exécutable** n'est volontairement pas déclarée complète.
Seuls les quatre presets déjà validés dans Core v5 sont reliés au moteur.

Les 350 autres lignes sont ambiguës au sens du POC : le classeur suffit à les
indexer, mais ne constitue pas à lui seul une spécification complète et validée
de génération. Elles sont donc bloquées individuellement avec une raison
explicite. Aucune série, répétition, transition ou règle de compatibilité n'est
inventée pour les rendre artificiellement exécutables.

La classification heuristique (`Nature` + `Famille`) est auditable et
reproductible, mais devra être revue ligne par ligne avant toute extension de la
surface exécutable. Le fichier Markdown disponible dans `.SOURCE` ne contient
pas le détail des 25 lignes Powerlifting; le XLSX est donc la source structurée
nécessaire pour reproduire les 354 lignes.
