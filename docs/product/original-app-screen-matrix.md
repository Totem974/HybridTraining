# Matrice black-box des écrans de l’application d’origine

Source exclusive des comportements : application Android d’origine 2.6.1 observée
sur Redmi Note 7 le 18 juillet 2026. Les identifiants ci-dessous sont propres à
l’audit et ne proviennent pas de l’application.

## Introduction et configuration

| ID | Nom observé | État requis et chemin d’entrée | Éléments, défilement et gestes | Champs et validations | Sorties, retour et persistance | Statut | Preuve |
|---|---|---|---|---|---|---|---|
| `OA-APP-001` | Lancement | Application arrêtée → icône Five/Three/One | Aucun splash distinct suffisamment long pour être caractérisé | Aucun | Vers introduction si aucun cycle, sinon accueil | `OBSERVED_PARTIALLY` | `V001_initial_launch.mp4` |
| `OA-ONB-001` | Cinq/Trois/Un | Premier lancement | Texte d’introduction, 5 points, « Commencer », « Sauter pour l’instant » ; balayages gauche/droite sans effet | Aucun | « Commencer » → charges ; retour Android quitte ; relance revient au premier panneau | `OBSERVED` | `S001_initial_launch.png`, `S004_intro_after_midway_restart.png` |
| `OA-ONB-002` | Exercices | Introduction → Commencer | Liste verticale : Deadlift, Squat, Bench Press, Overhead Press ; kg/lbs | Charge décimale et sélecteur rep max ; vide : Continuer sans effet visible | Retour → introduction ; état incomplet perdu après relance | `OBSERVED` | `S006_exercises_kg_empty.png`, `S011_exercises_filled_kg.png` |
| `OA-ONB-003` | Sélecteur de rep max | Toucher « Max 1 rep » d’un mouvement | Menu superposé : Max 1 rep à 10 reps | Une option requise par mouvement ; sélection immédiate | Choix ferme le menu | `OBSERVED` | `S007_exercise_rep_selector_open.png` |
| `OA-ONB-004` | Plans | Charges complètes → Continuer | Liste verticale complète, deux groupes éditoriaux, badges Recommended | Sélection d’une carte ; aucun paywall avec les achats restaurés | Continuer → date ; retour → charges ; choix conservé pendant le parcours | `OBSERVED` | `S015_plan_list_bottom.png`, `S017_plan_fsl_selected.png` |
| `OA-ONB-005` | Date de début | Plan sélectionné → Continuer | Date, raccourcis Aujourd’hui/Demain/dimanche | Date passée acceptée ; valeur par défaut : lendemain | Continuer → fréquence ; retour Android peut quitter l’onboarding et perdre l’état incomplet | `OBSERVED` | `S020_after_plan_continue.png`, `S022_program_past_date_selected.png` |
| `OA-SYS-001` | Sélecteur de date Android | Toucher la date | Calendrier système ; toucher hors zone ferme | Date passée, présente ou future visible | Annuler/toucher hors zone revient sans changement | `OBSERVED` | `S021_program_date_picker_open.png` |
| `OA-ONB-006` | Fréquence | Date → Continuer | Choix 3 ou 4 jours pour First Set Last | Un seul choix, 4 par défaut | Continuer → jours ; retour → date | `OBSERVED` | `S029_program_frequency_three_selected.png` |
| `OA-ONB-007` | Jours et mouvements | Fréquence → Continuer | Grille hebdomadaire et cartes mouvement ; glisser-déposer | À 4 jours : quatre affectations ; dépôt sur jour occupé sans effet | Continuer → prêt ; retour → fréquence ; affectations persistantes jusqu’à la fin du parcours | `OBSERVED` | `S030_program_day_selection.png`, `S031_program_day_drag_attempt.png` |
| `OA-ONB-008` | Tout est prêt ! | Jours → Continuer | Récapitulatif et deux cartes de livres « Acheter » | Aucun champ | « Allons-y » crée le cycle ; cycle persistant après relance | `OBSERVED` | `S033_onboarding_after_days.png`, `S034_home_first_configured.png` |

## Accueil, calendrier et cycle

| ID | Nom observé | État requis et chemin d’entrée | Éléments, défilement et gestes | Champs et validations | Sorties, retour et persistance | Statut | Preuve |
|---|---|---|---|---|---|---|---|
| `OA-HOME-001` | Cinq/Trois/Un | Cycle configuré → lancement | En-tête, réglages, restant cette semaine, semaine prochaine, cycle en cours, progrès et stats ; défilement vertical | Aucun | Cartes séance, deux « Plus de détails », Modifier, Réglages ; état persiste | `OBSERVED` | `S034_home_first_configured.png`, `S036_home_bottom_scroll.png` |
| `OA-HOME-002` | Détail hebdomadaire | Accueil → Plus de détails (planning) | Sept jours, carrousel de séances ; balayage gauche/droite entre jours | Cases non modifiables avant démarrage | Retour interne → accueil ; jour sélectionné après retour non vérifié | `OBSERVED` | `S084_schedule_details.png`, `S085_schedule_swipe_next_day.png` |
| `OA-HOME-003` | Calendrier du cycle | Détail hebdomadaire → icône calendrier | Juillet-août, jours avec séances ; toucher jour avec/sans séance et balayage vertical sans effet observé | Aucun | Retour → détail hebdomadaire | `OBSERVED` | `S086_schedule_calendar_picker.png`, `S088_calendar_scrolled_later.png` |
| `OA-CYCLE-001` | Modifier Cycle | Accueil → Modifier ou menu séance → Modifier le cycle | Onglets Max 1 Rép./Charge Ent./Série 1+, plan, Joker, option FSL, assistance ; vertical | Quatre charges, plan, interrupteur Joker, option AMRAP ; sauvegarde par icône disquette | Croix/retour Android ferme sans sauvegarder ; impact des modifications non testé | `OBSERVED_PARTIALLY` | `S130_cycle_editor.png` |
| `OA-CYCLE-002` | Menu Plan | Éditeur de cycle → Plan | Menu vertical des treize plans | Sélection possible mais non exécutée sur cycle existant | Retour Android a fermé l’éditeur complet | `OBSERVED_PARTIALLY` | `S131_cycle_plan_dropdown.png` |
| `OA-STATS-001` | Progrès & Statistiques | Accueil → Plus de détails (stats) | Graphique vide avant cycle complet, onglets 5+/3+/1+/CE, cycle courant, agrégats | Aucun champ | Retour Android a quitté l’application depuis cet écran ; statistiques persistantes | `OBSERVED` | `S133_stats_before_cycle_completion.png` |

## Séances

| ID | Nom observé | État requis et chemin d’entrée | Éléments, défilement et gestes | Champs et validations | Sorties, retour et persistance | Statut | Preuve |
|---|---|---|---|---|---|---|---|
| `OA-WRK-001` | Détail de séance | Accueil/carte ou détail hebdomadaire | Échauffement, principales, Joker, FSL, assistance ; vertical | Cases de résultats non tactiles avant démarrage | Commencer → confirmation éventuelle puis séance ; menu contextuel | `OBSERVED` | `S084_schedule_details.png` |
| `OA-WRK-002` | Menu de séance planifiée | Détail → trois points | Feuille inférieure : Changer la date, Skip, Modify cycle | Aucun | Toucher hors/retour ferme ; Skip agit immédiatement | `OBSERVED` | `S089_workout_overflow_menu.png` |
| `OA-WRK-003` | Changer la date | Menu → Changer la date | Sélecteur Android | Date modifiable | Annuler préserve ; déplacement réel non exécuté | `OBSERVED_PARTIALLY` | `S090_workout_change_date_dialog.png` |
| `OA-WRK-004` | Menu de séance sautée/terminée | Après Skip ou séance terminée → trois points | Effacer le progrès, Changer la date, Modifier les résultats, Modifier le cycle | Aucun | Effacer le progrès agit immédiatement et restaure la séance | `OBSERVED` | `S092_skipped_workout_menu.png`, `S093_workout_progress_cleared.png` |
| `OA-WRK-005` | Changer à aujourd’hui ? | Commencer une séance future | Dialogue : Commencer / Changer la date | Aucun | Commencer garde la date planifiée ; Changer la date non confirmé | `OBSERVED` | `S096_active_workout_initial.png`, `R002_future_dialog.xml` |
| `OA-WRK-006` | Séance en cours | Démarrer une séance | Chronomètre total, carte courante, plaques, barre, séries restantes, succès/échec/saut/notes ; vertical | Résultat de série et notes | Retour conserve la séance ; badge EN COURS et reprise après relance | `OBSERVED` | `S097_active_workout_started.png`, `S103_active_workout_resumed_correctly.png` |
| `OA-WRK-007` | Notes | Séance active → Notes | Feuille inférieure, ensemble de plaques, barre, zone texte | Texte libre ; note enregistrée automatiquement | Retour ferme ; note persistante après arrêt forcé | `OBSERVED` | `S099_active_set_notes_panel.png`, `S100_active_set_note_entered.png` |
| `OA-WRK-008` | Repos | Valider/échouer/sauter une série | Compte à rebours, Annuler, Série suivante, Sauter, Notes | Durée issue des réglages | Annuler rouvre la série précédente ; Série suivante avance | `OBSERVED` | `S105_rest_timer_after_success.png`, `S112_undo_skipped_set.png` |
| `OA-WRK-009` | Répétitions après échec | Série active → Échec | Dialogue +/- et Continuer | Valeur initiale prescrite ; 4/5 testé | Continuer enregistre l’échec et démarre le repos | `OBSERVED` | `S107_rest_after_failure.png`, `S108_failure_reps_four.png` |
| `OA-WRK-010` | Répétitions série max | Série 5+ → Succès | Dialogue +/- et Continuer | Minimum visible égal à la prescription ; 7/5 testé | Continuer → proposition Joker | `OBSERVED` | `S117_max_reps_dialog.png`, `R008_controlled_joker_offer.png` |
| `OA-WRK-011` | Séries Joker | Après série maximale | Proposition 5 %, 10 % ou 1 rép. ; Pass / Attempt | Choix d’incrément | Pass ignore la proposition et laisse FSL suivante ; Attempt non retesté de façon probante | `OBSERVED_PARTIALLY` | `R008_controlled_joker_offer.png`, `R009_after_joker_pass.png` |
| `OA-WRK-012` | Répétitions AMRAP FSL | FSL → Succès | Dialogue +/- et Continuer | Valeur initiale 0 ; 0 accepté | Continuer coche la série et démarre le repos | `OBSERVED` | `R011_fsl_success_dialog.png`, `R013_controlled_completed_detail.png` |
| `OA-WRK-013` | Sauter les séries restantes ? | Séance active → croix rouge | Dialogue d’avertissement, Annuler, Sauter les séries | Aucun | Annuler reprend ; confirmer termine avec les blocs restants non cochés | `OBSERVED` | `S113_quit_workout_dialog.png`, `R013_controlled_completed_detail.png` |
| `OA-WRK-014` | Détail terminé | Fin de séance | Résultats par série, réussite/échec/saut, notes, assistance | Chaque résultat devient éditable via le menu | Retour → accueil ; badges et données persistent | `OBSERVED` | `R013_controlled_completed_detail.png`, `R014_restart_after_two_sessions.png` |
| `OA-WRK-015` | Modifier les résultats | Détail terminé → menu → Modifier les résultats | Liste verticale, Terminer | Répétitions et états modifiables, dont AMRAP 0 | Retour sans modification préserve ; sauvegarde réelle non testée | `OBSERVED_PARTIALLY` | `S126_modify_results.png` |

## Réglages et surfaces système

| ID | Nom observé | État requis et chemin d’entrée | Éléments, défilement et gestes | Champs et validations | Sorties, retour et persistance | Statut | Preuve |
|---|---|---|---|---|---|---|---|
| `OA-SET-001` | Réglages | Accueil → engrenage | Long défilement : repos, plaques/barres, progression, localisation, pourboires, données, achats | Interrupteurs, valeurs, unités, premier jour | Auto-enregistrement ; changements vérifiés après relance | `OBSERVED` | `S037_settings_top.png`, `S041_settings_absolute_end.png` |
| `OA-SET-002` | Durée de repos | Réglages → une durée | Roues minutes/secondes par pas de 5 s | 0:15 testé ; sauvegarde immédiate | Fermer revient aux réglages ; persiste après relance | `OBSERVED` | `S053_rest_duration_selector.png`, `S057_settings_rest_after_restart.png` |
| `OA-SET-003` | Nouvel/éditer ensemble | Réglages → Nouvel Ensemble / ensemble existant | Nom, quantités de 50 à 0,125, +/- et charge maximale | Nom requis probable ; paire 50 kg testée | Sauvegarde → réglages ; données persistantes | `OBSERVED` | `S058_new_plate_set_dialog.png`, `S067_edit_plate_set.png` |
| `OA-SET-004` | Réorganiser les ensembles | Réglages → Réorganiser | Poignées de glisser-déposer | Ordre modifiable | Premier ensemble devient « Par Défaut » et influence l’arrondi | `OBSERVED` | `S068_reorder_plate_sets.png`, `S069_plate_sets_reordered.png` |
| `OA-SET-005` | Nouvelle barre | Réglages → Nouvelle Barre | Nom, poids décimal, interrupteurs par mouvement | 15,5 kg testé | Sauvegarde → réglages ; persiste | `OBSERVED` | `S070_new_bar_form.png`, `S072_audit_bar_weight_saved.png` |
| `OA-SYS-002` | Partage Android de l’export | Réglages → Exporter | Sharesheet Android, nom proposé `fiveThreeOne.json` | Aucune validation applicative visible | Retour annule ; partage vers Termux réussi | `OBSERVED_PARTIALLY` | `S042_export_file_picker.png`, `S046_export_termux_saved.png` |
| `OA-SYS-003` | Sélecteur Android d’import | Réglages → Importer | DocumentsUI, JSON récents ; `.txt` synthétique absent | Fichier vide/invalide sélectionnable s’il est JSON | Retour annule ; invalides reviennent silencieusement aux réglages | `OBSERVED` | `S048_import_file_picker.png`, `S140_import_picker.png` |
| `OA-SET-006` | Supprimer tous vos cycles ? | Réglages → Supprimer | Dialogue : avertissement irréversible, Annuler, Supprimer | Pas de ressaisie | Annuler conserve les cycles après relance ; confirmation non exécutée | `OBSERVED_PARTIALLY` | `S141_delete_all_confirmation.png`, `S142_delete_cancel_preserves.xml` |

## Écrans recherchés et non trouvés

| Fonction recherchée | Périmètre parcouru | Statut |
|---|---|---|
| Profil ou compte | Accueil, réglages, onboarding | `NOT_FOUND_AFTER_SYSTEMATIC_SEARCH` |
| Bibliothèque distincte et fiche programme | Catalogue onboarding, éditeur de cycle, réglages | `NOT_FOUND_AFTER_SYSTEMATIC_SEARCH` |
| RPE | Séance active, dialogues de résultats, modification des résultats | `NOT_FOUND_AFTER_SYSTEMATIC_SEARCH` |
| Historique autonome et records autonomes | Accueil, statistiques, détail terminé | `NOT_FOUND_AFTER_SYSTEMATIC_SEARCH` |
| Langue, thème, vibration, aide, confidentialité, licences, version | Réglages parcourus jusqu’à la fin | `NOT_FOUND_AFTER_SYSTEMATIC_SEARCH` |
| Refaire l’introduction, reset onboarding ou reset profil | Réglages et menus | `NOT_FOUND_AFTER_SYSTEMATIC_SEARCH` |
| Arrêter/terminer le cycle, nouveau cycle manuel | Accueil, éditeur, menus de séance | `NOT_FOUND_AFTER_SYSTEMATIC_SEARCH` |
| Fin naturelle de cycle | Interface atteignable pendant le lot | `BLOCKED_BY_TIME` |
