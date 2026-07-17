# Dépendances

Versions résolues le 17 juillet 2026 avec Flutter 3.44.6 et Dart 3.12.2.
`pubspec.lock` verrouille les versions transitives exactes.

| Dépendance directe | Version | Portée | Justification |
|---|---:|---|---|
| Flutter SDK | 3.44.6 | application | UI Android/iOS et outils officiels |
| `cupertino_icons` | 1.0.8 | application | icônes Flutter générées avec le projet ; utilisation limitée |
| `sqflite` | 2.4.3 | application | SQLite Android/iOS, transactions et migrations sans générateur supplémentaire |
| `flutter_lints` | 6.0.0 | développement | règles statiques officielles Flutter |
| `sqflite_common_ffi` | 2.4.2 | tests | base SQLite réelle sous Windows pour tester schéma et réouverture |
| `integration_test` | SDK Flutter | tests | parcours réel sur Android fourni par Flutter |

## Choix d'architecture associés

- L'état Base0 repose sur un `ChangeNotifier` injecté : aucun package de gestion
  d'état n'est encore nécessaire.
- La navigation Base0 n'a que deux états racine et deux onglets : aucun routeur
  externe n'est justifié à ce stade.
- Les contrats JSON sont petits et validés explicitement : pas de génération de
  code avant que le format historique soit connu.
- `sqflite` a été préféré à un ORM pour garder la première migration lisible et
  limiter les dépendances. Les accès restent derrière `TrainingStore`.

## Dépendances volontairement absentes

- réseau, compte, cloud, Firebase, analytics, publicité ;
- achat ou paywall ;
- service locator ou conteneur d'injection ;
- graphique, notifications et tâches d'arrière-plan avant leur tranche dédiée ;
- bibliothèque de navigation avant que le graphe d'écrans le nécessite.

Chaque ajout futur doit documenter besoin, maintenance, licence, impact plateforme
et alternative standard écartée.
