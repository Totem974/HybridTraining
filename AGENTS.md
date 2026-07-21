# AGENTS.md — HybridTraining

## Objectif et priorité

HybridTraining est une application locale de programmation et de suivi d'entraînement. La chaîne métier active est :

```text
catalogue publié + choix utilisateur + max + ratio TM + planning + matériel
→ cycle généré → snapshot autonome dans training.db
```

Ordre obligatoire : catalogue et primitives, premier cycle réel, preuve de modularité, Forever, puis interface produit. Ne pas commencer une couche avant que son contrat amont soit testé.

## Architecture

Le nouveau cœur utilise des noms génériques et n'est pas ajouté sous `poc_531` :

```text
lib/
  core/storage/
  features/
    training_catalog/{domain,application,data}/
    cycle_generation/{domain,application,data}/
    forever/{domain,application}/
    training_log/{domain,application,data}/
```

Les dépendances vont de la présentation vers l'application puis le domaine. Le domaine est en Dart pur et n'importe ni Flutter, ni SQLite, ni code legacy. Les anciens moteurs sont uniquement des références et des oracles goldens.

## Trois bases locales

- `catalog.db` contient les connaissances partagées, déclaratives, versionnées et publiées.
- `workspace.db` contient le profil, les max, ratios, équipements, préférences et brouillons utilisateur.
- `training.db` contient les snapshots autonomes générés, le détail prévu et les résultats réels.

Aucune clé étrangère ne traverse deux fichiers SQLite. Une version publiée du catalogue est immuable ; une correction crée une nouvelle version. Aucune licence, signature, PKI, chaîne de confiance ou reçu cryptographique n'est nécessaire.

## Catalogue et primitives

Utiliser des tables relationnelles pour les identités, relations, versions et ordres, et du JSON strict uniquement pour les primitives polymorphes. Les codecs refusent les types et clés inconnus. Ne pas créer de modèle EAV, langage libre, système de plugins spéculatif ou abstraction sans cas d'usage immédiat.

Le vocabulaire fermé couvre notamment programme, cycle, semaine, séance, bloc ordonné, mouvement, répétitions fixes/plage/total/AMRAP, pourcentage TM/1RM, charge fixe, poids du corps, warm-up, main work, supplemental, assistance, deload et schedule. Un nouveau template composé de primitives existantes ne nécessite aucun compilateur spécialisé.

## Générateur de cycle

Le cœur expose une fonction déterministe équivalente à :

```text
ResolvedCycleDefinition + CycleRequest = GeneratedCycle
```

Le compilateur ne lit pas SQLite, ne lit pas l'horloge globale, ne branche pas sur un identifiant de template et renvoie des erreurs métier typées. Le chargement du catalogue, la validation, la résolution des max, le calcul des charges, le plating, la compilation et la persistance restent des responsabilités séparées.

## Premier vertical slice

Avant tout nouveau template ou écran, livrer Standard 5/3/1 sur quatre jours : définition chargée depuis `catalog.db`, quatre mouvements, saisies 1RM/rep-max/TM direct, ratio configurable, dates et ordre configurables, warm-up/main work/deload, arrondi et plating, snapshot écrit puis relu depuis `training.db`, résultat réel d'une série écrit puis relu, et comparaison golden avec le legacy vérifié.

## Simplicité et réutilisation

Réutiliser sélectivement les calculs purs, arrondis, plating, value objects, références, goldens, fixtures, scheduling et schémas simples. Ne pas reprendre en bloc les moteurs spécialisés, règles de widgets, registres concurrents, signatures/confiance/licences, grandes façades SQLite ou une branche donneuse complète.

Implémenter uniquement le prochain gate fonctionnel. Les poids et pourcentages sont déterministes. Une dépendance manquante se corrige en amont, sans contournement local.

## Agents parallèles

Utiliser au maximum trois agents simultanés, uniquement sur des fichiers disjoints après gel des contrats partagés. Répartition : audit/goldens, catalogue/stockage, compilateur. Le lead conserve les contrats communs, l'intégration, `workspace.db`, `training.db` et les commits. Aucun agent UI avant le cycle réel persistant.

## Validation

Pendant un lot, exécuter les tests ciblés. À la fin d'un gate :

```text
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
```

Ajouter les tests de migration lorsqu'un schéma change. Ne jamais annoncer une commande réussie sans l'avoir exécutée jusqu'au bout.

## Git et sécurité

Préserver tout changement utilisateur. Ne jamais utiliser `git reset --hard`, stash destructif, push forcé ou fusion d'une branche donneuse complète. Créer de petits commits cohérents après inspection du diff, tests ciblés et `git diff --check`. Ne pousser qu'après autorisation explicite. `.SOURCE/` et les références locales restent en lecture seule ; ne copier aucun code décompilé, secret, donnée personnelle ou contenu protégé.
