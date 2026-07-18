# Spécification du cycle de vie

## Unités de planification

| Terme | Définition proposée | Statut |
|---|---|---|
| Cycle | trois semaines de travail principal sous un TM et un template donnés | INDEXED |
| Phase | un ou plusieurs cycles partageant un rôle Leader ou Anchor | INDEXED |
| Bloc | Leader(s) → 7th Week typée → Anchor(s) → validation avant nouvelle programmation | NEEDS_REVIEW |
| Macrocycle | suite versionnée de blocs orientée vers un objectif de long terme | NEEDS_REVIEW |

`Bloc` et `macrocycle` sont des contrats de projet destinés à lever l'ambiguïté ;
ils ne doivent pas être présentés à l'utilisateur comme des définitions textuelles
de l'auteur avant validation éditoriale.

## Phases et transitions

| RuleId | Concept | Generation | Inputs | Outputs | Constraints | Source | Status |
|---|---|---|---|---|---|---|---|
| LIFE-PHASE-001 | Leader | Forever | template Leader | phase | plus de volume barre/supplemental ; moins d'assistance, jumps/throws et conditionnement dur ; easy conditioning favorisé ; contexte : phase de construction ; exceptions propres aux templates | *Forever*, livre p. 18-19 ; PDF p. 30-31 | RULES_REVIEWED |
| LIFE-PHASE-002 | Anchor | Forever | template Anchor | phase | moins de volume barre ; plus d'intensité relative ou séries plus poussées ; assistance/jumps/conditionnement dur peuvent augmenter ; contexte : expression/évaluation ; exceptions propres aux templates | *Forever*, livre p. 18-19 ; PDF p. 30-31 | RULES_REVIEWED |
| LIFE-COUNT-001 | Nombre de phases | Forever | niveau, template | 3L/2A, 2L/2A, 2L/1A | 2L/1A recommandé largement ; 3L/2A limité surtout débutants/challenges BBB-BBS ; contexte : 3-5 cycles planifiés ; exception : template non applicable | *Forever*, livre p. 17 ; PDF p. 29 | RULES_REVIEWED |
| LIFE-TRANS-001 | Leader → Anchor | Forever | fin des Leaders | 7th Week Deload puis Anchor | Deload toujours entre Leader et Anchor ; contexte : transition normale ; exception : le protocole peut aussi suivre tout cycle si besoin | *Forever*, livre p. 19, 21, 23 ; PDF p. 31, 33, 35 | RULES_REVIEWED |
| LIFE-TRANS-002 | Avant nouvelle programmation | Forever | fin du plan | TM Test ou PR Test | choix typé, jamais semaine générique ; contexte : nouvelle programmation/avant Leader ; exception : TM Test recommandé avant tout Leader | *Forever*, livre p. 21, 23 ; PDF p. 33, 35 | RULES_REVIEWED |
| LIFE-BEYOND-001 | Cycle Beyond | Beyond | deux cycles de 3 semaines | 6 semaines puis deload | TM augmente après les trois premières semaines ; deload après la sixième ; contexte : modèle Beyond ; exception : calendrier allongé si fréquence <4 lifts/7 jours | *Beyond*, livre p. 6-8 ; PDF p. 10-12 | RULES_REVIEWED |

## 7th Week Protocol comme bloc typé

| RuleId | Concept | Generation | Inputs | Outputs | Constraints | Source | Status |
|---|---|---|---|---|---|---|---|
| LIFE-7W-DEL | 7th Week Deload | Forever | TM validé, transition | bloc `deload` : 70 %×5, 80 %×3-5, 90 %×1, TM×1 | Contexte : récupération et transition Leader→Anchor ; TM déjà connu correct ; exception : utilisable après tout cycle si nécessaire | *Forever*, livre p. 21 ; PDF p. 33 | RULES_REVIEWED |
| LIFE-7W-TM | 7th Week TM Test | Forever | TM, ratio cible | bloc `tmTest` : 70 %×5, 80 %×5, 90 %×5, TM×3-5 | Contexte : avant Leader/nouvelle programmation ; succès ≥3 pour cible 90 %, 5 pour cible 85 % ; exception : ratio inférieur imposé par template | *Forever*, livre p. 20-21 ; PDF p. 32-33 | RULES_REVIEWED |
| LIFE-7W-PR | 7th Week PR Test | Forever | TM, objectif | bloc `prTest` : 70 %×5, 80 %×5, 90 %×5, TM×objectif/PR | Contexte : après travail majoritairement léger/avant nouvelle programmation ; si moins de 3-5 reps, ajuster le TM ; exception : objectif non nécessairement record absolu | *Forever*, livre p. 21 ; PDF p. 33 | RULES_REVIEWED |

Le nom ne signifie pas une occurrence toutes les sept semaines. Le protocole
accepte 2, 3 ou 4 jours/semaine et une assistance réduite ; ces modalités sont
sourcées livre p. 21-23 / PDF p. 33-35.

## Contrats proposés pour le code

`ProgrammingPlan` contient une liste ordonnée de `PhaseDefinition`, pas deux
booléens. `PhaseDefinition` porte `PhaseRole`, nombre de cycles, template et
politiques de charge. `TransitionBlock` contient un `SeventhWeekProtocol`
discriminé et ses conditions. `ProgrammingBlock` conserve génération, version,
état (`planned`, `active`, `completed`, `invalidated`) et décisions de TM. Un
`MacrocyclePlan` agrège des blocs sans réinterpréter leur génération.
