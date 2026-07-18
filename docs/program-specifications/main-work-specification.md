# Spécification du travail principal

## Prescriptions normalisées

| RuleId | Concept | Generation | Inputs | Outputs | Constraints | Source | Status |
|---|---|---|---|---|---|---|---|
| MAIN-ORDER-001 | 5/3/1 | Forever | TM | 3 semaines | W1 65×5, 75×5, 85×5+ ; W2 70×3, 80×3, 90×3+ ; W3 75×5, 85×3, 95×1+ ; contexte : ordre standard ; exception : variation déclarée | *Forever*, livre p. 3 ; PDF p. 15 | RULES_REVIEWED |
| MAIN-ORDER-002 | 3/5/1 | Forever | TM | 3 semaines | Ordre 3, 5, 5/3/1 ; avec PR Sets, ceux-ci sont limités aux semaines 1 et 3 ; contexte : templates compatibles ; exception : prescription explicite différente | *Forever*, livre p. 65 ; PDF p. 77 | RULES_REVIEWED |
| MAIN-MIN-001 | Minimum standard | Forever | semaine | 5/3/1 reps minimales | Le `+` est une permission de dépasser le minimum, pas une obligation d'aller à l'échec ; contexte : standard ; exception : 5's Pro et tests typés | *Forever*, livre p. 3, 5 ; PDF p. 15, 17 | RULES_REVIEWED |
| MAIN-PR-001 | PR Set | Forever | série finale, objectif | performance arrêtée à l'objectif | Objectif défini avant la série ; 1-2 reps en réserve ; arrêt sur dégradation technique ; record possible par charge/reps, formule ou qualité ; contexte : semaine éligible d'un template PR ; exception : le résultat peut ne pas être un record absolu | *Forever*, livre p. 5, 65-66 ; PDF p. 17, 77-78 | RULES_REVIEWED |
| MAIN-5PRO-001 | 5's Pro | Beyond → Forever | pourcentages des 3 séries | 5 reps prescrites sur chaque série | Pas de `+` implicite ; la révision Forever permet des supplemental différents par lift et limite les PR Sets ; contexte : template déclarant 5's Pro ; exception : montages explicitement listés | *Beyond*, livre p. 50 ; PDF p. 82. *Forever*, livre p. 218-220 ; PDF p. 230-232 | RULES_REVIEWED |

## Matrice de compatibilité

| Méthode | Dernière série | PR implicite | Ordre autorisé | Statut |
|---|---|---|---|---|
| Standard 5/3/1 | minimum 5 / 3 / 1, `+` selon template | non | 5/3/1 ou variation déclarée | INDEXED |
| PR Set | objectif défini, jamais échec volontaire | oui, seulement si déclaré | 3/5/1 recommandé ; semaines 1 et 3 | INDEXED |
| 5's Pro | exactement 5 prescrites | non | pourcentages hebdomadaires du template | INDEXED |

Ne pas inférer `PR Set` de la seule présence du symbole `+`. Ne pas représenter
5's Pro par un simple minimum de cinq : c'est une méthode de main work distincte.

## Contrats proposés pour le code

Un `MainWorkPrescription` discriminé par `standard531`, `prSet` ou `fivesPro`,
composé de `WeekPrescription` et `WorkSetPrescription`. `PrSetPolicy` porte
l'objectif, la réserve attendue et les critères d'arrêt. `WeekOrder` est une
valeur explicite ; l'index de semaine ne doit jamais déterminer seul la méthode.
