# Rapport — domaine de programmes composable

Date : 2026-07-18

Le noyau v2 introduit une composition immutable de concepts, révisions, blueprints, policies, blocs, transitions, contraintes, références et statuts. Le validateur couvre les identifiants dupliqués, références absentes, versions et policies manquantes, transitions et ordres invalides, 7th Week sans objectif, règles non vérifiées, fréquences incompatibles et générateurs absents.

La compatibilité est assurée par un adapter v1 vers v2. Aucune interface, migration SQLite, règle chiffrée issue d'un livre ou génération réelle de macrocycle n'a été ajoutée.

Les tests Dart couvrent les compositions demandées, le partage de concept, l'adapter, les identifiants et l'absence d'import Flutter dans le v2.
