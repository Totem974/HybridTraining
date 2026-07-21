# AGENTS.md — HybridTraining

## 1. Objectif produit

HybridTraining est une application locale de programmation et de suivi d'entraînement.

La chaîne métier unique est :

```text
catalogue publié
+ choix utilisateur
+ 1RM / rep-max / Training Max
+ ratio de Training Max
+ planning
+ matériel
+ assistance / conditioning
= cycle généré
```

Puis :

```text
définition Forever
→ configurations de cycles
→ même générateur de cycle
→ macrocycle fini
```

L'interface ne contient aucune règle d'entraînement. Elle affiche les choix autorisés par le catalogue, construit une demande validée, lance la génération et permet ensuite d'exécuter les séances.

## 2. Priorité absolue

L'ordre de travail est obligatoire :

1. catalogue et primitives ;
2. premier cycle réel ;
3. briques réutilisables ;
4. preuve de modularité avec un second template et un programme personnalisé ;
5. Forever ;
6. interface produit ;
7. migration, historique, statistiques, imports/exports et finition.

Ne pas commencer une couche avant que son contrat amont soit testé.

## 3. Architecture

Le nouveau code métier utilise des noms génériques. Ne pas ajouter de nouveau cœur sous `poc_531`.

Organisation cible :

```text
lib/
  core/
    storage/
  features/
    training_catalog/
      domain/
      application/
      data/
    cycle_generation/
      domain/
      application/
      data/
    forever/
      domain/
      application/
    training_log/
      domain/
      application/
      data/
    presentation/
```

Règles de dépendances :

```text
presentation → application → domain
data/infrastructure → ports application/domain
```

Le domaine est en Dart pur. Il n'importe ni Flutter, ni SQLite, ni code legacy.

## 4. Trois bases locales

### `catalog.db`

Contient les connaissances partagées :

- références aux livres et pages/sections ;
- mouvements et exercices ;
- prescriptions ;
- composants réutilisables ;
- templates et variantes ;
- options et compatibilités ;
- schedules ;
- assistance et conditioning ;
- définitions Forever.

Une version publiée est immuable. Une modification crée un nouveau brouillon puis une nouvelle version publiée.

Aucune licence, signature distante, PKI, canal de confiance ou reçu cryptographique n'est requis pour exécuter une règle structurée. Une règle canonique doit seulement avoir une référence bibliographique précise et un statut de revue explicite.

### `workspace.db`

Contient ce que l'utilisateur modifie :

- profil et unités ;
- 1RM, rep-max et Training Max ;
- ratio de Training Max global ou par mouvement ;
- matériel, barres et disques ;
- préférences ;
- brouillons ;
- configurations enregistrées ;
- templates et modules personnalisés.

### `training.db`

Contient ce qui a été généré et réalisé :

- snapshot immuable du programme ;
- cycles, semaines, séances, blocs et séries ;
- charges et plaques calculées ;
- résultats réels ;
- états des séances et séries ;
- événements ;
- données nécessaires aux statistiques.

Aucune clé étrangère ne traverse deux fichiers SQLite. Un programme généré contient un snapshot autonome.

## 5. Catalogue

Le catalogue est déclaratif, versionné et extensible.

Utiliser :

- des tables relationnelles pour les identités, relations, versions et ordres ;
- des payloads JSON stricts et versionnés uniquement pour les primitives polymorphes ;
- des codecs fermés qui refusent les types et clés inconnus.

Ne pas utiliser :

- un modèle EAV générique ;
- du Dart, JavaScript ou SQL libre dans la base ;
- un système de plugins spéculatif ;
- une hiérarchie d'abstractions sans cas d'usage immédiat.

L'inventaire peut contenir toutes les entrées historiques avec un statut. Seules les définitions complètement structurées et référencées sont publiées comme exécutables.

## 6. Primitives minimales

Le moteur doit connaître un vocabulaire fermé et réutilisable :

- programme, cycle, phase, semaine, séance et bloc ordonné ;
- mouvement et rôle de mouvement ;
- séries fixes ;
- répétitions fixes, plage, total et AMRAP ;
- pourcentage du Training Max ;
- pourcentage du 1RM ;
- charge fixe ;
- poids du corps ;
- durée, distance, intervalles et répétitions de conditioning ;
- warm-up ;
- main work ;
- supplemental ;
- assistance ;
- Joker décidé pendant la séance ;
- deload ;
- évolution du Training Max ;
- schedule fixe, rotatif et personnalisé.

Un nouveau template composé de primitives existantes ne doit nécessiter aucun nouveau compilateur spécialisé.

## 7. Générateur de cycle

Le cœur expose une fonction déterministe équivalente à :

```text
ResolvedCycleDefinition
+ CycleRequest
= GeneratedCycle
```

Le compilateur :

- ne lit pas SQLite pendant le calcul ;
- ne dépend pas de l'horloge globale ;
- reçoit explicitement la date de départ ;
- ne branche pas sur un identifiant de template ;
- produit semaines, séances, blocs, séries, charges et métadonnées de snapshot ;
- renvoie des erreurs métier typées.

Le chargement du catalogue, la validation de la demande, le calcul des max, la compilation, le plating et la persistance sont des responsabilités séparées.

## 8. Forever

Forever est un compositeur, pas un second moteur.

Il sélectionne des définitions de cycles, applique Leaders, Anchors, transitions, deloads et évolution du Training Max, puis appelle le même générateur de cycle.

Il ne calcule jamais directement les séries ou les charges.

## 9. Réutilisation du code existant

Réutiliser sélectivement après test :

- calculs purs de 1RM/TM ;
- arrondis et plating ;
- value objects ;
- références bibliographiques ;
- résultats goldens ;
- fixtures ;
- algorithmes de scheduling utiles ;
- schémas simples de `workspace.db` et `training.db`.

Utiliser les anciens moteurs comme références et goldens uniquement. Le nouveau moteur de production ne les appelle pas.

Ne pas reprendre en bloc :

- les moteurs spécialisés par template ;
- les règles dans les widgets ;
- les registres Dart concurrents du catalogue ;
- le système de signatures, confiance, licences et promotion par multiples hashes ;
- les grandes façades SQLite d'administration ;
- une ancienne branche complète.

## 10. Premier vertical slice obligatoire

Avant tout nouveau template ou écran, livrer un cycle Standard 5/3/1 sur quatre jours :

- définition chargée depuis `catalog.db` ;
- quatre mouvements principaux ;
- 1RM, rep-max ou Training Max direct ;
- ratio de TM configurable ;
- date de départ et jours réels ;
- ordre des séances configurable ;
- main work ;
- warm-up et deload comme composants réutilisables ;
- calcul des charges, arrondi et plating ;
- snapshot écrit puis relu depuis `training.db` ;
- saisie d'un résultat réel de série, notamment répétitions réalisées ;
- comparaison golden avec le comportement legacy vérifié.

Ce slice doit fonctionner sans `switch(templateId)`.

## 11. Simplicité et efficacité

- Implémenter uniquement le prochain gate fonctionnel.
- Ne pas approfondir une sécurité hypothétique.
- Ne pas normaliser les 354 recettes avant d'avoir prouvé le schéma et le compilateur avec des cas représentatifs.
- Ne pas répéter les audits déjà consignés.
- Ne pas créer un service, repository ou DTO supplémentaire si une responsabilité existante peut rester claire.
- Préférer un petit modèle explicite à un framework interne.
- Les poids sont représentés par un value object déterministe ; les pourcentages ne reposent pas sur des comparaisons flottantes fragiles.
- Une dépendance manquante se corrige en amont. Aucun contournement local dans l'UI ou un adaptateur.

## 12. Agents parallèles

Utiliser au maximum trois agents simultanés, uniquement sur des fichiers disjoints et après gel des contrats partagés.

Répartition recommandée :

1. audit de réutilisation en lecture seule ;
2. catalogue et stockage ;
3. compilateur et goldens.

Le lead conserve les contrats communs, l'intégration et les commits.

Ne pas lancer un agent UI avant que le compilateur produise et persiste un cycle réel.

## 13. Validation

Pendant un lot, exécuter les tests ciblés.

À la fin d'un gate :

```text
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
```

Ajouter les tests de migration lorsqu'un schéma change.

Construire Web seulement si l'interface ou l'infrastructure Web change. Construire Android seulement si le code Android ou le packaging change.

Ne jamais déclarer une commande réussie si elle n'a pas été exécutée jusqu'au bout.

## 14. Git

- Préserver tout changement utilisateur.
- Ne jamais utiliser `git reset --hard`.
- Ne jamais forcer un push.
- Créer de petits commits cohérents.
- Vérifier le diff avant chaque commit.
- Ne pousser qu'après autorisation explicite du propriétaire.
- Ne pas fusionner une branche donneuse complète.
