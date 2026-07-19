# Index de lignage des programmes 5/3/1

## Règle d'identité

Un `concept id` reste stable entre générations. Chaque publication ajoute une
révision ; elle n'efface ni l'origine ni les prescriptions antérieures. Un preset
référence une révision précise et ne mélange jamais implicitement plusieurs livres.

| Concept id | Origine établie | Révisions indexées | Statut dans Forever | Type |
|---|---|---|---|---|
| `program.original-531` | Original | Original ; Forever PDF 176-179 | programme/révision | complet |
| `supplemental.fsl` | Beyond | Beyond multiple sets/rest-pause/paused ; Forever PDF 70-85 et combinaison PDF 180 | supplemental | composant |
| `supplemental.bbb` | Original | Original ; Beyond variants/challenges ; Forever PDF 57-69 | leader | composant et templates |
| `supplemental.bbs` | Forever | Forever PDF 146-154 | leader | composant et templates |
| `supplemental.ssl` | Forever | Forever PDF 141-143 ; usage BPS PDF 52 | supplemental | composant |
| `component.5s-pro` | Beyond (`5's Progression`) | Beyond ; Forever PDF 230-236 ; usage BPS | main work | composant |
| `component.joker-sets` | Beyond | Beyond Joker/Joker Supersets ; mentions Forever | anchor compatible à confirmer | composant |
| `component.widowmaker` | NEEDS_REVIEW | Forever, notamment Widowmaker Circuit | supplemental | composant |
| `program.beginner-prep-school` | Forever | Forever PDF 50-56 | toujours leader | complet/preset revu |
| `program.1000-percent-awesome` | Forever | Forever PDF 86-88 | NEEDS_REVIEW | candidat complet |
| `program.god-is-a-beast` | Forever | Forever PDF 120-126 | NEEDS_REVIEW | candidat complet |
| `program.coffinworm` | Forever | Forever PDF 137-140 | NEEDS_REVIEW | candidat complet |
| `program.pervertor` | Forever | Forever PDF 172-175 | NEEDS_REVIEW | candidat complet |
| `program.leviathan` | Forever | Forever PDF 210-212 | NEEDS_REVIEW | candidat complet |
| `program.widowmaker-circuit` | Forever | Forever PDF 237-239 | NEEDS_REVIEW | candidat complet distinct du composant |
| `program.krypteia` | Forever | Forever PDF 245-254 | NEEDS_REVIEW | programme/challenge candidat |

## Relations structurantes

- `program.beginner-prep-school` utilise `component.5s-pro`,
  `supplemental.fsl` et, pour un lift faible à TM 85 %, `supplemental.ssl`.
- `program.original-531-fsl` est une composition versionnée, pas un renommage de
  FSL ni d'Original 5/3/1.
- BBB, FSL, SSL, BBS, 5's Pro, Joker Sets et Widowmaker ne doivent pas recevoir
  automatiquement le type `programme complet`.
- Les entrées `Rhodes 5x5/3/1` et `Portal's 5x5/3/1` sont des révisions nommées
  de la famille `program.5x5-531`, pas des alias de traduction.
- Original, Beyond et Forever sont des générations du même système ; `Forever`
  est un axe de révision et non l'origine automatique de chaque concept.

## Identifiants de presets admissibles

| Preset id | Composition | État |
|---|---|---|
| `forever.beginner-prep-school.v1` | BPS complet PDF 50-57 | READY_TO_IMPLEMENT |
| `forever.original-531-fsl.v1` | Original 3/5/1 + FSL 5x5 PDF 180-182 | BLOCKED_DOCUMENTATION |
| `forever.original-531.v1` | Original Forever PDF 176-179 | BLOCKED_DOCUMENTATION |

