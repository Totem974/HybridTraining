# Audit Web — options, état et couverture de tests

Date de l’audit : 2026-07-22  
Périmètre : `CycleEditorSchema → formulaire/état → buildCycleRequest → bridge → Program`, conditions, préférences, migrations et tests Web.  
Nature : audit statique en lecture seule du code applicatif ; aucun comportement n’est considéré valide sans preuve directe dans le code ou un test qui vérifie le résultat métier.

## Synthèse

Le formulaire est bien alimenté par `CycleEditorSchema` et les composants émettent majoritairement des intents génériques `path/value`. La frontière moteur reste locale. En revanche, le flux d’état central est encore contenu dans `main.ts`, sans store explicite ni repository branché. Les valeurs conditionnelles devenues invisibles ou invalides ne sont pas nettoyées. Le mapping des options vers `CycleRequest` et leur consommation par le bridge laissent plusieurs contrôles visibles sans effet métier démontré.

Les tests présents valident correctement les renderers isolés, les métadonnées du client moteur, les primitives de stockage et quelques parcours de génération. Ils ne constituent pas encore une preuve de bout en bout pour l’effet de chaque option, les migrations, la sauvegarde/relecture IndexedDB, le nettoyage des dépendances ou la fidélité du programme.

## Constats prioritaires

### P0 — options visibles mais non appliquées au moteur

1. `buildCycleRequest` construit `options` en conservant les chemins complets (`"options.<id>"`) comme clés (`apps/web_generator/src/main.ts:284`). Une map métier attend normalement les identifiants d’option, sans le préfixe de chemin. Plus important encore, `_generate` accepte la clé top-level `options`, mais ne la lit pas lors de la construction de `CycleRequest` (`packages/training_engine_web_bridge/lib/src/engine_bindings.dart:754-860`).

2. Les seules options de formulaire explicitement consommées par `_generate` sont :

   - les pourcentages recopiés dans `percentageParameters` ;
   - `includeDeload`, dérivé uniquement de `options.include_deload` dans `main.ts:290`.

   Les booléens ou choix Warm-up, Joker, assistance, conditioning et autres paramètres non-percentage peuvent donc être visibles et modifiables sans effet métier prouvé. Le test E2E intitulé « catalog-driven options remain effective » (`cycle-parity.spec.ts:82`) ne compare aucun résultat avant/après : il décoche des cases, puis vérifie seulement qu’une génération ne signale pas d’erreur. Ce test peut réussir avec une option entièrement décorative.

3. Le bridge résout la définition avant de compiler sans recevoir la map `options` (`engine_bindings.dart:774`). Si certaines options doivent modifier les blocs résolus, leur valeur n’atteint pas ce point du pipeline.

Action requise : définir dans le contrat la représentation canonique des options, adapter `buildCycleRequest`, puis faire consommer chaque paramètre par le resolver/compiler. Ajouter un test de différentiel métier par option exposée.

### P0 — stockage IndexedDB non branché dans l’application

Les trois stores et leurs repositories existent (`workspace_drafts`, `saved_configurations`, `training_snapshots`) et sont testés isolément. Cependant, `main.ts` n’instancie ni `IndexedDbWorkspaceStorage` ni aucun des trois repositories. Aucun brouillon, configuration ou snapshot généré n’est sauvegardé ou relu par le parcours produit.

Le test E2E « plating visibility and local persistence survive reload » (`cycle-parity.spec.ts:92`) ne couvre que `showPlating` dans `localStorage`. Il ne prouve pas la sauvegarde/relecture IndexedDB demandée. L’import/export fichier est local, mais n’est pas une persistance de workspace.

Action requise : brancher les repositories sur les événements de formulaire/génération, définir les identifiants et la politique de restauration, puis tester un nouveau contexte de page après reload.

### P1 — valeurs dépendantes non nettoyées

1. Lorsqu’un champ parent change, la visibilité est recalculée et le formulaire est rerendu (`main.ts:129`), mais la valeur des enfants devenus invisibles ou désactivés reste dans `values` et dans `schema.fields`. `fieldsByRegion` masque seulement le contrôle ; il ne nettoie pas l’état.

2. `buildCycleRequest` collecte toutes les entrées `options.*`, y compris celles qui sont maintenant invisibles ou désactivées. Un ancien choix peut donc continuer à influencer une requête après disparition du contrôle.

3. Lors d’un changement de template/variante/schedule, `loadSchema(..., preserve: true)` réutilise toute valeur précédente ayant le même chemin (`main.ts:81`) sans vérifier :

   - qu’elle appartient encore aux `choices` ;
   - qu’elle respecte les nouvelles bornes ;
   - qu’elle est encore visible/activée ;
   - que sa sémantique est identique dans le nouveau schéma.

4. Le mode Rep Max conserve les répétitions lorsque l’utilisateur revient à un autre mode. Elles ne sont actuellement pas sérialisées hors Rep Max, ce qui limite ce cas précis, mais aucun invariant générique ne protège les autres champs conditionnels.

Action requise : appliquer une normalisation pilotée par le schéma après chaque changement parent et chaque remplacement de schéma. La règle doit supprimer/réinitialiser les descendants invisibles ou invalides avant validation et génération, sans règles de template dans TypeScript.

### P1 — import valide mais état visuel désynchronisé

L’import appelle bien `validateCycle` sur le payload puis génère ce payload. En revanche, il ne recharge pas le template/schéma et ne réhydrate pas `values`. Le programme importé peut donc être affiché alors que le formulaire montre encore la configuration précédente ; la prochaine auto-génération repartira de cet ancien état.

L’enveloppe importée n’est pas comparée aux métadonnées courantes avant validation (`engineVersion`, `catalogVersion`, `catalogHash`). Une requête ancienne compatible peut passer, mais il n’existe ni politique de compatibilité ni migration explicite.

Action requise : vérifier/migrer l’enveloppe, charger le schéma correspondant, normaliser et réhydrater les valeurs, puis valider et générer. Le test E2E actuel vérifie seulement la présence d’un statut « generated ».

### P1 — requête et UI pas totalement déterministes

- `cycleId` utilise `Date.now()` (`main.ts:276`) : deux générations identiques produisent des requêtes/snapshots différents. Cela complique les sauvegardes, les comparaisons et les captures déterministes.
- `requestMovements` fusionne les mouvements du schéma avec `sessionOrder` (`main.ts:251`). Pour une séance groupée, `sessionOrder` peut contenir un identifiant de groupe (`SQ+BP`/identifiant catalogue), qui n’est pas un mouvement nécessitant un max. Des `maxInputs` synthétiques à 100 peuvent ainsi être ajoutés.
- `startDate` concatène une heure locale sans suffixe de zone. Le rendu et le hash peuvent varier selon la sémantique attendue du contrat.
- l’application appelle directement `generateCycle`; elle n’exploite pas `validateCycle` pour présenter les erreurs structurées avant génération.

### P1 — champs visibles ou données de sortie sans effet complet

| Élément visible | État observé | Risque |
|---|---|---|
| Warm-up/Joker/assistance/conditioning et options non-percentage | Valeur visible, mais map `options` non consommée par `_generate` | Décoratif jusqu’à preuve différentielle |
| `programTitle` | Envoyé dans la requête, accepté parmi les clés, non consommé par `CycleRequest`; `renderProgram` n’affiche aucun titre utilisateur | Champ visible sans effet produit observable |
| `showPlating` | Accepté par le bridge mais non métier ; agit correctement sur le renderer et la préférence | Effet de présentation seulement, à documenter comme tel |
| Maximum total des plaques | Valeur read-only calculée dans le schéma initial ; aucun nouvel appel moteur après modification des compteurs | Total affiché susceptible de devenir obsolète |
| Unité lb | Le champ global alimente la requête, mais les libellés de plaques du schéma sont construits en `kg` et le maximum initial n’est pas rafraîchi | Affichage incohérent possible après bascule |
| Profil matériel | Le renderer Plating sait afficher un choix fourni par le schéma, mais le schéma bridge actuel n’expose pas de champ profil | Capacité UI non branchée |
| Action Générer | Le schéma l’expose, mais `output.ts:19` la masque volontairement et la génération est automatique | Divergence avec le parcours demandé et action de contrat inutilisée |
| Assistance dans Program | `movementNames()` ne connaît que les mouvements ayant un champ `max-load-*`; le renderer ne possède pas de dictionnaire des exercices d’assistance | Nom d’exercice manquant ou fallback vide possible |

La colonne « décoratif » doit être levée uniquement par un test montrant une modification canonique de `CycleResponse`, pas par la seule absence d’erreur.

## Conditions et état de formulaire

Points satisfaisants :

- `visibleWhen` et `enabledWhen` sont évalués génériquement ;
- les contrôles n’embarquent pas de règle BBB/FSL/Forever ;
- les choix affichés viennent du schéma ;
- les changements qui servent de dépendance provoquent un rerender.

Manques :

- pas de store explicite : `schema`, `values`, requête et dernière réponse sont des variables globales de module ;
- pas de reducer/transition testable pour les changements parent/enfant ;
- pas de nettoyage récursif ou de convergence si une remise à zéro change une autre condition ;
- pas de validation des valeurs préservées contre le nouveau schéma ;
- pas de protection contre une réponse asynchrone de schéma devenue obsolète après plusieurs changements rapides ;
- les contrôles spécialisés ignorent silencieusement certains `kind` qu’ils ne connaissent pas, au lieu d’échouer explicitement ou de retomber sur un renderer contractuel.

## Préférences et migrations

### Ce qui est couvert

- `localStorage` est limité aux trois clés autorisées : langue, sections repliées, affichage des plaques ;
- les identifiants de sections sont filtrés ;
- un JSON de sections invalide revient à une liste vide ;
- les stores IndexedDB sont créés lors de l’upgrade initial et les enveloppes/timestamps sont validés avant écriture.

### Ce qui manque

- aucune version de préférence ni migration de clés/valeurs ;
- aucune migration IndexedDB au-delà de `databaseVersion = 1` ;
- aucune stratégie pour catalog hash/engine version obsolète dans un brouillon ou snapshot ;
- aucune gestion testée de `versionchange`, quota, transaction abort, base bloquée après ouverture, stockage indisponible ou mode privé ;
- `collapsedSections` est persisté mais aucune section du produit ne le lit ou ne l’applique ; il est donc actuellement décoratif ;
- pas de test prouvant que les repositories sont réellement utilisés par l’application.

## Couverture actuelle

### Unitaire

Présent : conditions simples, doublons de schéma, blocs Weight/Template/Additional Options/Plating, rendu Program élémentaire, client moteur (origine et mismatch de métadonnées), stockage/enveloppes/repositories isolés.

Limites : les tests utilisent surtout des schémas synthétiques et ne vérifient pas le round-trip avec un vrai `CycleEditorSchema` du bridge. Ils ne testent pas `main.ts`, `buildCycleRequest`, la normalisation d’état, la réhydratation d’import ou la correspondance exhaustive champ → requête.

### E2E

Présent : Standard, BBB, Two Days, Rep Max, toggles options, affichage plaques, FR/EN, import/export, 1440/390/320, absence de requête externe, captures de preuve.

Limites : assertions majoritairement textuelles et « pas d’erreur ». Aucune comparaison canonique avant/après option, aucune persistance IndexedDB, aucun test clavier/accessibilité automatisé, aucune assertion de nettoyage des champs conditionnels, aucune capture avec seuil de régression (`toHaveScreenshot`) et aucune vérification complète des 23 variantes via l’UI.

## Tests requis avant validation

### Unitaires — état et mapping

1. Reducer/store : changement d’un parent masque un enfant, nettoie sa valeur, puis produit une requête sans ce champ.
2. Changement template/variante/schedule : valeur commune valide préservée ; valeur hors choix/hors bornes réinitialisée ; ancien champ absent supprimé.
3. Table contractuelle exhaustive : pour chaque `field.kind` et région, vérifier rendu, disabled/visible, intent et sérialisation.
4. `buildCycleRequest` :

   - One RM, direct TM et Rep Max avec répétitions différentes ;
   - options bool/int/choice/percentage sans préfixe parasite ;
   - groupe de séance sans faux `maxInput` ;
   - kg/lb, barre et multiplicité exacte des plaques ;
   - date et ordre ;
   - aucun champ invisible/désactivé.

5. Import : mismatch API/engine/catalog refusé ou migré ; schéma/valeurs réhydratés ; payload jamais muté.
6. Préférences : anciennes clés/versions, valeurs invalides, migration idempotente.
7. IndexedDB : upgrade depuis une version précédente, transaction abort/quota, `versionchange`, restauration du draft et tri déterministe.
8. Program : fixed/range/AMRAP, assistance (nom + répétitions), séance groupée, dates, avertissements, plaques on/off, aucune fuite d’ID.
9. Maximum matériel : modification d’un compteur déclenche une valeur moteur rafraîchie, sans calcul TypeScript.

### Intégration — bridge réel

1. Charger le bundle réel, demander le schéma de chaque variante, remplir les valeurs par défaut, valider puis générer.
2. Pour chaque champ visible modifiable, changer une valeur et vérifier soit :

   - une différence métier attendue dans le JSON canonique ;
   - un effet de présentation explicitement classé comme tel ;
   - un rapport d’incompatibilité moteur structuré.

   Aucun quatrième état « accepté mais sans effet ».

3. Comparer la requête construite côté Web à un fixture contractuel, puis comparer la réponse bridge à l’oracle natif.
4. Round-trip sauvegarde : état → enveloppe IndexedDB → nouvelle instance → état/requête/réponse identiques.
5. Round-trip export/import : configuration → fichier → page neuve → formulaire et réponse identiques ; programme exporté inchangé.
6. Variations de catalogue/version : migration supportée ou refus structuré, sans restauration partielle.

### Playwright / E2E

1. Remplacer le test d’options par des assertions différentielles : Warm-up ajoute/retire les blocs, Joker ajoute/retire les séries, Deload ajoute/retire la semaine/bloc prévu, assistance change les exercices/répétitions.
2. Parent/enfant : activer une option, modifier son enfant, désactiver le parent, changer de template, revenir ; vérifier état nettoyé et JSON envoyé.
3. Sauvegarder un draft/configuration et un snapshot dans IndexedDB, recharger ou ouvrir une nouvelle page, puis vérifier formulaire et Program.
4. Importer une configuration d’un autre template : vérifier sélections, champs, options, programme et message de validation ; tester fichier corrompu et catalog hash incompatible.
5. Plating : changer quantités/barre/unité, vérifier le total moteur rafraîchi et les pastilles exactes ; basculer Show Plating sans régénération métier inutile.
6. Scheduling : plusieurs fréquences, ordre valide, rejet/absence d’ordre invalide, séance groupée et date.
7. Vérifier le titre utilisateur dans la sortie/export ou supprimer le champ si non supporté.
8. Parcours clavier complet, focus visible, libellés/roles, annonce d’erreur et audit axe sans violation sérieuse.
9. `toHaveScreenshot` avec baselines et seuil documenté à 1440/390/320, en FR et EN pour les zones sensibles.
10. Réseau : conserver l’interception globale et ajouter génération, import, export, reload IndexedDB et changement de template sous la même assertion zéro origine externe.
11. Exécuter au minimum Chromium desktop/mobile et le smoke WebKit configuré ; ne pas compter les captures conditionnellement ignorées comme couverture WebKit.

## Gate de sortie conseillé

Le jalon Web ne devrait être déclaré conforme que lorsque :

- chaque champ visible possède une preuve d’effet ou une classification explicite « présentation uniquement » ;
- aucun descendant caché/désactivé n’est sérialisé ;
- import et restauration IndexedDB réhydratent le formulaire avant génération ;
- les trois stores sont exercés par un parcours produit ;
- les 23 variantes passent le même pipeline réel `schema → état → requête → bridge → Program` ;
- les assertions E2E vérifient des sorties métier, pas seulement l’absence d’erreur ;
- aucune donnée technique brute ni valeur obsolète n’apparaît dans Program ou Plating.
