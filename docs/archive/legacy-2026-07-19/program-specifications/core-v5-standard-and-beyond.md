# Core v5 - Standard/Powerlifting et Beyond

Cette spécification ne couvre que les règles vérifiées nécessaires aux deux
blueprints de référence. Elle ne prétend pas indexer le livre Original complet.

## Standard / Powerlifting

Source : `531_Powerlifting.pdf`, pages PDF 10 à 14.

- le Training Max initial est 90 % du max réel (pages 10-11) ;
- le modèle standard est 5/3/1 sur trois semaines, suivi d'un deload en semaine
  quatre (page 11) ;
- les pourcentages des semaines de travail sont 65/75/85, 70/80/90 et
  75/85/95 ; le deload utilise 40/50/60 (page 11) ;
- le dernier set des semaines de travail est un set de performance, mais le
  deload ne comporte jamais de max reps (pages 12-13) ;
- le modèle alternatif 3/5/1 n'est utilisé que lorsqu'il est sélectionné. Sa
  semaine 3x5 n'est pas poussée en max reps (pages 11-12) ;
- la progression est prévisualisée après le cycle et n'est pas appliquée aux
  prescriptions déjà générées (pages 14-16).

Le blueprint exige que l'ordre des quatre mouvements, les jours, les TM, les
incréments et la politique d'arrondi soient fournis. Le moteur n'invente donc
aucune affectation ni conversion d'incrément.

## Beyond - deux cycles puis deload

Source : `Beyond_531_-_Jim_Wendler.pdf`, pages PDF 9, 11 et 12.

- le TM représente 85 à 90 % du max de salle (page 9) ;
- deux cycles 5/3/1 de trois semaines sont exécutés dos à dos sans deload entre
  eux (page 11) ;
- après le premier cycle, le TM doit augmenter avant toute prescription du
  second cycle (page 11) ;
- le second cycle utilise les TM confirmés ; après les six semaines vient le
  deload, puis un nouveau checkpoint de TM (page 12) ;
- quatre lifts dans sept jours donnent sept semaines calendaires avec le deload ;
  à trois jours, la rotation des quatre lifts allonge la durée calendaire sans
  changer les sept semaines de programmation (page 12).

Le générateur est amendable : sans confirmation du checkpoint intermédiaire, il
retourne uniquement le premier cycle et les décisions prévisualisées. Une valeur
du second cycle différente de la progression confirmée est refusée. Beyond n'est
jamais traduit en Leader ou Anchor.
