# Spécification de la bibliothèque de programmes

La bibliothèque possède deux usages : `browse` depuis les réglages et `select`
depuis l’onboarding. Elle lit exclusivement le `ProgramCatalog` du domaine.

La vue initiale « Actuels » retient les révisions `current` et
`currentWithRestrictions`, indépendamment de leur origine. Les filtres de statut
sont Actuels, Legacy et Tous ; le filtre d’origine propose Toutes, Original,
Beyond et Forever.

Chaque carte expose textuellement l’origine du concept, la génération de la
révision, le statut dans Forever et le statut documentaire. La fiche est une
liste défilable présentant le type et l’historique des révisions. Une donnée
inconnue est affichée « À vérifier », jamais remplacée par une description
inventée.

Seul un preset `available` peut être sélectionné. Pour ce lot, il s’agit de
`forever-original-fsl-v1`, recommandé et présélectionné.
