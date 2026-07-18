# Domaine de programmes composable

Le domaine v2 se trouve sous `lib/features/programs/domain/v2`. Il sépare les concepts historiques, leurs révisions et les blueprints exécutables. Un blueprint compose des policies versionnées, des blocs ordonnés, des transitions, des capacités et des contraintes; aucune règle numérique provenant d'un ouvrage n'est encodée dans un enum.

Les identifiants sont des types valeur stables. La sérialisation reste dans `program_domain_serializer.dart`. Le validateur agrège les erreurs de structure et de disponibilité avant qu'un blueprint atteigne un générateur.

Le v1 demeure inchangé. `ProgramV1Adapter` traduit explicitement son catalogue vers le v2 et conserve `forever-original-fsl-v1`. La lecture `ProgramDefinitionRef.fromJson`, l'alias `classic` et le schéma SQLite v1 restent donc compatibles.

Ce lot modélise les séquences et plusieurs mouvements principaux par séance, mais ne génère pas encore de macrocycle et n'ajoute aucun programme ou écran.
