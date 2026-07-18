# Matrice de maturité des programmes 5/3/1

## Convention

La maturité documentaire est indépendante de la maturité d'implémentation.
`READY_TO_IMPLEMENT` n'est accordé que si chaque règle indispensable à la
génération est `RULES_REVIEWED`. `NONE` signifie qu'aucun preset correspondant
n'est présent à la base `51398a1` ; cela ne préjuge pas du travail d'autres branches.

Champs abrégés : `L` Leader, `A` Anchor, `T` Transition, `P` Prep ; `NR` non
revu. Sauf indication contraire, jours, TM, main, supplemental, assistance,
conditioning et séquence sont `NEEDS_REVIEW`.

| Concept id | Titre/origine/révisions | Rôle | Jours / lifts séance | TM ; main ; supplemental | Assistance / conditioning / blocs | Doc | Impl. | Prêt | Blocage |
|---|---|---|---|---|---|---|---|---|---|
| `program.beginner-prep-school` | Forever ; v1 | L | 3 ; 2 | 85-90 % ; 5's Pro ; FSL/SSL 5x5 | circuit prescrit ; running 3x ; cycles sans durée fixe | RULES_REVIEWED | NONE | oui | aucun blocage génératif |
| `program.original-531` | Original ; révision Forever | A/mixte | 4 ; 1 | 85-90 % ; 3/5/1 PR ; aucun ou selon preset | 50-100/catégorie ; plages à confirmer ; transition possible | RULES_REVIEWED | PARTIAL | non | conditioning, arrondi et transition à figer |
| `program.original-531-fsl` | Original + FSL Beyond ; révision Forever | L/A | 4 ; 1 | 85-90 % ; 3/5/1 ; FSL 5x5 | 50-100/catégorie ; conditioning à revoir ; L vers A | RULES_REVIEWED | PARTIAL | non | règles de conditioning/transition |
| `supplemental.fsl` | Beyond ; multiple sets, rest-pause, pauses, Forever 5x5 | composant | dépend preset | dépend ; n/a ; variantes multiples | dépend preset | INDEXED | PARTIAL | non | ne constitue pas seul un programme |
| `supplemental.bbb` | Original ; Beyond variants/challenge ; Forever | L | NR | TM Forever annoncé 85 %, 90 % débutant ; reste NR | NR | INDEXED | NONE | non | section PDF 57-69 à revoir |
| `supplemental.bbs` | Forever | L | NR | NR | NR | INDEXED | NONE | non | section PDF 146-154 à revoir |
| `supplemental.ssl` | Forever | composant | dépend preset | révision 5x5 observée dans BPS | dépend preset | PARTIAL_RULES_REVIEWED | NONE | non | catalogue complet de la révision non revu |
| `component.5s-pro` | Beyond « 5's Progression », Forever | composant | dépend preset | séries principales toutes à 5 dans BPS ; famille NR | dépend preset | INDEXED | PARTIAL | non | variations et compatibilités non revues |
| `component.joker-sets` | Beyond ; mentions Forever | composant anchor | dépend preset | ajouté après main selon règles NR | dépend preset | INDEXED | NONE | non | pas de preset Forever autonome prouvé |
| `component.widowmaker` | Forever | supplemental | dépend preset | NR | dépend preset | INDEXED | NONE | non | distinguer du Widowmaker Circuit |
| `program.1000-percent-awesome` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 86-88 à revoir |
| `program.coffinworm` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 137-140 à revoir |
| `program.pervertor` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 172-175 à revoir |
| `program.god-is-a-beast` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 120-126 à revoir |
| `program.krypteia` | Forever | programme/challenge candidat | NR | TM 85 % mentionné p.33, reste NR | NR | INDEXED | NONE | non | PDF 245-254 à revoir |
| `program.leviathan` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 210-212 à revoir |
| `program.widowmaker-circuit` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 237-239 à revoir |
| `program.svr-ii` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 89-93 à revoir |
| `program.morning-star` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 94-95 à revoir |
| `program.volume-and-strength` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 96-99 à revoir |
| `program.5x5-531` | Forever | famille | NR | NR | NR | INDEXED | NONE | non | PDF 100-111 à revoir, révisions à séparer |
| `program.five-and-dime` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 112-116 à revoir |
| `program.simplest-strength` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 117-119 à revoir |
| `program.black-army-jacket` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 127-129 à revoir |
| `program.spinal-tap-5s-pro` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 130-133 à revoir |
| `program.spinal-tap-high-school` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 134-136 à revoir |
| `program.full-body-85` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 144-145 à revoir |
| `program.supplemental-heaven` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 155-156 à revoir |
| `program.full-body-squat-push-pull` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 157-171 à revoir |
| `program.prowler-challenge` | Forever | challenge candidat | NR | NR | NR | INDEXED | NONE | non | PDF 182-184 à revoir |
| `program.original-challenge` | Forever | challenge candidat | NR | NR | NR | INDEXED | NONE | non | PDF 185-188 à revoir |
| `program.combination-template` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 189-191 à revoir |
| `program.limited-time` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 192-196 à revoir |
| `program.bodybuilder-upper-athlete-lower` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 197-198 à revoir |
| `program.strength-conditioning` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 199-203 à revoir |
| `program.wendler-classic` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 204-209 à revoir |
| `program.con-clavi-con-dio` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 213-216 à revoir |
| `program.prep-fat-loss` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 217-222 à revoir |
| `program.strength-circuits` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 223-229 à revoir |
| `program.ceremony-of-opposites` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 240-241 à revoir |
| `program.2x2x2` | Forever | candidat | NR | NR | NR | INDEXED | NONE | non | PDF 242-244 à revoir |

## Dépendances documentaires communes

Toutes les lignes dépendent des principes et du TM (PDF 14-18), de la composition
de séance (18-29), des blocs Leader/Anchor et du 7th Week Protocol (29-34), de
l'assistance (36-46) et du conditioning (256-266). Une section de programme peut
restreindre ou remplacer ces valeurs générales ; la règle locale prévaut et doit
être sourcée séparément.

