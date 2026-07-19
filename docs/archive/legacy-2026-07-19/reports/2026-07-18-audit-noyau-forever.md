# Audit documentaire du noyau Forever - 2026-07-18

## Résultat

Les règles transversales nécessaires à l'agent G1 sont structurées dans quatre
spécifications. Les règles exécutables sont adossées à une double pagination.
Les termes de modélisation non directement définis par la source sont isolés en
`NEEDS_REVIEW`.

## Sources examinées

| Priorité | Source locale | Pagination | Usage | Statut |
|---:|---|---|---|---|
| 1 | *5/3/1 Forever* | 282 pages PDF | source normative principale | RULES_REVIEWED |
| 2 | *Beyond 5/3/1* | 220 pages PDF | origine/révision TM, cycles, 5's Progression, deload | RULES_REVIEWED |
| 3 | PDF français « explication » | 5 pages PDF | source secondaire non assimilée au livre Original | NOT_APPLICABLE |
| 4 | `docs/program-specifications/*.md` au commit 51398a1 | index et format | repérage/croisement, jamais substitut à la source primaire | INDEXED |

L'ouvrage primaire Original 5/3/1 n'a pas été identifié parmi les PDF locaux.
Son attribution historique reste donc séparée des prescriptions Forever et ne
reçoit aucune règle nouvelle.

## Couverture

| Sujet demandé | Document principal | Statut |
|---|---|---|
| TM, 1RM, weight-room max, validation, reset | `training-max-specification.md` | RULES_REVIEWED |
| ordre, PR Sets, 5's Pro, minimums | `main-work-specification.md` | RULES_REVIEWED |
| Leader, Anchor, nombres, transitions, 7th Week | `cycle-lifecycle-specification.md` | RULES_REVIEWED |
| cycle, bloc, macrocycle | `cycle-lifecycle-specification.md` | NEEDS_REVIEW pour les termes de projet bloc/macrocycle |
| vue consolidée et contrats | `forever-core-rules.md` | RULES_REVIEWED |

## Divergences explicites

- Beyond : deux cycles successifs, hausse du TM à mi-parcours, puis deload.
- Forever : phases Leader/Anchor et transition par un 7th Week Protocol typé.
- Beyond conserve 90 % comme cible centrale ; Forever rend le ratio dépendant du
  template, avec 85 % très fréquent et 80 % possible.
- Une semaine 7 de Beyond ne doit pas être migrée automatiquement vers un objet
  Forever `SeventhWeekProtocol` sans type et provenance.

## Contrôles anti-invention

- aucune donnée de l'application d'origine, du prototype ou du JSON local n'a été
  utilisée comme règle ;
- aucun texte long n'est reproduit ; les formulations sont normalisées ;
- aucune règle ambiguë d'arrondi, de macrocycle ou de provenance Original n'est
  rendue exécutable ;
- les exceptions de template restent des exceptions, jamais des valeurs globales.

## Limites et validation restante

`NEEDS_REVIEW` : terminologie produit de `bloc` et `macrocycle`, politique
d'arrondi des charges, et pagination/règles de l'édition Original absente. Ces
points ne bloquent pas l'implémentation des règles Forever portant
`RULES_REVIEWED`, mais doivent rester non exécutables tant qu'ils ne sont pas
validés par une source primaire.
