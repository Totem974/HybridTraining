# Bibliothèque canonique de programmes

La bibliothèque est un index local, déterministe et requêtable. Elle reprend les
42 entrées de l’index Forever R2 et les complète avec les composants transversaux,
le protocole de transition, le preset de compatibilité et les révisions nommées. Elle distingue les
programmes complets, composants, protocoles, presets exécutables et révisions
historiques. Une entrée représente une vue canonique d’un concept à une génération
donnée ; plusieurs presets peuvent donc référencer le même `conceptId`.

`ProgramLibraryRepository` reçoit une `ProgramQuery`. La recherche normalise la
casse et les accents français/anglais. `ProgramFilter` compose les dimensions avec
une logique ET entre dimensions et OU au sein d’une dimension. Le tri conserve
l’ordre canonique comme dernier critère, ce qui garantit sa stabilité.

Le mode consultation expose aussi les entrées incomplètes. Le mode sélection ne
permet de choisir qu’une entrée de type preset possédant un identifiant persistant,
des règles vérifiées et une implémentation. Un composant ou une ligne documentaire
ne peut jamais générer seul un plan.

Une métadonnée non établie par R2 reste absente. Elle est affichée « À vérifier »
et ne correspond pas à un filtre précis. La bibliothèque ne déduit donc ni niveau,
ni objectif, ni fréquence, ni équipement à partir du seul titre d’une section.

L’interface propose quatre vues : Programmes, Composants, Protocoles et Historique.
La recherche, les filtres et le tri sont traduits en requêtes de domaine ; aucun
widget ne contient de règle de filtrage. Le panneau couvre origine, génération,
statut Forever, phase, niveau, objectif, fréquence, mouvements principaux,
équipement, plage de TM et maturités documentaire et d’implémentation. Les onglets
portent le filtre de type.

## Extension

Une nouvelle entrée doit avoir un identifiant stable, un `conceptId`, une génération,
des métadonnées de requête et des statuts explicites. Une règle non validée reste
`indexed` ou `needsReview` et non exécutable. L’ajout d’un preset exige également un
générateur enregistré et un test de sélection.
