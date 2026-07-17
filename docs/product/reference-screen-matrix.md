# Matrice des écrans de référence

## Direction UI validée par le propriétaire

Le prototype local `.SOURCE/GUI Amélioration app 531` définit désormais la
direction visuelle du POC : fond `#0B0B0C`, surfaces `#171716`, identité orange
`#F5821F`, actions validantes vertes `#3ECB6A` et navigation basse à cinq
entrées. Le thème, l'accueil, la séance, les statistiques, le profil, les
réglages, l'historique et la bibliothèque informative suivent cette direction.
La modification complète du cycle reste progressive tant que ses écritures
métier ne sont pas disponibles.

Le parcours d'introduction suit six panneaux : introduction, programme,
planning, charges, validation et plan final. La date et la fréquence choisies
alimentent réellement les dates des séances générées.

Les captures locales regroupent un générateur web, des maquettes et une application
Android observée. Elles guident le comportement seulement : aucun code, logo,
illustration ou police n'est repris. `UNKNOWN` évite d'inventer un état absent.

| ID | Écran et source | Entrée ; actions et champs | Validations, états et sorties | Ancien accès | Base0 / différence intentionnelle |
|---|---|---|---|---|---|
| `splash` | Splash ; `2026-07-15 132917`, `204913` | lancement ; aucune saisie | attente puis onboarding/accueil ; erreurs non observées | UNKNOWN | non implémenté ; démarrage Flutter neutre |
| `onboarding_intro` | Introduction ; `112427`, `132917` | premier lancement ; commencer/passer | pagination visible ; vide/erreur non observés ; vers planning | UNKNOWN | simplifié vers profil ; aucun texte tiers repris |
| `onboarding_schedule` | Planning ; `132917`, `204913` | onboarding ; date, 2/3/4 séances, jours/mouvements | sélection requise probable ; vers max | UNKNOWN | backlog ; Base0 génère 4 jours séquentiels |
| `onboarding_maxes` | Charges maximum ; `111901`, `132917` | onboarding ; quatre charges, reps/1RM, kg/lb | valeurs positives ; vers validation | UNKNOWN | implémenté : 1RM positif et kg/lb ; estimation UI à venir |
| `onboarding_review` | Validation des max ; `111901`, `132917` | après saisie ; revoir/continuer | quatre valeurs ; retour ou programme | UNKNOWN | non séparé ; validation dans le formulaire |
| `program_recommendation` | Choix de génération ; `111901`, `113214`, `145705` | onboarding ; famille ou objectif | maquettes divergentes ; vers proposition | UNKNOWN | un seul modèle vérifié, affiché explicitement |
| `program_proposal` | Proposition ; `132917`, `145705` | après sélection ; commencer/changer | carte récapitulative ; vers accueil/bibliothèque | UNKNOWN | intégré à la création du cycle |
| `program_library` | Bibliothèque ; `145705`, `204913` | navigation ; onglets, cartes, détail | liste/fiche ; vide/erreur non observés | gratuit/payant non déterminable | documentation seulement ; pas de faux catalogue actif |
| `cycle_editor` | Modification cycle ; `204913` | programme actif ; max, reps, ratio, variante, deload | sauvegarde visible ; erreur non observée ; retour accueil | UNKNOWN | backlog ; modèle Base0 immuable après création |
| `dashboard` | Tableau de bord ; `112546`, `145705` | profil configuré ; prochaine séance, TM, progrès | vide après cycle possible ; vers séance/historique/réglages | UNKNOWN | remplacé par deux onglets simples et originaux |
| `workout_detail` | Détail du jour ; `204913` | tableau de bord ; séries et assistance | cases à faire ; vers exécution | UNKNOWN | implémenté sous forme de liste de séries |
| `workout_active` | Séance en cours ; `202849` | détail ; chrono, série, plaques, reps | actif/suivant ; vers résultat/notes | UNKNOWN | partiel : validation d'une série, sans chrono/plaques |
| `set_actions` | Actions série ; `202917`, `202950`, `202959` | série active ; succès, échec, saut, notes | états réussi/échoué/sauté ; vers suivante | UNKNOWN | succès implémenté ; échec/saut/notes au backlog |
| `amrap_result` | Résultat AMRAP ; `203013` | série `+` ; nombre de reps | entier non négatif ; vers suivante | UNKNOWN | moteur marque PR set ; saisie libre UI à venir |
| `workout_abandon` | Saut du reste ; `204049` | séance active ; annuler/confirmer | confirmation destructive ; retour | UNKNOWN | non implémenté ; aucune fin silencieuse permise |
| `history` | Historique, déduit du tableau de bord et des maquettes | onglet ; séances terminées | état vide explicite ; détail futur | UNKNOWN | liste persistante implémentée |

## Composants et règles transverses

| Composant | États observés | Décision Base0 |
|---|---|---|
| unité | métrique, impérial | modèle et stockage kg/lb |
| progression onboarding | passée, active, future | backlog après stabilisation du parcours |
| carte mouvement | ID, nom, charge, reps, unité | IDs stables, traductions séparées |
| série | à faire, active, réussie, échouée, sautée | à faire/réussie livrés ; autres au backlog |
| notes | panneau de série | stockage prévu, UI au backlog |
| plaques | répartition visuelle | calcul de domaine livré, UI au backlog |
| navigation basse | accueil, suivi, ajout, profil, réglages | non reprise avant définition des écrans |

## Générateur web du 13 juillet

Il expose des paramètres pour Boring But Big, Triumvirate, Periodization Bible,
Bodyweight, Simplest Strength, Full Body, First Set Last, GVT et autres. Il sert à
repérer le vocabulaire. Ses calculs ne sont jamais une source métier sans
recoupement avec les livres.

## Divergences encore `NEEDS_REVIEW`

- onboarding par famille, objectif ou recommandation directe ;
- accès gratuit ou payant de chaque ancien écran ;
- couleurs d'accent variables entre vert, rouge et orange ;
- calendrier exact et comportement de report ;
- disponibilité précise des programmes par édition.

Les dates, noms et charges des captures ne sont jamais utilisés comme fixtures.
