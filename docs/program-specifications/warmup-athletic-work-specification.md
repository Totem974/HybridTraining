# Spécification warm-up, mobilité et travail athlétique Forever

## Sources et statuts

Règles revues dans *5/3/1 Forever*, pages PDF 18-26. Les prescriptions propres à
un programme prévalent sur les valeurs générales. Statuts : `RULES_REVIEWED`,
`INDEXED`, `NEEDS_REVIEW`, `CONTRADICTORY`, `NOT_APPLICABLE`.

## Mobilité et warm-up général

| Règle | Prescription | Source | Statut |
|---|---|---:|---|
| Position | avant chaque séance de lifting ou hard conditioning | 18-21 | RULES_REVIEWED |
| Durée usuelle | 10-15 minutes, adaptée à l'âge et aux besoins | 19 | RULES_REVIEWED |
| Effort | ne doit pas fatiguer ; qualité, contrôle, régularité | 19-21 | RULES_REVIEWED |
| Agile 8 | protocole complet possible | 19 | RULES_REVIEWED |
| Taxonomie libre | mise en mouvement, hanches/aine latéral, poids du corps, jambes/fléchisseurs, épaules, squat profond | 20 | RULES_REVIEWED |
| Circuit minimal | jumping jack 25, squat hold 30 s, push-up 5 avec pause, Bulgarian 5/jambe avec pause, suspension 30 s | 20 | RULES_REVIEWED |

Un warm-up barbell est distinct : séries d'approche du main lift, charges et
répétitions dépendantes du lift/preset. Forever autorise d'intercaler au plus
3 jumps/throws entre ces séries après adaptation (PDF 26-27). Le générateur ne
doit pas inventer une rampe universelle si le preset ne la fournit pas.

## Jumps et throws

| Règle | Prescription | Source | Statut |
|---|---|---:|---|
| Ordre | après warm-up, avant le lifting | 21, 26 | RULES_REVIEWED |
| But | explosivité/activation, jamais conditioning | 21-23 | RULES_REVIEWED |
| Volume général | 10-20 contacts ou throws par séance ; recommandation locale prioritaire | 22-23 | RULES_REVIEWED |
| Repos | suffisant pour préserver l'explosivité | 23 | RULES_REVIEWED |
| Intensité throws | charge permettant une exécution explosive ; 10-12 lb indicatif pour la majorité des hommes entraînés | 22, 26 | RULES_REVIEWED |
| Interdictions | box jumps à hautes reps ; mouvement trop avancé ; charge sacrifiant la vitesse | 22 | RULES_REVIEWED |
| Plyométrie | non requise pour la population générale ; risque/stress supérieur | 22, 24-25 | RULES_REVIEWED |
| Box jump | 3-5 séries de 3-5 si utilisé seul ; hauteur submaximale adaptée | 23 | RULES_REVIEWED |
| Standing long jump | 5x3 si utilisé seul | 24 | RULES_REVIEWED |
| Standing hurdle | débutant 3x3, puis protocole box jump | 24 | RULES_REVIEWED |
| Bounding | avancé, non obligatoire ; contacts limités selon variante | 24-25 | RULES_REVIEWED |
| Medicine ball | overhead, backward, chest pass ; total 15-20 | 25-26 | RULES_REVIEWED |

## RequirementLevel

- `REQUIRED_BY_SYSTEM` : rôle présent dans le modèle Forever.
- `REQUIRED_BY_PRESET` : volume/mouvement imposé localement.
- `RECOMMENDED` : recommandation générale avec substitution possible.
- `OPTIONAL` : variante explicitement facultative.
- `PROHIBITED` : incompatibilité ou pratique interdite.

Pour la base Forever, mobilité/warm-up est `REQUIRED_BY_SYSTEM`. Jumps/throws est
`REQUIRED_BY_SYSTEM` mais le choix précis reste `RECOMMENDED` sauf prescription
locale. Une contre-indication utilisateur doit pouvoir désactiver l'activité en
conservant la règle source et la raison.

