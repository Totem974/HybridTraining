# Matrice des interactions de l’application d’origine

Les effets « après redémarrage » ont été vérifiés par arrêt forcé lorsque la ligne
l’indique. « Destructif » décrit l’effet visible sur les données fictives.

## Onboarding et planning

| Écran | Contrôle / geste | Précondition et action | Résultat immédiat | Après redémarrage / données | Destructif | Statut | Preuve |
|---|---|---|---|---|---|---|---|
| Introduction | Balayage gauche/droite | Premier lancement, balayer la zone centrale | Aucun changement (`NO_EFFECT_OBSERVED`) | Revient au premier panneau | Non | `OBSERVED` | `S002_intro_panel_2.png`, `S003_intro_panel_3_before_restart.png` |
| Introduction | Commencer | Toucher le bouton | Ouvre les quatre exercices | État incomplet non conservé | Non | `OBSERVED` | `S005_intro_after_commencer.png` |
| Introduction | Sauter pour l’instant | Toucher le lien | Ouvre aussi le parcours de configuration observé | Reprise non distincte observée | Non | `OBSERVED_PARTIALLY` | `S001_initial_launch.png` |
| Exercices | Continuer vide | Quatre champs vides | Aucun message et aucun changement visible | Aucun profil créé | Non | `OBSERVED` | `S008_exercises_empty_continue.png` |
| Exercices | Saisie décimale | Deadlift, 5 reps, saisir `140.5` | Valeur acceptée | Perdue si onboarding non terminé | Non | `OBSERVED` | `S010_deadlift_decimal_five_rep.png` |
| Exercices | kg/lbs | Toucher kg puis revenir | Suffixes mis à jour | Choix incomplet perdu à la relance | Non | `OBSERVED` | `S006_exercises_kg_empty.png` |
| Exercices | Menu rep max | Toucher le sélecteur, choisir 5 reps | Menu 1–10, choix affiché | Conservé dans le parcours courant | Non | `OBSERVED` | `S007_exercise_rep_selector_open.png`, `S009_deadlift_five_rep_selected.png` |
| Plans | Défilement vertical | Balayer jusqu’en bas | Affiche les groupes 2nd Edition et Beyond | Aucun effet de données | Non | `OBSERVED` | `S015_plan_list_bottom.png`, `S016_plan_list_end.png` |
| Plans | Sélection FSL | Toucher Première Série en Dernier | Carte sélectionnée | Choix utilisé pour le cycle final | Non | `OBSERVED` | `S017_plan_fsl_selected.png` |
| Plans | Retour interne | Revenir aux exercices puis avancer | Valeurs retrouvées, avec libellé lbs incohérent dans le récapitulatif | État perdu si l’application est arrêtée avant la fin | Non | `CONTRADICTORY_BEHAVIOR` | `S018_exercises_after_internal_back.png`, `S019_plan_after_forward_again.png` |
| Date | Choisir une date passée | Ouvrir le calendrier, choisir 17/07/2026 | Date passée acceptée | Perdue si parcours abandonné | Non | `OBSERVED` | `S022_program_past_date_selected.png` |
| Date | Toucher hors dialogue | Calendrier ouvert | Ferme le sélecteur sans choix | Valeur antérieure conservée | Non | `OBSERVED` | `date_picker_outside_tap.xml` |
| Date | Retour Android | Parcours incomplet | Quitte l’application | Relance à l’introduction, valeurs perdues | Oui, perte de saisie non finalisée | `OBSERVED` | `S023_plan_after_android_back.png`, `S024_program_date_after_return.png` |
| Fréquence | 3 / 4 jours | Choisir 3 puis 4 | La grille suivante s’adapte | Valeur finale intégrée au cycle | Non | `OBSERVED` | `S029_program_frequency_three_selected.png`, `S030_program_day_selection.png` |
| Jours | Glisser-déposer | Déplacer développé épaule dimanche → mardi | Carte déplacée | Planning final persistant | Non | `OBSERVED` | `S031_program_day_drag_attempt.png` |
| Jours | Dépôt sur jour occupé | Glisser sur lundi déjà occupé | Aucun changement (`NO_EFFECT_OBSERVED`) | Planning précédent conservé | Non | `OBSERVED` | `S032_program_multiple_movements_same_day.png` |
| Prêt | Allons-y | Configuration complète | Crée le cycle et ouvre l’accueil | Cycle retrouvé après arrêt forcé | Création | `OBSERVED` | `S034_home_first_configured.png`, `S035_home_after_configured_restart.png` |

## Accueil, calendrier et cycle

| Écran | Contrôle / geste | Précondition et action | Résultat immédiat | Après redémarrage / données | Destructif | Statut | Preuve |
|---|---|---|---|---|---|---|---|
| Accueil | Défilement vertical | Balayer jusqu’en bas | Affiche cycle et statistiques | Position non vérifiée après relance | Non | `OBSERVED` | `S036_home_bottom_scroll.png` |
| Détail hebdomadaire | Balayage gauche | Lundi sélectionné | Sélectionne mardi | Les données de séance ne changent pas | Non | `OBSERVED` | `S085_schedule_swipe_next_day.png` |
| Détail hebdomadaire | Balayage droit | Mardi sélectionné | Revient à lundi | Aucun effet de données | Non | `OBSERVED` | `S084_schedule_details.png` |
| Calendrier | Toucher un jour de séance | Calendrier ouvert | Aucun écran supplémentaire (`NO_EFFECT_OBSERVED`) | Aucun effet | Non | `OBSERVED` | `S087_calendar_session_day_opened.png` |
| Calendrier | Toucher un jour vide / balayer verticalement | Calendrier ouvert | Aucun effet observé (`NO_EFFECT_OBSERVED`) | Aucun effet | Non | `OBSERVED` | `S088_calendar_scrolled_later.png` |
| Accueil | Modifier | Cycle actif | Ouvre l’éditeur de cycle | Retour sans sauvegarder ne change rien d’observé | Non | `OBSERVED_PARTIALLY` | `S130_cycle_editor.png` |
| Éditeur cycle | Menu Plan | Toucher le plan actif | Liste les treize plans | Aucun changement sans sélection | Non | `OBSERVED` | `S131_cycle_plan_dropdown.png` |
| Éditeur cycle | Retour Android | Menu Plan ouvert | Ferme l’éditeur complet | Cycle inchangé | Non | `OBSERVED` | `S132_fsl_option_dropdown.png` |
| Statistiques | Plus de détails | Cycle partiellement réalisé | Affiche agrégats et message de graphique vide | Compteurs persistants | Non | `OBSERVED` | `S133_stats_before_cycle_completion.png` |

## Séance

| Écran | Contrôle / geste | Précondition et action | Résultat immédiat | Après redémarrage / données | Destructif | Statut | Preuve |
|---|---|---|---|---|---|---|---|
| Détail séance | Changer la date | Menu → Changer la date | Ouvre le calendrier Android | Annulation conserve la date | Non | `OBSERVED_PARTIALLY` | `S090_workout_change_date_dialog.png` |
| Détail séance | Skip | Menu séance planifiée → Skip | Séance grisée/sans bouton Commencer, sans confirmation | État sauté présent tant qu’il n’est pas effacé | Oui, état de séance | `OBSERVED` | `S091_workout_skip_confirmation.png`, `S092_skipped_workout_menu.png` |
| Séance sautée | Effacer le progrès | Menu → Effacer le progrès | Restaure immédiatement la séance | Séance de nouveau disponible | Oui, résultat de séance | `OBSERVED` | `S093_workout_progress_cleared.png` |
| Séance future | Commencer | Toucher Commencer | Dialogue « Changer à aujourd’hui ? » | Aucun changement avant choix | Non | `OBSERVED` | `R002_future_dialog.xml` |
| Dialogue date | Commencer | Choisir Commencer | Démarre sans déplacer la date | Séance active persistante | Création de progression | `OBSERVED` | `R003_first_warmup.xml` |
| Séance active | Succès | Série de chauffe/principale | Marque réussie, lance le repos | Résultat persistant | Écriture | `OBSERVED` | `R004_rest_after_warmup1.xml` |
| Séance active | Échec | Série de chauffe → Échec, choisir 4/5 | Dialogue puis repos | Échec visible dans le détail terminé | Écriture | `OBSERVED` | `S108_failure_reps_four.png`, `S109_rest_after_failure_recorded.png` |
| Séance active | Sauter | Série en cours → Sauter | Passe au repos, compteur décrémenté | Résultat sauté persistant s’il n’est pas annulé | Écriture | `OBSERVED` | `S111_after_set_skipped.png` |
| Repos | Annuler | Série précédente sautée | Rouvre la série et réaugmente le compteur | Annulation persistable | Réversible | `OBSERVED` | `S112_undo_skipped_set.png` |
| Repos | Série suivante | Repos actif | Passe immédiatement à la série suivante | Progression conservée | Non | `OBSERVED` | `R005_warmup2.xml`, `R006_main1.xml` |
| Série max | Succès + 7 reps | Série 5+ | Ouvre saisie, enregistre 7/5+ | Résultat présent après relance | Écriture | `OBSERVED` | `S117_max_reps_dialog.png`, `R014_restart_after_two_sessions.png` |
| Joker | Pass | Proposition à 5 % affichée | Ignore la tentative Joker ; FSL reste suivante | Aucun Joker ajouté dans l’essai contrôlé | Non | `OBSERVED` | `R008_controlled_joker_offer.png`, `R009_after_joker_pass.png` |
| Joker | Attempt | Proposition affichée | Essai initial perturbé par intervention concurrente | Aucun résultat probant | Inconnu | `UNKNOWN` | — |
| AMRAP FSL | Succès + Continuer à 0 | Série FSL | 0 accepté, série cochée, repos | Résultat persistant | Écriture | `OBSERVED` | `R011_fsl_success_dialog.png`, `R013_controlled_completed_detail.png` |
| Séance active | Notes | Ouvrir Notes, saisir `Audit_set_note` | Texte affiché sur la série | Note retrouvée après arrêt forcé | Écriture | `OBSERVED` | `S100_active_set_note_entered.png`, `note-persist.xml` |
| Séance active | Accueil Android puis retour | Séance en cours | Accueil système puis reprise possible | Badge EN COURS et reprise au bon écran | Non | `OBSERVED` | `S101_active_workout_after_restart.png`, `S103_active_workout_resumed_correctly.png` |
| Séance active | Croix rouge | Séries restantes | Ouvre avertissement explicite | Annuler conserve la séance | Potentiellement destructif | `OBSERVED` | `S113_quit_workout_dialog.png` |
| Confirmation abandon | Sauter les séries | Séance fictive contrôlée | Termine et revient au détail ; assistance restante non cochée | Badge COMPLÉTÉ persiste | Oui, clôture la séance | `OBSERVED` | `R013_controlled_completed_detail.png`, `R014_restart_after_two_sessions.png` |
| Détail terminé | Modifier les résultats | Menu → Modifier les résultats | Valeurs et états éditables | Sauvegarde non exécutée | Potentiellement destructif | `OBSERVED_PARTIALLY` | `S126_modify_results.png` |

## Réglages et données

| Écran | Contrôle / geste | Précondition et action | Résultat immédiat | Après redémarrage / données | Destructif | Statut | Preuve |
|---|---|---|---|---|---|---|---|
| Réglages | Auto-série suivante | Activer puis relancer | Interrupteur activé | Activé après relance, puis rétabli à faux | Non | `OBSERVED` | `S054_settings_auto_next_enabled.png`, `S055_settings_auto_next_after_restart.png` |
| Réglages | Durée de repos | 3:00 → 0:15 | Valeur affichée immédiatement | 0:15 après relance, puis rétablie à 3:00 | Non | `OBSERVED` | `S056_settings_rest_changed.png`, `S057_settings_rest_after_restart.png` |
| Plaques | Ajouter une paire 50 kg | Ensemble `Audit_Set` | Charge maximale recalculée | Ensemble persistant | Écriture | `OBSERVED` | `S065_plate_set_pair_added.png`, `S066_plate_set_saved_settings.png` |
| Plaques | Réorganiser | Déplacer `Audit_Set` en premier | Devient « Par Défaut », arrondis des séances changent | Ordre persistant ; ensemble principal restauré ensuite | Écriture à effet global | `OBSERVED` | `S069_plate_sets_reordered.png`, `S079_home_after_test_settings_restored.png` |
| Barre | Créer `Audit_Bar` 15,5 kg | Nouvelle Barre | Barre et affectations visibles | Persistante ; affectations retirées ensuite | Écriture | `OBSERVED` | `S070_new_bar_form.png`, `S072_audit_bar_weight_saved.png` |
| Progression | Saisir 7,5 | Succès haut du corps | Valeur enregistrée comme 7 | Persiste après relance, puis restaurée à 5 kg | Écriture | `OBSERVED` | `S073_progression_upper_success_modified.png`, `S074_progression_modified_after_restart.png` |
| Localisation | kg → lbs | Unité kg active | Libellés et arrondis changent sans conversion cohérente | Comportement persistant ; retour kg restaure les valeurs | Écriture globale | `CONTRADICTORY_BEHAVIOR` | `S080_settings_units_lbs_selected.png`, `S082_home_display_lbs_after_restart.png` |
| Localisation | Dim. → Lun. | Premier jour dimanche | Calendrier devient L M M J V S D | Persiste après relance ; dimanche restauré | Écriture | `OBSERVED` | `S137_monday_first_day_persisted.png`, `S138_sunday_restored.xml` |
| Export | Exporter puis Retour | Données fictives présentes | Ouvre sharesheet avec `fiveThreeOne.json`, Retour annule | Aucun changement des données | Non | `OBSERVED` | `S042_export_file_picker.png` |
| Export | Partager vers Termux | Sharesheet ouverte | Fichier annoncé comme enregistré dans Termux | Contenu inaccessible par ADB autorisé | Création de fichier externe | `OBSERVED_PARTIALLY` | `S045_export_termux_receiver.png`, `S046_export_termux_saved.png` |
| Import | Retour Android | Sélecteur ouvert | Annule et revient aux réglages | Données existantes conservées | Non | `OBSERVED` | `import_cancelled_settings.xml` |
| Import | JSON invalide | Choisir `HTAudit_invalid.json` | Retour silencieux aux réglages | Cycles existants visibles ensuite | Potentiellement destructif | `OBSERVED` | `S050_import_invalid_result.png` |
| Import | JSON vide | Choisir un fichier de 0 octet | Retour silencieux aux réglages | Cycles existants conservés | Potentiellement destructif | `OBSERVED` | `S051_import_empty_result.png`, `V002_import_empty.mp4` |
| Import | Mauvaise extension | Sélecteur ouvert avec `.txt` synthétique sur Download | `.txt` absent de la liste, JSON visibles | Aucun import | Non | `OBSERVED` | `S140_import_picker.png` |
| Réglages | Restaurer les achats | Toucher le bouton | Aucun message visible dans la fenêtre d’observation | État des achats inchangé visiblement | Non | `OBSERVED_PARTIALLY` | `S052_restore_purchases_result.png` |
| Suppression | Supprimer | Toucher dans Réglages | Ouvre dialogue irréversible | Aucun changement avant confirmation | Potentiellement destructif | `OBSERVED` | `S141_delete_all_confirmation.png` |
| Suppression | Annuler | Dialogue ouvert | Revient aux réglages | Deux séances terminées toujours présentes après relance | Non | `OBSERVED` | `S142_delete_cancel_preserves.xml` |
| Suppression | Confirmer | Dialogue ouvert | Non exécuté sur téléphone physique sans autorisation destructive explicite | Effet réel inconnu | Oui | `BLOCKED_SAFETY` | `S141_delete_all_confirmation.png` |
