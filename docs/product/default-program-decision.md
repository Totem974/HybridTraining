# Décision sur le preset par défaut

Original, Beyond et Forever sont des générations successives du même système
5/3/1, et non des familles exclusives. Les concepts possèdent une origine
historique et peuvent recevoir des révisions propres à plusieurs générations.

Le seul preset disponible est `forever-original-fsl-v1`, version 1. Il utilise
les règles Forever, la révision principale `forever-original-531-v1` et la
révision supplémentaire `forever-first-set-last-5x5-v1`. Il conserve un
Training Max applicatif à 90 %, cinq séries FSL, quatre jours recommandés et
trois jours comme adaptation produit.

Seul un preset complet et disponible peut générer un cycle. Un concept, une
origine ou une génération ne peut jamais être persisté comme programme actif.

## Compatibilité SQLite

Le schéma reste en version 1 et les cycles conservent l’identifiant
`forever-original-fsl-v1`. Le champ historique `family` reste lisible et la
valeur `classic` devient l’alias de sérialisation de `original`.
