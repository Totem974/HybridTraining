# Inventaire comportemental de la source d’inspiration

## Objet et méthode

Ce document inventorie les comportements observables de la page de calcul servant de référence. Il ne constitue ni une spécification d’entraînement indépendante, ni une autorisation de copier son moteur, sa marque, ses actifs ou son code. Les futures implémentations doivent rester pilotées par le catalogue et le moteur Dart de HybridTraining.

Sources inspectées en lecture seule le 22 juillet 2026 :

- `D:/GitHub/scraper/output/fivethreeone.app.tar`, capture réseau datée du 22 juillet 2026, avec miroir et reconstruction lisible des composants ;
- `D:/GitHub/HybridTraining/.cleanup-backup/.SOURCE/sitecalculator.tar`, miroir HTTrack antérieur contenant les bundles de la même application ;
- miroir décompressé sous `docs/sources-local/legacy-oracles/sitecalculator/` ;
- captures sous `docs/sources-local/legacy-oracles/.SCREENSHOT/` et `.CODEX-CAPTURES/` ;
- maquettes HTML locales sous `docs/sources-local/legacy-oracles/GUI Amélioration app 531/`.

Le premier fichier est l’autorité principale pour les valeurs et conditions ci-dessous. Le second confirme l’origine des bundles, tandis que les captures et miroirs confirment la présence et la disposition des contrôles, sans suffire à prouver seuls leur effet métier.

Niveaux de preuve : **observé** signifie explicitement présent dans la reconstruction ; **déduit** signifie conséquence directe de plusieurs branches observées ; **à confirmer** signale une ambiguïté à couvrir par oracle avant toute implémentation.

## État initial observé

| Domaine | Défaut de la source | Effet observable |
|---|---|---|
| Template | `Boring But Big`, variante `Original (5x10)` | Cinq séries de dix sur le même mouvement, ratio commun initial de 30 % |
| Charges principales | 67,5 / 90 / 135 / 180 lb dans l’ordre interne OP/BP/SQ/DL | Entrées servant de TM à la génération source |
| Fréquence | 4 jours | Ordre OP, DL, BP, SQ |
| Ordre de travail | normal | Les séries montent ; `Bastard work order` est désactivé |
| Ordre des semaines | 5/3/1 | `3/5/1 week order` est désactivé |
| Warm-up | Original | 40 % × 5, 50 % × 5, 60 % × 3 |
| Joker | désactivé | `jokerMax = 0`, aucune série Joker |
| Deload | Deload 1 activé | 40/50/60 % × 5/5/5 ; warm-up de deload sauté par défaut |
| Plaques | lb, barre 45 lb | Inventaire source prérempli ; kg disponible avec barre 20 kg |
| Output | titre vide, QR actif, plating actif | La génération est recalculée à chaque changement |

## Matrice exhaustive des templates exposés

| Template canonique source | Variantes / sous-options | Défaut source | Fréquence autorisée | Impact attendu observé |
|---|---|---|---|---|
| **Boring But Big** | Original (5×10), Less Boring, 5×5, 5×3, 5×1, Beyond Variation 1, Beyond Variation 2, 2 Days/Week ; ratio 30–75 % par pas de 5, commun ou par mouvement, seulement pour Original/Less Boring ; supplément de deload : aucun, 5×10, 3×10 ou 5×5 à 50 % | Original, 30 % commun, aucun BBB pendant deload | 3 ou 4 ; variante 2 Days/Week verrouillée à 2 | Ajoute cinq séries supplémentaires. Original = même mouvement ; Less Boring et 2 Days = mouvement croisé. 5×5/3/1 utilisent respectivement 80/90/100 %. Beyond V1 = 5×10 à 65/70/75 % ; V2 = 5×10, 5×8, 5×5 à 65/70/75 %. La variante 2 jours progresse 50/60/70 %. Ajoute aussi cinq séries d’assistance spécifiques. |
| **Triumvirate** | aucune configuration propre | — | 3 ou 4 | Après le travail principal, deux exercices d’assistance, chacun sur cinq séries ; répétitions spécifiques au mouvement (ex. 15/10, 12/15). |
| **Periodization Bible** | aucune configuration propre | — | 3 ou 4 | Après le travail principal, trois exercices d’assistance, cinq séries chacun, avec répétitions spécifiques au mouvement. |
| **Bodyweight** | total 75–150 répétitions, pas 5 ; 1–10 séries | 75 répétitions, 5 séries | 3 ou 4 | Répartit le total entre le nombre de séries choisi, pour deux exercices d’assistance associés au mouvement ; la répartition arrondit les séries puis affecte le reliquat. |
| **Simplest Strength** | TM séparés pour close-grip bench, incline press, front squat et straight-leg deadlift | 93 / 116,25 / 139,5 / 162,75 | 3 ou 4 | Ajoute trois séries chargées de l’exercice secondaire avec ratios/répétitions dépendant de la semaine, puis trois séries de 12 sur chaque assistance associée. |
| **For Beginners** | `Intermediate` oui/non | non | 3 verrouillés | Ordre SQ, DL+OP, BP. Ajoute un second mouvement principal à 55/65/75 % ou, en Intermediate, 45/55/65 %, trois séries de cinq ; ajoute trois séries de dix d’assistance. DL inclut aussi le travail 5/3/1 d’OP. |
| **Full Body** | Original : Phase One/Two/Three ; Updated : choix de séries Squat ; Full Boring : choix séparé Squat/Bench/Deadlift | Original, Phase One | 3 verrouillés | Voir section détaillée : le template remplace la génération standard de séance et change l’ordre/topologie, pas seulement l’assistance. |
| **2 Days/Week** | Option One, Two, Three ; Option Three ajoute `Second Lift Sets` parmi 65/75/85×3, 70/80/90×3, 75×5/85×3/95×1, 80/90/100×1 | Option One, premier profil | 2 verrouillés | Option 1 groupe DL+OP et SQ+BP dans deux séances. Option 2 fait tourner les quatre mouvements sur deux jours. Option 3 ajoute un second mouvement chargé avant/après le principal selon la séance. Chaque option possède son plan d’assistance. |
| **Pyramid** | aucune configuration propre | — | 3 ou 4 | Après le travail principal, redescend avec deux séries : semaines 5/3/1 = 75/65×5, 80/70×3, 85×3 puis 75×5 ; la dernière est marquée plus set. Rien au deload. |
| **First Set Last** | AMRAP ou Multiple Sets ; si Multiple Sets : 3–5 séries et 3–8 reps | AMRAP ; valeurs mémorisées 3×5 | 3 ou 4 | Utilise le premier pourcentage de la semaine (65/70/75 %) après le principal. AMRAP produit une série ; Multiple Sets produit le nombre de séries/répétitions choisi. Rien au deload. |
| **GVT** | Alternate exercise oui/non ; ratio 30–75 % par pas de 5, commun ou par mouvement | non, 30 % commun | 2, 3 ou 4 | Dix séries de dix au ratio choisi, sur le mouvement principal ou son mouvement croisé ; pas de charge GVT au deload, mais assistance conservée. |
| **5’s Progression** | aucune configuration propre | — | 3 ou 4 | Remplace les reps principales par 5/5/5 aux ratios 5/3/1 normaux. Warm-up, Joker, ordre inversé et deload global restent applicables. |
| **BBB Challenge** | Six Weeks, Three Months, Thirteen Weeks ; `Less boring` oui/non | Six Weeks, Less boring activé | 4 verrouillés | Plusieurs sous-cycles avec hausse automatique du TM entre sous-cycles. Six semaines : 2 sous-cycles ; trois mois : 3 ; treize semaines : 4. Les ratios progressent jusqu’à 100 % et la variante 13 semaines réduit ensuite les reps à 5, 3 puis 1. Les deloads apparaissent seulement après certains sous-cycles. |

## Full Body — conditions et effets précis

Full Body est une famille à traiter comme une topologie de programme, pas comme une option cosmétique.

### Original

- Trois jours verrouillés, ordre SQ, BP, DL+OP.
- `Phase One` : 40/50/60 % × 5/5/5.
- `Phase Two` : 65/75/85 % × 3/3/3.
- `Phase Three` : 75/85/95 % × 3/3/1.
- Sur les jours autres que Squat et hors deload, trois séries de Squat précèdent le travail principal.
- Le jour Deadlift inclut aussi le travail 5/3/1 d’Overhead Press.
- Assistance observée : BP reçoit trois séries de dix de pull-up ; SQ reçoit trois séries de dix de dumbbell bench et de dumbbell row ; la séance groupée DL+OP n’ajoute pas cette assistance.

### Updated

- Trois jours et ordre identiques à Original.
- Seul `Squat Sets` est configurable avec quatre profils : 65/75/85 × 5 ; 70/80/90 × 3 ; 75×5/85×3/95×1 ; 80/90/100 × 1.
- Particularité observée : le premier profil Deadlift est affiché et généré en 3/3/3, pas 5/5/5.
- Le reste de la topologie Original demeure.

### Full Boring

- Trois jours verrouillés, ordre SQ, BP, DL ; plus de token DL+OP.
- Trois profils séparés, un pour Squat, Bench et Deadlift, parmi les quatre profils ci-dessus.
- À chaque séance, le mouvement du jour utilise son travail 5/3/1 complet ; les deux autres mouvements reçoivent chacun trois séries selon leur profil.
- L’assistance Full Body standard est supprimée.
- **À confirmer par oracle** : l’indexation historique des ratios dans la reconstruction est compacte et mérite un golden par combinaison avant transposition de contrat.

## Options transversales sensibles

### Warm-up Original

Valeur interne observée `0`, défaut actif. Produit exactement trois séries par mouvement :

1. 40 % du TM × 5 ;
2. 50 % du TM × 5 ;
3. 60 % du TM × 3.

Les charges sont arrondies et les plaques sont calculées par le moteur source. Ces calculs ne doivent pas être recréés dans le Web TypeScript.

### Warm-up Beyond 5/3/1

Valeur interne observée `1`. Son activation révèle deux champs conditionnels : `Upper Body Base Weight` et `Lower Body Base Weight`, défauts respectifs 95 et 135 dans l’unité initiale lb.

Comportement observé :

- commence par une série de 10 à charge nulle/barre ;
- ajoute une série de 5 à la charge de base haut ou bas ;
- monte ensuite par incréments de 10 % du TM jusqu’à la première série de travail ;
- utilise 5 reps jusqu’à 50 % du TM, puis 3 reps au-dessus ;
- le nombre de séries est donc dynamique et dépend du TM, de la base, de la première charge de travail et de l’arrondi.

Condition UI : les charges de base n’apparaissent que pour Beyond. Impact attendu : changement du nombre et des charges de warm-up, jamais simple changement de libellé.

### Joker Sets : +5 à +30 %

Le switch est désactivé par défaut (`jokerMax = 0`). Lorsqu’il est activé, `Up to` propose : +5, +10, +15, +20, +25 ou +30 %.

La valeur représente un **plafond cumulatif en pas de 5 %**, et non une unique série au pourcentage choisi :

- +5 % → 1 Joker ;
- +10 % → 2 Jokers ;
- … ;
- +30 % → 6 Jokers.

Chaque Joker part de la série principale la plus lourde de la semaine et ajoute `5 % du TM × rang`. Les reps sont identifiées comme Joker par la source. Joker est aussi appliqué à 5’s Progression. Il n’est pas ajouté par le chemin deload.

### Deload global

`Deload After Cycle` mappe l’absence à `-1`. Dans l’état initial observé, le deload est actif sur Deload 1 et `Skip Warmup` est actif.

| Choix | Séries de deload observées | Warm-up conditionnel |
|---|---|---|
| Deload 1 | 40/50/60 % × 5/5/5 | `Skip Warmup` visible |
| Deload 2 | 50/60/70 % × 5/5/5 | visible |
| Deload 3 | 65/76/85 % × 3/3/3 | visible ; noter 76 %, valeur littérale observée |
| Deload 4 | 40/50/60 % × 10/8/6 | visible |
| Deload 5 | 50/60/70 % × 10/8/6 | visible |
| High Intensity | barre/0 × 10, charge de base × 5, montée de 10 % du TM, puis TM × 1 | `Skip Warmup` masqué ; chemin dédié |

Pour Deload 1–5, décocher `Skip Warmup` préfixe le deload par le warm-up global choisi, calculé jusqu’à sa première charge. High Intensity ignore ce switch et utilise ses propres bases fixes observées : 95/135 lb ou 45/60 kg, puis 3 reps jusqu’à 80 % du TM et 1 rep au-dessus, avec une dernière répétition à 100 % du TM.

Le switch Deload conditionne aussi le sous-choix BBB de travail supplémentaire pendant la semaine de deload. Aucun contrôle sans effet ne doit être présenté si le catalogue/moteur ne porte pas ces variantes.

## Planification et conditions communes

- Horaire par défaut des templates ordinaires : 3 ou 4 jours, ordre OP/DL/BP/SQ.
- Une seule fréquence autorisée est affichée comme valeur fixe ; plusieurs valeurs utilisent un toggle.
- Beginners : 3 jours, SQ / DL+OP / BP.
- Full Body Original/Updated : 3 jours, SQ / BP / DL+OP.
- Full Body Full Boring : 3 jours, SQ / BP / DL.
- 2 Days/Week Option One : 2 jours, DL+OP / SQ+BP.
- 2 Days/Week Options Two/Three : 2 jours, rotation OP/DL/BP/SQ.
- BBB 2 Days/Week : 2 jours, rotation des quatre mouvements.
- BBB Challenge : 4 jours.
- GVT : 2, 3 ou 4 jours.
- `Bastard work order` inverse l’ordre des trois séries principales, sans changer leurs identités.
- `3/5/1 week order` permute les deux premières semaines en 3/5/1. BBB Challenge conserve sa progression interne malgré cet affichage réordonné.
- Avec quatre tokens mais 3 ou 2 jours, la source déroule la rotation sur les semaines et groupe certains mouvements pendant le deload. Ce comportement doit être représenté par le schedule résolu, pas reproduit par le front.

## Interactions et invariants à couvrir par oracles

1. Chaque template et chacune de ses variantes doivent produire un snapshot distinct lorsque leur effet métier diffère.
2. Full Body doit avoir au minimum un oracle par variante, par phase Original et par profil extrême ; Full Boring nécessite des profils de mouvements différents.
3. Warm-up Beyond doit être testé avec bases haut/bas différentes et un TM qui change le nombre de paliers.
4. Joker doit être testé à +5 et +30 pour prouver respectivement 1 et 6 séries, ainsi qu’avec `Bastard work order` et 5’s Progression.
5. Deload doit couvrir les six choix, `Skip Warmup` vrai/faux pour Deload 1–5, et l’absence complète de deload.
6. BBB doit couvrir ses huit variantes, ses ratios communs/différenciés, ses quatre choix de supplément au deload et la condition « deload global actif ».
7. Les schedules à 2/3 jours doivent vérifier l’ordre et les groupes SQ+BP / DL+OP sans exposer les identifiants internes.
8. `3/5/1` doit être testé séparément sur un cycle ordinaire et BBB Challenge.
9. Les valeurs historiques littérales surprenantes — notamment 76 % dans Deload 3 — ne doivent être « corrigées » sans décision de catalogue documentée.
10. Les contrôles absents du contrat HybridTraining doivent rester invisibles jusqu’à ce que le catalogue et le moteur les supportent réellement.

## Écarts de portée et prudences

- La source expose des recettes et comportements que le catalogue HybridTraining actuel peut classer comme documentation seulement. Leur présence dans cet inventaire ne signifie pas qu’elles sont exécutables aujourd’hui.
- Les noms visibles de la source sont des libellés de référence. Les identités canoniques HybridTraining doivent rester les IDs versionnés du catalogue.
- La reconstruction rend les branches lisibles, mais n’est pas un oracle suffisant pour les erreurs historiques, l’arrondi, le plating ou les combinaisons extrêmes. Les sorties gelées natives restent l’autorité de migration.
- Le miroir `sitecalculator.tar` contient surtout les bundles minifiés et confirme la même application, mais n’ajoute pas de contrat métier plus fiable que la capture reconstruite récente.
- Les captures locales valident principalement la hiérarchie et l’apparition conditionnelle des contrôles ; elles ne prouvent pas à elles seules les valeurs générées.
