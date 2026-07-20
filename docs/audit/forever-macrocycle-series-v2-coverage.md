# Forever macrocycle series v2 — couverture

Date : 2026-07-20

## Couverture exécutable

| Catégorie | Révision | Statut | Limite sourcée |
| --- | --- | --- | --- |
| Programme autonome | Beginner Prep School (`FV-141`, alias canonique `forever-beginner-prep-school-v1`) | Exécutable | 5/3/1 Forever, pages 50–57 |
| Leader | `forever-original-fsl-leader-v1` | Exécutable dans `forever-2l1a-v2` | 5/3/1 Forever, pages 180–182 |
| Anchor | `forever-original-pr-set-anchor-v1` | Exécutable dans `forever-2l1a-v2` | 5/3/1 Forever, pages 180–182 |
| Protocole | `forever-seventh-week-deload-v1` | Obligatoire, inséré par le compilateur | 5/3/1 Forever, pages 31 et 33 |
| Protocole | `forever-seventh-week-tm-test-v1` | Obligatoire, inséré par le compilateur | 5/3/1 Forever, pages 31–33 |
| Recette | `forever-2l1a-v2` | Exécutable | Leader 1, Leader 2, Anchor 1 et deux frontières obligatoires |
| Transition | Leader 1 → Leader 2 | Autorisée uniquement avec la même révision Leader revue | Quatre jours d’entraînement ; progression TM sourcée |
| Transition | Leader 2 → Anchor 1 | Autorisée uniquement vers la révision PR Set Anchor revue | Quatre jours d’entraînement ; frontière deload obligatoire |

Les anciens IDs `FV-236`, `forever-original-531-fsl-2l1a-v1` et
`forever-original-531-fsl-v1` restent des alias de transport. Ils ne créent pas
de règles exécutables supplémentaires.

## Couverture non exécutable

| Catégorie | Entrée | Statut | Motif |
| --- | --- | --- | --- |
| Recette | `forever-2l2a-v1` | `needsReview` | Aucun jeu complet de règles productives revues n’est enregistré. |
| Recette | `forever-3l2a-v1` | `needsReview` | Aucun jeu complet de règles productives revues n’est enregistré. |
| Templates documentaires | BBB, composant FSL, Simplest Strength, Boring But Strong | `needsReview` ou documentaire | Aucune stratégie de calcul complète et revue n’est enregistrée. |
| C2 arbitraire | Toute révision différente de C1 sans transition explicite | Interdit | Le Core exige une transition compatible explicite. |

Les entrées `needsReview` ou interdites échouent dans le validateur et le
compilateur. L’UI ne les propose pas comme choix productifs.

## Runtime, continuation et migrations

- Le schéma v4 stocke soit un `standaloneProgramId`, soit une série finie.
- Les migrations v2 → v3 → v4, v3 → v4 et FV-236 → M1 2L/1A sont prises en
  charge sans modifier les anciens snapshots.
- La séquence compilée pilote l'ordre, les révisions et les dates transmis au
  générateur canonique ; l'Anchor utilise sa révision distincte.
- `CycleStrategyRegistry` et `ProtocolStrategyRegistry` sont les autorités
  immuables des prescriptions. Le générateur interprète ces stratégies et ne
  conserve aucune table métier concurrente.
- La continuation ajoute un seul M2 `projected/planned` et préserve M1.
- Les décisions TM conservent un état par lift : `confirmed`, `projected`,
  `proposed`, `held` ou `reset`. Une hausse supérieure à la règle est refusée.
- Le composeur restaure l’identité et l’état de terminaison de la série, expose
  les décisions TM, la fin de macrocycle et la fin de série.
- Les amendements du futur passent par aperçu puis confirmation atomique. Un
  aperçu obsolète ou une requête modifiée après l’aperçu est refusé.

## Protection historique

Le fixture canonique
`test/fixtures/core-v5/forever-original-fsl-2l1a.golden.json` reste inchangé.
Les goldens UI desktop et mobile ont été révisés pour le composeur en huit
étapes.

## État de validation du dernier lot

Validations exécutées le 20 juillet 2026 :

- `dart format --set-exit-if-changed .` : réussi ;
- `flutter analyze` : réussi, aucune anomalie ;
- `flutter test --reporter compact` : réussi, 373 tests ;
- tests visuels desktop et mobile : réussis, 4/4 ;
- tests ciblés génération canonique, adaptateur et widgets : réussis, 36/36 ;
- tests ciblés du domaine planning : réussis, 21/21 ;
- tests ciblés de persistance : réussis, 10/10.

Google Chrome 150.0.7871.129 et le ChromeDriver officiel 150.0.7871.124 sont
alignés sur la même branche 150.0.7871. Le parcours `flutter drive` a réussi en
35,4 secondes : cinq tests sur cinq, dont les scénarios Original, Beyond et
Forever M1 → M2.
Firefox 152.0.6 avec GeckoDriver officiel 0.36.0 exécute les mêmes cinq tests
avec succès en 34,7 secondes. Le scénario Forever termine M1 et M2, clôture la
série puis recrée la page et restaure le snapshot v4 depuis le stockage local du
navigateur, avec les TM Press 62,5 puis 65.

Microsoft Edge et le pilote local protégé de `.SOURCE/` sont alignés en version
150.0.4078.83. Le parcours Edge n'a pas été exécuté : Flutter 3.44.6 envoie
`browserName: edge`, capability refusée par EdgeDriver qui attend
`MicrosoftEdge`. Chrome reste donc la cible Web de référence ; ce blocage relève
du SDK Flutter et aucun résultat Edge n'est déclaré.

Le pilote de test limite désormais une exécution navigateur à deux minutes afin
qu’un défaut de connexion ne bloque plus le chantier. À la demande du
propriétaire, les validations et builds Android sont reportés à un chantier
ultérieur.
