# Cycle de vie du Training Max Forever

## Identité

Une projection ou décision porte `cycleInstanceId`, `nodeId`, mouvement et
frontière de séquence. Le numéro de semaine est une coordonnée d'affichage, pas
une clé métier.

## États

- `confirmed` : valeur initiale ou décision explicitement acceptée ;
- `projected` : valeur future utilisée pour prévisualiser les charges ;
- `proposed` : ajustement présenté à l'athlète ;
- `held` : maintien explicite ;
- `reset` : nouvelle base explicitement choisie.

La génération initiale confirme seulement les TM d'entrée. Les cycles futurs
utilisent des projections visibles. À une frontière, le Core propose par lift une
hausse standard, une hausse réduite, un maintien ou un reset.

Une confirmation régénère uniquement les nœuds futurs. Les séances terminées,
résultats et décisions passées restent immuables. Deload, TM Test et PR Test sont
reconnus par leur `ProtocolPurpose`, jamais par les semaines 7, 10 ou 11.
