# Écarts entre l’application d’origine et la reconstruction Flutter

Cette analyse compare l’application Android d’origine observée à l’état du dépôt au
18 juillet 2026. Elle ne transforme jamais le comportement d’origine en règle
Forever. Les décisions proposées doivent être validées avant implémentation.

## Synthèse

La reconstruction possède déjà un socle local SQLite, un onboarding, un cycle de
trois semaines, une séance guidée, l’historique, un import transactionnel et des
tests. Elle diverge toutefois fortement sur la structure du parcours, la navigation,
la composition des séances et la gestion des réglages. Plusieurs écrans Flutter
(profil, navigation basse, bibliothèque documentaire) n’existent pas dans
l’application d’origine, tandis que l’original possède calendrier, échauffement,
Joker, assistance et inventaire de matériel absents ou partiels dans le POC.

## Matrice fonctionnelle

| Fonction | Application d’origine observée | Reconstruction Flutter actuelle | Écart et risque | Décision proposée |
|---|---|---|---|---|
| Lancement | Pas de splash distinct caractérisé ; introduction ou accueil | État loading avec indicateur Flutter | Écart visuel faible ; ne pas copier l’identité originale | `REPRODUCE_WITH_IMPROVEMENT` |
| Introduction | Écran unique, 5 points, Commencer et Sauter | Parcours Flutter 1/6 avec identité HYBRID | Progression et textes différents ; source prototype déjà validée séparément | `OWNER_DECISION_REQUIRED` |
| Profil/nickname | Aucun profil ou nom demandé | Nom obligatoire, profil et initiales dans un onglet dédié | Donnée et écran ajoutés sans équivalent original | `OWNER_DECISION_REQUIRED` |
| Ordre de l’onboarding | Intro → charges → plan → date → fréquence → jours → prêt | Intro → programme → planning → charges → validation → plan | Parité comportementale faible et risque d’incompréhension | `REPRODUCE_WITH_IMPROVEMENT` |
| Reprise onboarding | Tout parcours incomplet est perdu à la relance | Contrôleur ne persiste qu’après création finale, comportement proche | Perte silencieuse dans les deux cas ; amélioration souhaitable | `REPRODUCE_WITH_IMPROVEMENT` |
| Charges initiales | Quatre mouvements, 1–10 rep max, point décimal, kg/lbs | 1RM positif seulement, nom requis, kg/lb | Estimation rep max absente ; ordre des mouvements différent | `REPRODUCE_WITH_IMPROVEMENT` |
| Unité par défaut | lbs observé malgré locale française | kg par défaut | Décision produit, pas règle métier | `OWNER_DECISION_REQUIRED` |
| Conversion kg/lbs | Libellé/arrondi incohérent, sans conversion de masse fiable | L’unité est stockée avec la saisie, aucune bascule UI fonctionnelle | Reproduire l’erreur ferait perdre le sens des données | `DROP` |
| Catalogue onboarding | Treize plans visibles, regroupés 2nd Edition/Beyond | Un seul Original + FSL activable, Full Body désactivé | Catalogue original n’est pas une source Forever ; activation prématurée risquée | `NEEDS_DOMAIN_REVIEW` |
| Bibliothèque | Aucun écran autonome trouvé ; catalogue dans onboarding/éditeur | Bibliothèque Forever/Beyond/Classic et fiches documentaires | Écran Flutter intentionnel, sans équivalent original | `DEFER` |
| Date de début | Raccourcis, date passée acceptée, lendemain par défaut | Date du jour par défaut, plage -1 jour à +365 | Différence de défaut et plage ; date passée demande décision | `OWNER_DECISION_REQUIRED` |
| Fréquences | FSL : 3 ou 4 jours ; 2 jours visible pour un autre plan | 3 ou 4 jours | Compatible pour FSL, mais 2 jours futur dépend du programme | `REPRODUCE` |
| Affectation des jours | Grille réelle et glisser-déposer des mouvements | Offsets fixes `[0,1,3,5]` ou `[0,2,4]`, ordre enum squat/bench/deadlift/OHP | Le planning utilisateur n’est pas représenté | `REPRODUCE_WITH_IMPROVEMENT` |
| Accueil | Pas de navigation basse ; engrenage, cartes de semaine, cycle et stats | Navigation basse à cinq entrées, prochaine séance, cycle et historique | Architecture et hiérarchie différentes ; prototype a validé une direction propre | `OWNER_DECISION_REQUIRED` |
| Notifications | Interrupteur fin de repos dans Réglages | Icône/panneau vide et réglage « bientôt » | La reconstruction expose une destination sans comportement | `DEFER` |
| Calendrier hebdomadaire | Carrousel par jours et calendrier complet du cycle | Aucune vue calendrier | Navigation temporelle centrale manquante | `REPRODUCE_WITH_IMPROVEMENT` |
| Détail de séance | Échauffement, principales, Joker, FSL, assistance | Principales et supplemental seulement | Composition très incomplète | `NEEDS_DOMAIN_REVIEW` |
| Échauffement | Trois séries visibles et exécutables | Absent du modèle `SetKind` | Fonction d’usage manquante ; pourcentages à vérifier dans les sources métier | `NEEDS_DOMAIN_REVIEW` |
| Séries principales | Ordre visible 5+/3+/1+ dans le cycle audité | Moteur : semaine 1 en 3+, semaine 2 sans performance, semaine 3 en 5/3/1+ | Divergence majeure ; l’original n’est pas une autorité Forever | `NEEDS_DOMAIN_REVIEW` |
| First Set Last | Une série AMRAP dans le plan observé | Cinq séries de 5 à la charge FSL | Divergence substantielle de template, nom identique trompeur | `NEEDS_DOMAIN_REVIEW` |
| Séries Joker | Proposition dynamique après top set, 5/10 % ou 1 rep, Pass/Attempt | Absentes | Fonction Beyond/classique possible ; ne pas ajouter sans validation documentaire | `NEEDS_DOMAIN_REVIEW` |
| Assistance | Deux exercices, chacun 5 séries, éditables via cycle | Absente du modèle et de la séance Flutter | Fonction d’usage manquante, mais prescriptions non copiables | `NEEDS_DOMAIN_REVIEW` |
| Résultat succès/échec/saut | Trois actions, répétitions après échec, annulation depuis repos | Trois résultats persistés ; compteur et récapitulatif | Couverture proche ; UX différente | `REPRODUCE_WITH_IMPROVEMENT` |
| AMRAP | Dialogue après action ; top set minimum prescrit, FSL initialisé à 0 | Compteur intégré à la carte et initialisé aux reps prescrites | AMRAP 0 non naturel pour le FSL actuel ; validation à clarifier | `REPRODUCE_WITH_IMPROVEMENT` |
| RPE | Introuvable | Absent | Aucun écart confirmé | `DROP` |
| Repos | Quatre durées configurables, auto-next, notification et cloche | Durée fixe 180 s, persistance de `restUntil`, bouton passer | Paramétrage et comportements automatiques absents | `REPRODUCE_WITH_IMPROVEMENT` |
| Reprise de séance | Badge EN COURS, reprise après arrêt forcé | `startedAt`, `restUntil` et résultats persistés, mais l’accueil ouvre la prochaine séance | Socle présent ; découverte/reprise UI à vérifier | `REPRODUCE_WITH_IMPROVEMENT` |
| Notes | Feuille par série avec plaques/barre, sauvegarde automatique | Champ notes de séance avec debounce | Granularité différente ; risque de perdre le lien à la série | `OWNER_DECISION_REQUIRED` |
| Abandon séance | Croix rouge, confirmation, séries restantes non cochées, badge COMPLÉTÉ | Pas de dialogue global ; terminer seulement quand toutes les séries sont traitées | Fonction manquante, sémantique « terminé » discutable | `REPRODUCE_WITH_IMPROVEMENT` |
| Sauter une séance | Action immédiate sans confirmation ; Effacer le progrès immédiat | Pas de menu de séance ni report/saut global | Fonction de planning manquante ; confirmation souhaitable | `REPRODUCE_WITH_IMPROVEMENT` |
| Modifier résultats | Éditeur complet après séance | Aucun détail historique éditable | Correction postérieure absente ; fort impact sur records | `REPRODUCE_WITH_IMPROVEMENT` |
| Historique | Détails terminés accessibles via calendrier ; pas d’onglet autonome trouvé | Liste historique autonome simple | Flutter apporte une vue utile mais sans détail | `REPRODUCE_WITH_IMPROVEMENT` |
| Statistiques | Agrégats détaillés avant fin de cycle, graphique après cycle complet | Deux compteurs et texte « à venir » | Parité très partielle | `DEFER` |
| Progression | Succès haut/bas en kg ou %, échec en %, auto-enregistré | Mise à jour manuelle des quatre TM, séances futures recalculées | Modèle de progression différent ; validation métier nécessaire | `NEEDS_DOMAIN_REVIEW` |
| Éditeur de cycle | 1RM/TM/1+, plan, Joker, FSL, assistance | Ajustement de TM seulement ; sauvegarde explicite | Surface Flutter beaucoup plus étroite | `NEEDS_DOMAIN_REVIEW` |
| Plaques et barres | CRUD, poids décimal, inventaire, affectation par mouvement, ordre par défaut | Calculateur avec inventaire et barre codés en dur | Domaine partiel présent, UI/persistance absentes | `REPRODUCE_WITH_IMPROVEMENT` |
| Premier jour semaine | Lun./Sam./Dim., effet immédiat et persistant | Absent | Format calendrier futur incomplet | `REPRODUCE` |
| Export | Sharesheet Android, fichier `fiveThreeOne.json` | Dialogue contenant le JSON et copie presse-papiers | Pas de fichier natif ; risque UX et exposition de JSON | `REPRODUCE_WITH_IMPROVEMENT` |
| Import | Sélecteur de fichier JSON, erreurs invalides silencieuses | Coller JSON, simulation obligatoire, rapport, application atomique | Reconstruction plus sûre mais moins native | `REPRODUCE_WITH_IMPROVEMENT` |
| Suppression | Dialogue « tous vos cycles », portée réelle non confirmée | Efface profil, cycles, séances et records, revient à onboarding | Portées potentiellement différentes ; action Flutter plus large | `OWNER_DECISION_REQUIRED` |
| Refaire introduction | Introuvable | Introuvable | Critère de l’audit non satisfait par l’original, besoin produit séparé | `OWNER_DECISION_REQUIRED` |
| Compte / cloud | Aucun compte requis, parcours hors ligne | Local SQLite, aucun compte/cloud | Aligné avec l’objectif local-first | `REPRODUCE` |
| Localisation | Interface française, unité indépendante ; aucun sélecteur de langue | Chaînes FR/EN en classe Dart, mais instance française fixe et pas d’ARB | Internationalisation technique incomplète | `REPRODUCE_WITH_IMPROVEMENT` |

## Risques prioritaires

1. **Identité du template** : `forever-original-fsl-v1` génère actuellement cinq
   séries de 5 FSL, alors que l’application d’origine observée nomme FSL une série
   AMRAP. Ni l’un ni l’autre ne doit être arbitré sans les spécifications Forever.
2. **Ordre des semaines** : la reconstruction et l’original divergent. Le domaine
   doit être revu contre les sources validées, pas contre les captures.
3. **Unités** : l’erreur de conversion de l’original ne doit jamais être reproduite.
4. **Suppression** : le libellé original parle des cycles ; la reconstruction efface
   aussi le profil. La portée cible exige une décision propriétaire explicite.
5. **Navigation** : la navigation basse et le profil de la reconstruction sont des
   choix du prototype, non des comportements de l’original. Les sources doivent
   rester nommées séparément dans les tickets futurs.

## Décisions requises avant le lot suivant

- ordre cible de l’onboarding et présence d’un pseudonyme local ;
- unité par défaut et politique exacte de conversion ;
- planning libre par jours ou offsets fixes ;
- définition documentaire exacte du template par défaut ;
- statut des Joker et de l’assistance dans le premier lot fonctionnel ;
- granularité des notes (séance ou série) ;
- sens de « séance terminée » après saut du reste ;
- portée exacte de Supprimer, Arrêter le cycle et Refaire l’introduction ;
- maintien de la navigation basse issue du prototype malgré son absence dans
  l’application d’origine.
