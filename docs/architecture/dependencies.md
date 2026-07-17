# Dépendances

Les versions exactes seront verrouillées dans `pubspec.lock` après génération avec
le SDK Flutter installé. Aucune version n'est inventée tant que la résolution réelle
n'a pas été exécutée.

## Choix prévus

| Dépendance | Rôle | Justification |
| --- | --- | --- |
| Flutter SDK | Interface et services Android/iOS | Plateforme demandée pour le produit. |
| `flutter_riverpod` | État et injection | Contrôleurs explicites, remplaçables dans les tests, sans conteneur DI supplémentaire. |
| `go_router` | Navigation déclarative | Routes et redirections testables adaptées à l'onboarding et au programme actif. |
| `drift` | SQLite typé et migrations | Requêtes typées, transactions et stratégie de migration vérifiable. |
| `sqlite3_flutter_libs` | Moteur SQLite mobile | Fournit SQLite aux plateformes Flutter prises en charge par Drift. |
| `path_provider` | Emplacement de la base et des exports | Évite les chemins locaux codés en dur. |
| `json_annotation` et `json_serializable` | JSON fortement typé | Contrats versionnés et erreurs de décodage explicites. |
| `build_runner` | Génération contrôlée | Génère les adaptateurs Drift et JSON de façon reproductible. |
| `intl` et `flutter_localizations` | Français, anglais et formats locaux | Outils officiels de localisation Flutter. |

## Dépendances volontairement évitées au départ

- framework d'architecture global ;
- service locator en plus du conteneur d'état ;
- client HTTP, authentification ou SDK cloud ;
- Firebase, analytics, publicité ou suivi ;
- bibliothèque de graphiques avant la tranche qui en a réellement besoin ;
- bibliothèque d'achat ou paywall ;
- package interne séparé pour chaque couche.

Chaque ajout futur doit documenter son besoin, sa maintenance, sa licence, son
impact plateforme et l'alternative standard qui a été écartée.
