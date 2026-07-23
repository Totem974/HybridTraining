# Validation courante — Web statique Cycle

Date de vérification : 23 juillet 2026

Ce document décrit l'état observé sur la branche de refonte courante. Le rapport
`static-web-g14-g15-2026-07-22.md` reste une preuve historique de son checkpoint ;
ses compteurs, ses tailles et ses mesures ne décrivent pas l'état actuel.

## Référence et catalogue

| Contrôle | Résultat observé |
| --- | --- |
| Oracle source exact | 35 scénarios figés |
| Documents catalogue | 58 |
| Catalogue brut | 22 templates et 41 variantes |
| Catalogue Cycle public | 19 templates et 37 variantes |

## Tests et parité

| Contrôle | Résultat observé |
| --- | --- |
| Moteur Dart pur | 186/186 tests réussis |
| Bridge Web | 54/54 tests réussis |
| Contrats JSON v1 | 16/16 tests réussis |
| Application Flutter de référence | 468/468 tests réussis |
| Analyse Flutter | aucune anomalie |
| Build Flutter Web release | réussi |
| Tests unitaires Web | 98/98 réussis |
| Matrice E2E | 105 réussis, 30 ignorés intentionnellement |
| Parité Cycle native | 37/37 |
| Parité Cycle JavaScript | 37/37 |
| Parité Forever | 1/1 |

Les 30 cas E2E ignorés correspondent à des projets ou tests auxquels ces cas ne
s'appliquent pas. Ils ne représentent ni des échecs ni des validations
manquantes.

## Poids des artefacts

Mesures effectuées sur les artefacts courants :

| Artefact | Brut | Gzip |
| --- | ---: | ---: |
| Bridge Dart JavaScript | 297 058 o | 92 114 o |
| JavaScript UI | 60 714 o | 18 243 o |
| CSS | 29 467 o | 5 524 o |
| `catalog.bundle.json` | 432 646 o | 37 361 o |
| `catalog.db` | 1 548 288 o | 162 125 o |

## Performances locales

Mesures locales effectuées sur le port 4176 :

| Scénario | Médiane | p95 |
| --- | ---: | ---: |
| Premier chargement | 559,49 ms | 566,11 ms |
| Génération Standard | 92,5 ms | 101,4 ms |
| Génération BBB | 92,5 ms | 106,4 ms |

## Conclusion

Les 37 variantes Cycle publiques sont couvertes par la même requête côté Dart
natif et côté bridge JavaScript. Le scénario Forever existant reste identique.
Le front conserve le moteur Dart comme unique autorité métier ; ses tests Web
et sa matrice E2E sont validés selon les compteurs ci-dessus. Flutter Web et
`/forever/` restent conservés : aucune suppression ni bascule de l'oracle n'est
incluse dans cette validation.
