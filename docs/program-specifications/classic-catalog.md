# Catalogue 5/3/1 classique

## Portée

Ce document est un index de travail, pas une reproduction des sources. La source
française locale est secondaire et sert à recouper les concepts. Les règles à
implémenter doivent être confirmées dans les ouvrages de Jim Wendler.

## Cycle classique confirmé

| Élément | Règle structurée | Source | Statut |
|---|---|---|---|
| Mouvements | squat, développé couché, soulevé de terre, développé militaire | explication française, p. 2-3 | CONFIRMED_SECONDARY |
| Base de calcul | training max, présenté ici à 90 % du 1RM | explication française, p. 2 | CONFIRMED_SECONDARY |
| Semaine 1 | 65 % x 5, 75 % x 5, 85 % x 5+ | Forever, p. 165 (PDF 177) | CONFIRMED_PRIMARY |
| Semaine 2 | 70 % x 3, 80 % x 3, 90 % x 3+ | Forever, p. 165 (PDF 177) | CONFIRMED_PRIMARY |
| Semaine 3 | 75 % x 5, 85 % x 3, 95 % x 1+ | Forever, p. 165 (PDF 177) | CONFIRMED_PRIMARY |
| Progression du TM | +5 lb haut du corps, +10 lb squat/soulevé de terre après le cycle | Forever, p. 165 (PDF 177) | CONFIRMED_PRIMARY |
| Série finale | série de performance visant un record de répétitions ou d'e1RM | Forever, p. 165 (PDF 177) | CONFIRMED_PRIMARY |
| Décharge | structure et placement selon protocole choisi | Forever, section 7th Week Protocol, p. 31-34 | NEEDS_REVIEW |
| Arrondi des charges | incrément dépendant des disques et de l'unité | non fixé par ces pages | NEEDS_REVIEW |

## Garde-fous d'implémentation

- Les pourcentages s'appliquent au `trainingMax`, jamais directement au 1RM.
- Le symbole `+` représente une série de performance, pas une répétition imposée.
- L'unité et la règle d'arrondi sont des paramètres séparés du programme.
- Aucune règle `NEEDS_REVIEW` ne doit générer silencieusement une séance.

