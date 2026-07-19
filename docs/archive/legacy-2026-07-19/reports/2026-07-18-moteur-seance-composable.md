# Rapport — moteur de séance composable

## Livré

- domaine pur couvrant les treize rôles demandés et six types de cible ;
- exécution multi-blocs et multi-mouvements dans l’ordre du blueprint ;
- migration additive SQLite v3 et persistance immédiate ;
- démarrage/reprise, navigation, résultat, modification, annulation, repos par
  bloc, notes, abandon, saut du reste, clôture et données de résumé ;
- premier écran extrait, cartes de blocs distinctes et test 390 × 844 ;
- tests de domaine, widget et persistance avec données fictives.

## Compatibilité

Les tables historiques v1 ne sont pas modifiées. La migration 1 → 3 conserve
les lignes existantes. Aucun rôle d’assistance ni nouveau programme n’est
inventé : le runtime ne fait qu’exécuter les blocs reçus.

## Validation

`flutter pub get`, le formatage, l’analyse statique et les 98 tests passent. Le
test d’intégration Android passe avec la flavor `dev`. Les APK `devDebug` et
`prodDebug` sont compilés avec succès. Aucun push n’est effectué.
