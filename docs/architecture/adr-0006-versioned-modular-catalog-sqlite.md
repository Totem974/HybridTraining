# ADR-0006 — Trois bases SQLite aux cycles de vie séparés

## Décision

Le stockage local est séparé physiquement :

- `catalog.db` contient les versions publiables, sources, preuves, modules, templates, variantes, règles, schedules, mouvements et prescriptions ; le runtime l’ouvre en lecture seule ;
- `workspace.db` contient les profils, poids et Training Max, matériel, brouillons, préférences et clones personnalisés exportables ;
- `training.db` contient les plans générés, sessions, blocs, prescriptions résolues, résultats, événements et statistiques.

Il n’existe aucune clé étrangère entre ces bases. Chaque schéma possède sa version, sa migration et sa transaction propres.

Une version de catalogue publiée ou retirée est immuable par triggers SQLite. Toute évolution part d’une nouvelle version brouillon liée par `parent_version_id`.

Le cycle de vie unique est `draft → inReview → approved → published → retired`, avec sorties explicites vers `rejected` et retour contrôlé vers un brouillon. « Archived » est représenté par `retired`; « superseded » n’est pas un statut mais la relation `parent_version_id` vers la version suivante. L’autorité (`canonical`, `compatible`, `userCustom`) et la revue (`needsReview`, `confirmed`, `rejected`) restent indépendantes.

La vue `runtime_catalog_entries` est la projection de découverte runtime : version `published`, revue `confirmed`, implémentation `implemented`, visibilité `visible` et licence `ownedReference` ou `compatible`. Les identifiants historiques (`OR-001`, `BY-026`, `FV-141`) sont conservés sans normalisation dans `catalog_entry_key`; les identifiants stables du domaine sont distincts et en minuscules.

La publication est une opération administrative distincte du runtime. Elle exige, dans la même transaction, un reçu `catalog_publication_validations` correspondant au hash canonique et attestant preuves, licences, dépendances, enfants et absence de bloqueur. Une signature optionnelle n’est acceptée qu’avec son `keyId`, un canal de confiance explicite et `signature_verified`. La façade runtime n’expose qu’une ouverture en lecture seule ; l’écriture passe par la capacité d’administration dédiée.

La vue runtime filtre le graphe et non la seule ligne d’entrée : une preuve confirmée et un binding moteur exécutable sont obligatoires, et une dépendance bloquée, non revue ou sans licence autorisée exclut son parent. Le staging reste un espace de préparation séparé et ne constitue jamais une source runtime.

Toutes les références internes à une version sont gardées par triggers : une ligne ne peut ni changer de `catalog_version_id`, ni pointer vers un objet d’une autre version. Les guards considèrent à la fois l’ancienne et la nouvelle version lors des mutations ; les contenus `published` et `retired` sont immuables.

Un plan copie `catalog_version_id`, `catalog_content_hash`, la version du schéma de snapshot, son hash et le snapshot minimal entièrement résolu nécessaire à sa reproduction. Ce snapshot ne contient ni texte source protégé, ni preuve/extrait, ni donnée personnelle : uniquement identifiants stables, paramètres numériques, ordre et règles résolues. Il reste donc utilisable si le catalogue est absent ou remplacé. Une personnalisation est un clone explicite dans `workspace.db`, sans mutation du canon.

## Conséquences

- Les règles `NEEDS_REVIEW` peuvent être inventoriées sans devenir exécutables.
- Les variantes, compatibilités, obligations et visibilité restent déclaratives.
- L’assistance, le supplemental, les politiques warm-up/Joker/deload et les programmes finis partagent les mêmes modules et prescriptions.
- L’ancien stockage monolithique v5 reste inchangé. Son import vers les trois bases devra être orchestré comme trois transactions reprises séparément, sans prétendre à une atomicité inter-base.
- Le stockage applicatif doit utiliser le chiffrement fourni par la plateforme quand il est disponible. Les exports workspace sont explicites, validés et ne contiennent pas le catalogue protégé. Avec les clés étrangères SQLite activées, l’effacement d’un profil cascade atomiquement vers ses poids et Training Max, gymnases et matériel, brouillons, préférences et définitions personnalisées. Les journaux de `training.db` ne sont pas touchés par cette cascade inter-base et suivent une durée de retenue distincte et documentée.
- Une migration coordonnée ne remplace jamais simultanément les trois fichiers : chaque base migre et se vérifie séparément, puis un marqueur applicatif confirme que leurs versions sont compatibles. Toute reprise après interruption conserve les fichiers précédents jusqu’à cette confirmation.
- La frontière d’écriture de `training.db` doit recalculer et vérifier canonisation et hash du snapshot avant insertion. Les contraintes `json_valid`, version de schéma, algorithme `sha256` et version de canonisation complètent ce contrôle sans le remplacer.
