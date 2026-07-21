# État du générateur de cycles — 21 juillet 2026

## Périmètre

Le chantier actif est le générateur de cycles. Forever est hors périmètre fonctionnel : il reste un inventaire historique et deviendra ultérieurement un générateur de macrocycles appelant le même `CycleCompiler`.

## Réalisé

- Contrats génériques gelés pour le catalogue, le compilateur et l'éditeur Web.
- Trois responsabilités de stockage séparées : catalogue, espace utilisateur et snapshots d'entraînement.
- Compilateur Dart pur, déterministe et sans branchement sur un identifiant de template.
- Primitives génériques pour plans hebdomadaires, phases répétées, charges relatives, exécutions de séries et décisions runtime.
- Source déclarative répartie sous `catalog_src/`, codec JSON strict et builder déterministe.
- Inventaire : 354 entrées classifiées sur 354.
- Catalogue déclaré : 16 templates, 19 variantes, 51 composants, 9 schémas d'options, 8 schedules, 6 mouvements, 30 exercices, 8 plans d'assistance et 11 définitions de conditioning.
- Familles présentes : Standard, Powerlifting, BBB, Triumvirate, Periodization Bible, Bodyweight, Simplest Strength, Beginners, Full Body phases 1–3, Pyramid, First Set Last et 5's Progression.
- Page Web catalogue, formulaires dynamiques, brouillons et service de génération implémentés en composants isolés.
- Forever : 182 entrées historiques, zéro template Cycle actif.

## État réel de validation

Le générateur n'est pas encore lançable depuis l'application Web principale.

- `/cycle` existe, mais n'est pas raccordé au `HybridTrainingApp` ni à l'ouverture runtime des trois bases.
- Le démarrage Web utilise encore l'ancien POC 5/3/1.
- Le seed exhaustif n'est pas encore publié comme `catalog.db` runtime Web.
- Quatre suites ciblées échouent actuellement à la compilation : un test Beyond utilise un type trop large et le codec SQLite ne traite pas encore `RelativeSetLoad` exhaustivement.
- Le compteur actuel `compileFailures == 0` ne constitue donc pas encore une preuve de compilation exhaustive.
- Aucun scénario Chrome complet n'a encore été déclaré passant.

## Prochain gate

1. Réparer les erreurs de compilation ciblées et faire compiler réellement chaque variante.
2. Produire et charger le catalogue runtime exhaustif.
3. Raccorder `/cycle`, `catalog.db`, `workspace.db` et `training.db` dans la composition Web.
4. Valider génération, sauvegarde et relecture dans Chrome.
5. Exécuter formatage, analyse, tests complets, contrôle du diff et build Web release.

Forever ne commence qu'après ce gate.
