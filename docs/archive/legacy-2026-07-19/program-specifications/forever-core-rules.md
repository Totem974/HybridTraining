# Noyau transversal 5/3/1 Forever

## Portée et méthode

Cette spécification formalise uniquement les règles transversales nécessaires à
l'exécution. Elle ne constitue pas un catalogue de templates. La priorité des
sources est : *5/3/1 Forever*, puis *Beyond 5/3/1*, puis les index structurés du
dépôt. Aucun comportement de l'application d'origine ou du prototype n'est une
source. L'édition Original n'étant pas disponible comme source primaire locale,
ses règles historiques non reprises explicitement restent `NEEDS_REVIEW`.

Dans les références ci-dessous, `livre` désigne la pagination imprimée et `PDF`
la page du fichier local. Pour *Forever*, l'écart observé dans les sections
utilisées est de 12 pages. Le PDF *Beyond* contient des pages liminaires et des
doublons : son décalage n'est pas constant, donc chaque paire est relevée
indépendamment.

## Registre transversal

| RuleId | Concept | Generation | Inputs | Outputs | Constraints | Source | Status |
|---|---|---|---|---|---|---|---|
| CORE-TM-001 | Training Max | Forever | 1RM réel ou 1RM estimé ; ratio du template | TM | Le TM est une base de programmation, pas un record ; généralement 85-90 %, parfois 80 % selon le template ; contexte : mouvement et template ; exception : certains athlètes très forts utilisent moins ; génération : révision Forever | *Forever*, livre p. 2, 20-21 ; PDF p. 14, 32-33 | RULES_REVIEWED |
| CORE-TM-002 | 1RM / weight-room max / TM | Beyond → Forever | performance maximale réelle ou estimée | trois concepts non interchangeables | Le `weight-room max` de Beyond correspond au maximum réellement utilisable en salle ; Forever emploie `actual max`/`estimated max`, puis applique un ratio pour produire le TM ; ne jamais enregistrer le TM comme 1RM ; contexte : calcul initial et reset ; exception : aucune | *Beyond*, livre p. 6 ; PDF p. 10. *Forever*, livre p. 2, 20 ; PDF p. 14, 32 | RULES_REVIEWED |
| CORE-TM-003 | Estimation | Forever | charge, répétitions | e1RM = charge × reps × 0,0333 + charge | Le ratio du template est appliqué ensuite ; l'arrondi présenté est illustratif, aucune granularité universelle n'est prescrite ici ; contexte : initialisation/reset ; exception : un 1RM réel peut être fourni | *Forever*, livre p. 2, 21 ; PDF p. 14, 33 | RULES_REVIEWED |
| CORE-WEEK-001 | Ordre classique | Forever | cycle standard | semaines 5/3/1 : 5, 3, 5/3/1 | W1 65/75/85 %, W2 70/80/90 %, W3 75/85/95 % ; les `+` n'imposent pas un PR Set à tous les templates ; contexte : structure de référence ; exception : variations/templates | *Forever*, livre p. 3 ; PDF p. 15 | RULES_REVIEWED |
| CORE-WEEK-002 | Ordre 3/5/1 | Forever | template déclarant 3/5/1 | semaines : 3, 5, 5/3/1 | Utilisé notamment avec PR Sets pour réserver les PR aux semaines 1 et 3 ; ne pas le rendre global ; contexte : template compatible ; exception : prescriptions propres au template | *Forever*, livre p. 65 ; PDF p. 77 | RULES_REVIEWED |
| CORE-MAIN-001 | Séries minimales | Forever | semaine, TM, prescription | répétitions prescrites | 5/3/1 standard : minima 5, 3 et 1 sur la dernière série ; `+` autorise un objectif supérieur sans aller à l'échec ; 5's Pro remplace ces minima par 5 sur les trois séries de travail ; contexte : main work ; exception : PR Set/PR Test explicitement typé | *Forever*, livre p. 3, 5, 65 ; PDF p. 15, 17, 77 | RULES_REVIEWED |
| CORE-MAIN-002 | PR Set | Forever | série finale éligible, objectif du jour | résultat reps/charge/qualité | Ce n'est pas un AMRAP sans limite ; fixer un objectif, garder 1-2 reps en réserve et arrêter si la technique se dégrade ; en 3/5/1, semaines 1 et 3 seulement ; contexte : template avec PR Set ; exception : un objectif peut être qualitatif | *Forever*, livre p. 5, 65-66 ; PDF p. 17, 77-78 | RULES_REVIEWED |
| CORE-MAIN-003 | 5's Pro | Beyond → Forever | trois pourcentages hebdomadaires | 5 reps à chaque série | Révision Forever : toutes les séries principales sont des séries de 5 prescrites, sans PR Set implicite ; compatible avec certains montages explicitement documentés ; contexte : template 5's Pro ; exception : 5x5/3/1 dans le template 5's Pro Forever | *Beyond*, livre p. 50 ; PDF p. 82. *Forever*, livre p. 218-220 ; PDF p. 230-232 | RULES_REVIEWED |
| CORE-PROG-001 | Progression ordinaire | Forever | TM courant, famille de mouvement, fin de cycle | nouveau TM | maximum +5 lb press/bench et +10 lb squat/deadlift ; une hausse inférieure ou nulle est permise, jamais supérieure ; aucune accélération après un bon test ; contexte : fin d'un cycle ; exception : prescription plus conservatrice du template | *Forever*, livre p. 3, 20-21 ; PDF p. 15, 32-33 | RULES_REVIEWED |
| CORE-PROG-002 | Reset | Forever | TM test insuffisant, charge, reps | e1RM puis TM réduit | 1-2 reps au TM impose une baisse vers 85-90 % de l'e1RM ; l'auteur préfère au moins 5 reps fortes et indique que les resets sont fréquents et par mouvement ; contexte : test/échec de validation ; exception : certains templates imposent 80 ou 85 % | *Forever*, livre p. 21, 23 ; PDF p. 33, 35 | RULES_REVIEWED |
| CORE-LIFE-001 | Leader / Anchor | Forever | template, objectif, expérience | phase typée | Leader : plus de volume barre/supplémentaire et moins d'assistance/conditionnement dur ; Anchor : moins de volume barre, plus d'intensité ou d'effort, davantage d'assistance/jumps/conditionnement dur ; ce ne sont pas des booléens ; exceptions : templates documentés qui dérogent | *Forever*, livre p. 17-19 ; PDF p. 29-31 | RULES_REVIEWED |
| CORE-LIFE-002 | Séquences | Forever | niveau, template | 3L/2A, 2L/2A ou 2L/1A | 2L/1A est la recommandation générale ; 3L/2A surtout débutants et challenges BBB/BBS, non recommandé à la plupart ; contexte : plan de 3-5 cycles ; exception : applicabilité du template | *Forever*, livre p. 17 ; PDF p. 29 | RULES_REVIEWED |
| CORE-7W-001 | 7th Week Protocol | Forever | type, position dans le plan | bloc de test/deload | Nom historique, pas « chaque septième semaine » ; variantes `deload`, `tmTest`, `prTest` ; contexte : transition/validation ; exception : peut être placé après tout cycle si nécessaire | *Forever*, livre p. 19, 23 ; PDF p. 31, 35 | RULES_REVIEWED |
| CORE-TERM-001 | Cycle / bloc / macrocycle | Projet | règles sourcées ci-dessus | vocabulaire non ambigu | `cycle` = trois semaines d'un template ; `bloc` = séquence Leader(s), protocole 7th Week, Anchor(s), puis validation ; `macrocycle` = suite planifiée de blocs vers un objectif. Seul `cycle` est un terme directement défini par la source ; `bloc` et `macrocycle` sont des termes de modélisation proposés, pas des citations | *Forever*, livre p. 3, 17-23 ; PDF p. 15, 29-35 | NEEDS_REVIEW |

## Origine et révision

| Concept | Origine documentée | Révision exécutable retenue | Divergence |
|---|---|---|---|
| TM à 90 % | Beyond confirme l'usage de 90 % du weight-room max | Forever prescrit le ratio du template, usuellement 85-90 % | 90 % n'est plus une constante globale |
| Cycles | Beyond propose deux cycles consécutifs puis deload | Forever structure Leader(s), 7th Week typée, Anchor(s) | Ne pas convertir automatiquement une séquence Beyond en Leader/Anchor |
| 5's Progression / 5's Pro | Beyond formalise la progression à cinq répétitions | Forever la réemploie dans des templates Leader et Anchor | Le rôle de phase vient de Forever, pas de Beyond |
| PR Sets | Présentés comme composant Original dans Forever | Forever limite leur emplacement selon le template | Origine historique distincte de la révision applicable |
| 7th Week Protocol | Beyond contient des deloads calendaires et optionnels | Forever définit trois blocs typés | Une semaine Beyond « week 7 deload » n'est pas un protocole Forever générique |

## Contrats proposés pour le code

Sans imposer d'implémentation, le domaine minimal devrait distinguer :

- enums `ProgrammingGeneration { original, beyond, forever }`, `WeekOrder { fiveThreeOne, threeFiveOne }`, `MainWorkMethod { standard531, prSet, fivesPro }`, `PhaseRole { leader, anchor }`, `SeventhWeekKind { deload, tmTest, prTest }` ;
- valeurs immuables `TrainingMax`, `OneRepMax`, `EstimatedOneRepMax`, `Percentage`, `LoadIncrement`, `RepTarget` ;
- objets versionnés `CycleDefinition`, `PhaseDefinition`, `ProgrammingBlock`, `MacrocyclePlan`, `SeventhWeekProtocol` ;
- objets de décision `TmTestResult`, `TmAdjustmentDecision`, `TransitionRule`, chacun conservant `ruleId`, génération et source ;
- un Leader/Anchor portant ses politiques de volume, intensité, assistance et conditionnement, sans champ booléen `isLeader` ;
- un `SeventhWeekProtocol` discriminé par son type, avec séries, objectif et règle d'échec propres.

Toute règle `NEEDS_REVIEW` est non exécutable. La provenance historique ne doit
jamais choisir silencieusement la révision exécutée.
