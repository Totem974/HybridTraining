# Spécification du Training Max

## Modèle conceptuel

| Terme | Définition opérationnelle | Ne doit pas être confondu avec |
|---|---|---|
| `actualOneRepMax` | meilleure charge réellement réalisée pour une répétition valide | TM |
| `estimatedOneRepMax` | estimation issue de `charge × reps × 0,0333 + charge` | record réellement réalisé |
| `weightRoomMax` | terme Beyond pour le maximum réaliste utilisable en salle | max de compétition supposé |
| `trainingMax` | base sous-maximale à laquelle les pourcentages du programme sont appliqués | 1RM, e1RM, objectif de performance |

## Règles

| RuleId | Concept | Generation | Inputs | Outputs | Constraints | Source | Status |
|---|---|---|---|---|---|---|---|
| TM-CALC-001 | Calcul e1RM | Forever | charge > 0 ; reps > 0 | e1RM | `charge × reps × 0,0333 + charge` ; contexte : absence de 1RM fiable/reset ; exception : 1RM réel valide | *Forever*, livre p. 2, 21 ; PDF p. 14, 33 | RULES_REVIEWED |
| TM-CALC-002 | Calcul TM | Forever | 1RM ou e1RM ; ratio prescrit | TM | Ratio généralement 0,85-0,90 ; le template peut prescrire 0,80 ; contexte : par mouvement et par template ; exception : cas très forts documentés sous 0,85 | *Forever*, livre p. 2, 20-21 ; PDF p. 14, 32-33 | RULES_REVIEWED |
| TM-TEST-001 | 7th Week TM Test | Forever | TM, ratio cible | 3-5 reps au TM | montée : 70 %×5, 80 %×5, 90 %×5, 100 % TM×3-5 ; 90 % cible exige ≥3, 85 % exige 5 ; reps fortes/rapides, sans échec ; contexte : avant Leader/nouvelle programmation ; exception : aucune | *Forever*, livre p. 20-21 ; PDF p. 32-33 | RULES_REVIEWED |
| TM-TEST-002 | Test réussi | Forever | résultat TM Test | conserver/progresser normalement | Plus de 5 reps n'autorise jamais une hausse supérieure à la progression ordinaire ; contexte : fin de test ; exception : hausse inférieure ou répétition permise | *Forever*, livre p. 20-21 ; PDF p. 32-33 | RULES_REVIEWED |
| TM-TEST-003 | Test insuffisant | Forever | 1-2 reps au TM | TM abaissé | recalculer l'e1RM avec le résultat puis choisir 85-90 %, ou le ratio inférieur imposé ; préférence de coaching : abaisser si <5 reps fortes ; contexte : test ; exception : seuil exact dépend du ratio/template | *Forever*, livre p. 21 ; PDF p. 33 | RULES_REVIEWED |
| TM-PROG-001 | Incrément | Forever | fin de cycle | TM suivant | +5 lb maximum upper (press, bench), +10 lb maximum lower (squat, deadlift) ; moins ou zéro autorisé ; contexte : cycle terminé ; exception : aucune hausse accélérée | *Forever*, livre p. 3 ; PDF p. 15 | RULES_REVIEWED |
| TM-RESET-001 | Reset individualisé | Forever | stagnation/test insuffisant | nouveau TM par mouvement | resets fréquents, surtout press/bench ; ne pas synchroniser artificiellement tous les mouvements ; contexte : long terme ; exception : aucune | *Forever*, livre p. 23 ; PDF p. 35 | RULES_REVIEWED |

## Validation d'entrée

- Refuser un ratio absent si le template n'a pas de valeur par défaut revue.
- Refuser tout ratio ou incrément provenant d'une traduction, d'un libellé UI ou
  d'une génération différente sans règle de transition explicite.
- Conserver unité et granularité d'arrondi séparément. La source illustre un
  arrondi mais ne fixe pas de règle universelle : `NEEDS_REVIEW`.
- Un TM Test en échec produit une décision explicite ; il ne doit ni supprimer
  l'historique ni modifier rétroactivement les cycles terminés.

## Contrats proposés pour le code

`MaxBasisKind`, `TmRatioPolicy`, `TmTestPrescription`, `TmTestResult`,
`TmAdjustmentDecision` et `LoadRoundingPolicy`. Chaque décision doit porter le
mouvement, l'ancien TM, le nouveau TM, le motif, la génération et le `RuleId`.
