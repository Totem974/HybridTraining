# Audit du catalogue canonique des programmes - 2026-07-18

## Résultat

L'audit indexe toutes les entrées du sommaire Forever sans transformer leurs
titres en presets. Beginner Prep School est le seul nouveau candidat marqué
`READY_TO_IMPLEMENT`, après revue textuelle et visuelle des pages PDF 50 à 56.

## Sources consultées

- édition locale protégée *5/3/1 Forever*, 282 pages ;
- édition locale protégée *Beyond 5/3/1* pour les lignages FSL, BBB, Joker Sets
  et 5's Progression ;
- index Original existant, conservé prudent faute de pagination originale revue ;
- catalogues et modèle de lignage présents à la base `51398a1`.

Aucun PDF, texte substantiel, binaire, capture, secret ou fichier de `.SOURCE/`
n'est ajouté au suivi Git.

## Constats

1. Les catalogues antérieurs confondaient parfois présence au sommaire et
   maturité générative. La nouvelle matrice rend l'incomplétude explicite.
2. FSL, BBB, BBS, SSL, 5's Pro, Joker Sets et Widowmaker sont d'abord des
   composants. Certaines sections forment des templates, mais leur nom seul ne
   suffit pas à prouver un programme complet.
3. Beginner Prep School prescrit bien public, fréquence, alternance, deux lifts
   par séance, main/supplemental, assistance, athletic work, conditioning, TM,
   progression et sortie. Toutes ces règles sont `RULES_REVIEWED`.
4. La progression BPS autorise une hausse plus faible, une répétition de cycle
   ou des microcharges ; elle ne doit pas être réduite à une hausse automatique.
5. Le rôle BPS « Always a Leader template » est situé au début de la page PDF 57,
   immédiatement avant la section BBB, et appartient à la conclusion BPS.

## Recommandations

1. Coder d'abord `forever.beginner-prep-school.v1`.
2. Préparer ensuite `forever.original-531-fsl.v1` après revue finale du
   conditioning et de la transition.
3. Développer auparavant les composants TM, main set, FSL/SSL, alternance A/B,
   assistance catégorisée, jumps/throws, conditioning, provenance et blocs.

## Limites

- Les candidats autres que BPS et les deux révisions Original restent `INDEXED`.
- L'origine exacte de Widowmaker reste `NEEDS_REVIEW`.
- Les révisions historiques Original ne reçoivent aucune page inventée.
- Aucun état d'une autre branche n'a été incorporé à la maturité d'implémentation.

