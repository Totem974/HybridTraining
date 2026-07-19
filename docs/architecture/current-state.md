# État courant

L’application démarre directement dans le Core Validation Shell. L’onboarding,
le dashboard, le calendrier visuel, la bibliothèque visuelle et l’ancienne
séance guidée ne sont plus compilés. Le shell est un outil de validation, pas la
future interface produit.

Beginner Prep School v1 est le seul preset exécutable. Original 5/3/1 et
Original + FSL restent documentaires ou réservés à la réouverture des données
historiques tant que leurs contrats complets restent `NEEDS_REVIEW`.

Le chemin canonique actif est :

```text
Core Validation Shell
  → contrôleur / interfaces application
  → domaines Dart purs (programme, runtime, TM, statistiques)
  → dépôts SQLite transactionnels
  → schéma v4 et sauvegarde v4 compatible v1/v2/v3
```

Le runtime v4 persiste un état immuable, les résultats réels et un journal
ordonné après chaque action. Les anciennes tables v1 et le runtime v3 restent
lisibles uniquement pour migration et compatibilité des sauvegardes.

Le changement de programme possède un aperçu sans écriture et une application
atomique. Une séance active exige une décision explicite. Les séances terminées,
records et historiques de TM ne sont jamais réécrits.
