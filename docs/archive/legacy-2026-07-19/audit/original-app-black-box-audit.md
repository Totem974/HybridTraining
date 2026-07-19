# Audit black-box de l’application Android d’origine

## Portée et règle de preuve

Cet audit décrit uniquement ce qui a été visible par interaction normale avec
l’application Android d’origine. Aucun APK n’a été décompilé, aucune base interne
n’a été lue et aucun asset n’a été copié. L’arbre d’accessibilité Android a servi
uniquement à relever les libellés affichés et les zones tactiles.

Les règles d’entraînement ne sont pas déduites de cette application. Elles restent
subordonnées aux spécifications validées de `docs/program-specifications/`.

Statuts employés : `OBSERVED`, `OBSERVED_PARTIALLY`,
`NOT_FOUND_AFTER_SYSTEMATIC_SEARCH`, `BLOCKED_PAYWALL`, `BLOCKED_ACCOUNT`,
`BLOCKED_NETWORK`, `BLOCKED_SAFETY`, `BLOCKED_BY_TIME`, `BLOCKED_TECHNICAL`,
`UNKNOWN` et `CONTRADICTORY_BEHAVIOR`.

## Environnement

| Élément | Valeur observée |
|---|---|
| Appareil | Xiaomi Redmi Note 7 (`aosp_lavender`) |
| Nature de l’appareil | Téléphone physique déclaré réinitialisé et données de test jetables |
| Android | Android 13, API 33 |
| Écran | 1080 × 2340, densité 420 dpi |
| Locale | `fr-FR` |
| Connectivité pendant l’audit | Aucune connexion utile requise ; partage vers PC bloqué car appareils déconnectés |
| Application visible | Five/Three/One, titre interne « Cinq/Trois/Un » |
| Package Android | `dev.strongpigeon.fivethreeone` |
| Activité lancée | `.MainActivity` |
| Version | 2.6.1 |
| Build | 118 |
| SDK cible indiqué par Android | 33 |
| Dossier de preuves | `D:\HybridTrainingAudit\original-app\2026-07-18_01` |

L’application était déjà installée et tous les achats intégrés étaient disponibles.
Aucun contournement de paiement n’a été nécessaire ni tenté.

## Méthode

L’exploration a suivi un graphe d’états : premier lancement, onboarding incomplet,
cycle configuré, séance partielle, séance terminée et réglages modifiés. Pour les
états importants, l’application a été forcée à l’arrêt puis relancée. Les zones
verticales et horizontales visibles ont été parcourues, les dialogues annulés puis
rouverts, et les valeurs temporaires ont été rétablies lorsque cela était possible.

Toutes les données saisies sont fictives : 140 kg au soulevé de terre, 120 kg au
squat, 80 kg au développé couché et 50 kg au développé épaule. Les noms techniques
`Audit_Set`, `Audit_Bar` et `Audit_set_note` signalent clairement des données de test.

Une intervention humaine concurrente a perturbé une première fin de séance. Les
captures `S115` à `S126` ne sont donc pas utilisées pour conclure sur l’ordre des
blocs. Le segment a été refait sans intervention, sous les identifiants `R001` à
`R014`; ces preuves contrôlées font foi.

## Parcours exécutés

### Onboarding

- premier lancement, fermeture intermédiaire et reprise ;
- bouton « Commencer », bouton « Sauter pour l’instant » et retour ;
- saisie des quatre charges, décimale au point, kg/lb et rep max de 1 à 10 ;
- validation vide, retour depuis le catalogue et perte de l’onboarding incomplet ;
- catalogue complet des treize plans visibles ;
- date passée, aujourd’hui, demain et sélecteur Android ;
- fréquences 3 et 4 jours pour First Set Last ;
- glisser-déposer des mouvements et tentative sur un jour occupé ;
- écran final puis persistance du cycle après redémarrage.

### Accueil, calendrier et cycle

- accueil en haut et en bas, séance future et séance terminée ;
- détail hebdomadaire, balayage entre jours dans les deux sens ;
- calendrier complet du cycle ;
- menus de séance : changer la date, sauter, effacer le progrès, modifier les
  résultats et modifier le cycle ;
- éditeur de cycle et menu des treize plans ;
- statistiques avant la fin du premier cycle.

### Séance contrôlée

- préparation, démarrage anticipé et confirmation de conservation de la date ;
- échauffement, réussite, échec avec 4/5 répétitions, saut et annulation du saut ;
- série maximale 5+ enregistrée à 7 répétitions ;
- proposition de séries Joker et action « Pass » contrôlée ;
- First Set Last AMRAP enregistré à 0 répétition ;
- notes persistantes, minuteur de repos, reprise de séance après redémarrage ;
- dialogue de fin anticipée, annulation puis confirmation sur une séance fictive ;
- détail terminé et modification des résultats ;
- persistance des badges « COMPLÉTÉ » après arrêt forcé.

### Réglages et données

- quatre durées de repos, trois interrupteurs, progression, unités et premier jour ;
- création, modification et réorganisation d’un ensemble de plaques ;
- création d’une barre et affectation temporaire à des mouvements ;
- passage kg/lb et retour au réglage initial ;
- export, annulation du partage et partage vers Termux ;
- import annulé, JSON invalide, JSON vide et filtrage du fichier `.txt` ;
- dialogue de suppression globale, annulation et vérification après redémarrage ;
- restauration des achats, sans retour visible.

## Résultats majeurs

1. L’application est utilisable sans compte et ses parcours centraux restent
   accessibles hors ligne.
2. L’onboarding incomplet n’est pas repris : une relance revient à l’introduction
   et perd les charges saisies. Un cycle finalisé, lui, persiste.
3. Le catalogue observé mélange des plans de « 5/3/1 2nd Edition » et de
   « Beyond 5/3/1 ». Cette taxonomie visible n’est pas une preuve de règles Forever.
4. First Set Last propose seulement 3 ou 4 jours. L’affectation par défaut à 4
   jours était dimanche développé épaule, lundi soulevé de terre, mercredi
   développé couché et vendredi squat ; le glisser-déposer est effectif.
5. Une séance comprend échauffement, séries principales, séries Joker optionnelles,
   un bloc First Set Last, assistance, notes et repos.
6. L’action « Pass » du panneau Joker ignore la tentative proposée et laisse le
   First Set Last comme prochaine série. Ce résultat a été revérifié de manière
   contrôlée.
7. Un AMRAP First Set Last accepte 0 répétition et apparaît coché dans le détail
   terminé.
8. « Sauter » une séance depuis son menu et « Effacer le progrès » agissent
   immédiatement, sans dialogue de confirmation observé. En revanche, terminer une
   séance active avec des séries restantes demande une confirmation.
9. Les statistiques agrégées apparaissent avant la fin du cycle, mais le graphique
   de progression demande au moins un cycle complet.
10. Le premier jour de semaine est appliqué au calendrier et persiste après
    redémarrage.

## Comportements inattendus ou contradictoires

| Observation | Statut | Conséquence documentaire |
|---|---|---|
| Le récapitulatif des charges de l’onboarding a affiché « lbs » après une saisie configurée en kg. | `CONTRADICTORY_BEHAVIOR` | Ne pas reproduire ce libellé erroné. |
| Basculer de kg vers lbs a changé l’arrondi et le libellé sans conversion de masse cohérente (107,5 affiché 110, par exemple), puis le retour kg a restauré les valeurs. | `CONTRADICTORY_BEHAVIOR` | Séparer stockage canonique, conversion et arrondi dans la reconstruction. |
| Un changement de progression de 7,5 a été enregistré comme 7. | `OBSERVED` | Le contrôle visible semble entier malgré un clavier permettant une décimale. |
| Importer un JSON vide ou manifestement invalide a ramené silencieusement aux réglages. | `OBSERVED` | Absence de rapport d’erreur visible ; amélioration recommandée. |
| « Restaurer les achats » n’a produit aucun retour visible dans la fenêtre d’observation. | `OBSERVED_PARTIALLY` | Le traitement interne et le résultat réseau restent inconnus. |

Le saut de plusieurs blocs lors du premier essai de séance n’est pas attribué à
l’application : l’utilisateur a signalé avoir touché l’écran en parallèle. Il est
donc exclu des comportements inattendus.

## Limites et fonctions bloquées

| Sujet | Statut | Limite exacte |
|---|---|---|
| Fin naturelle du cycle et génération du cycle suivant | `BLOCKED_BY_TIME` | Le cycle couvre juillet-août et aucune modification interne des dates n’était autorisée. |
| Export lisible et réimport du même export | `BLOCKED_TECHNICAL` | Le partage a enregistré `fiveThreeOne.json` dans l’espace privé Termux, inaccessible par ADB sans contourner la sandbox Android. |
| Partage vers le PC | `BLOCKED_NETWORK` | Les deux cibles « Lien avec Windows » étaient déconnectées. |
| Confirmation de « Supprimer tous vos cycles » | `BLOCKED_SAFETY` | Téléphone physique : le dialogue a été observé et annulé ; aucune confirmation destructive explicite du propriétaire n’a été fournie pendant l’action. |
| Import après effacement, double import et remplacement de données existantes | `BLOCKED_SAFETY` | Dépend de l’effacement réel et d’un export récupérable. |
| Notifications Android effectives | `OBSERVED_PARTIALLY` | Réglage de fin de repos observé ; aucun déclenchement système fiable n’a été attendu. |
| Verrouillage/déverrouillage pendant le repos et rotation | `UNKNOWN` | Non validés de façon probante dans ce lot. |
| Contenu du fichier exporté | `BLOCKED_TECHNICAL` | Aucun fichier normal de l’application n’a été lu depuis son espace privé. |

## Fonctions recherchées mais non trouvées

Après parcours complet des réglages, de l’accueil, du calendrier, des menus de
séance et de l’éditeur de cycle : profil utilisateur, compte, écran de bibliothèque
distinct, fiche détaillée de programme, saisie RPE, records distincts, langue,
thème, vibration, aide, confidentialité, licences, version, refaire l’introduction,
réinitialiser uniquement l’onboarding, réinitialiser le profil, arrêter le cycle,
nouveau cycle manuel et supprimer seulement l’historique sont
`NOT_FOUND_AFTER_SYSTEMATIC_SEARCH`.

## Index des preuves locales

Les fichiers restent hors du dépôt. La date de toutes les preuves ci-dessous est
le 18 juillet 2026 et l’appareil est le Redmi Note 7 décrit plus haut.

| ID | Fichier | Écran/état | Action |
|---|---|---|---|
| `E001` | `S001_initial_launch.png` | Introduction initiale | Premier lancement |
| `E002` | `S006_exercises_kg_empty.png` | Charges vides en kg | Continuer depuis l’introduction |
| `E003` | `S007_exercise_rep_selector_open.png` | Sélecteur de rep max | Ouvrir la liste 1–10 reps |
| `E004` | `S010_deadlift_decimal_five_rep.png` | Valeur décimale | Saisir 140.5 |
| `E005` | `S015_plan_list_bottom.png` | Catalogue des plans | Défiler vers Beyond |
| `E006` | `S021_program_date_picker_open.png` | Sélecteur de date | Ouvrir le calendrier Android |
| `E007` | `S030_program_day_selection.png` | Affectation hebdomadaire | Afficher les quatre mouvements |
| `E008` | `S031_program_day_drag_attempt.png` | Planning modifié | Glisser le développé épaule |
| `E009` | `S034_home_first_configured.png` | Accueil configuré | Finir l’onboarding |
| `E010` | `S035_home_after_configured_restart.png` | Accueil persistant | Arrêt forcé et relance |
| `E011` | `S037_settings_top.png` | Réglages, haut | Ouvrir les réglages |
| `E012` | `S039_settings_bottom.png` | Réglages, données | Défiler vers export/import/suppression |
| `E013` | `S053_rest_duration_selector.png` | Sélecteur de repos | Modifier la durée |
| `E014` | `S058_new_plate_set_dialog.png` | Ensemble de plaques | Créer un ensemble fictif |
| `E015` | `S070_new_bar_form.png` | Barre | Créer une barre fictive |
| `E016` | `S080_settings_units_lbs_selected.png` | Unité lbs | Basculer depuis kg |
| `E017` | `S081_home_display_lbs.png` | Accueil en lbs | Observer l’arrondi sans conversion cohérente |
| `E018` | `S084_schedule_details.png` | Détail hebdomadaire | Ouvrir « Plus de détails » |
| `E019` | `S086_schedule_calendar_picker.png` | Calendrier du cycle | Ouvrir l’icône calendrier |
| `E020` | `S089_workout_overflow_menu.png` | Menu de séance | Ouvrir le menu contextuel |
| `E021` | `S097_active_workout_started.png` | Séance active | Démarrer une séance future |
| `E022` | `S107_rest_after_failure.png` | Dialogue de répétitions | Marquer une série en échec |
| `E023` | `S112_undo_skipped_set.png` | Série restaurée | Annuler un saut |
| `E024` | `S113_quit_workout_dialog.png` | Confirmation de fin anticipée | Toucher la croix rouge |
| `E025` | `R008_controlled_joker_offer.png` | Séries Joker contrôlées | Enregistrer 7 répétitions sur 5+ |
| `E026` | `R009_after_joker_pass.png` | FSL encore à venir | Choisir « Pass » |
| `E027` | `R011_fsl_success_dialog.png` | AMRAP à 0 | Valider l’AMRAP FSL |
| `E028` | `R013_controlled_completed_detail.png` | Détail terminé contrôlé | Sauter les séries d’assistance restantes |
| `E029` | `R014_restart_after_two_sessions.png` | Deux séances persistantes | Arrêt forcé et relance |
| `E030` | `S130_cycle_editor.png` | Éditeur de cycle | Ouvrir « Modifier » |
| `E031` | `S131_cycle_plan_dropdown.png` | Liste des plans | Ouvrir le menu du plan |
| `E032` | `S133_stats_before_cycle_completion.png` | Statistiques | Ouvrir « Plus de détails » |
| `E033` | `S137_monday_first_day_persisted.png` | Semaine commençant lundi | Modifier puis redémarrer |
| `E034` | `S042_export_file_picker.png` | Partage d’export | Lancer « Exporter » |
| `E035` | `S048_import_file_picker.png` | Sélecteur d’import | Lancer « Importer » |
| `E036` | `S051_import_empty_result.png` | Import vide | Sélectionner un JSON de 0 octet |
| `E037` | `S140_import_picker.png` | Filtrage MIME | Vérifier les JSON visibles et le `.txt` absent |
| `E038` | `S141_delete_all_confirmation.png` | Confirmation destructive | Ouvrir puis annuler la suppression |
| `E039` | `S142_delete_cancel_preserves.xml` | Données préservées | Relancer après annulation |
| `E040` | `V001_initial_launch.mp4` | Lancement | Enregistrement court |
| `E041` | `V002_import_empty.mp4` | Import vide | Enregistrement court |

## Intégrité du dépôt

Aucune preuve, vidéo, export ou donnée de test n’est ajoutée à Git. Aucun fichier
Flutter n’est modifié par ce lot. Les seules écritures prévues sont les documents
d’audit et les liens demandés dans la matrice de référence.
