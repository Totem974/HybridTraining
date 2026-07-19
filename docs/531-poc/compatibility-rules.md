# Compatibility rules

Compatibility is validated by the pure Core before recommendation or generation.
The UI only renders structured validation issues.

## Global invariants

- All four main lifts must have a positive, valid input.
- Rep-max inputs require a positive repetition count.
- Training Max ratio must be greater than zero and no greater than one.
- Selected weekdays must be unique and match the selected frequency.
- Rounding increment and equipment weights must be positive.
- The selected generation must match the executable program definition.
- Documentation-only, ambiguous, unavailable, or unregistered definitions cannot
  be generated.
- A Powerlifting supplement cannot be selected as a primary generation.

## Generation boundaries

- Original uses its reviewed canonical cycle/adapter only.
- Beyond uses the reviewed two-cycle strategy and explicit TM checkpoint; it is
  never represented as Leader/Anchor.
- Forever uses typed blocks, Leader/Anchor transitions, and 7th Week purposes
  from its blueprint. Missing confirmed TM inputs are reported when required.
- Beginner Prep School remains a Forever program with its distinct schedule and
  movement structure.

## Catalogue ambiguity

Catalogue classification does not make a row executable. An executable template
must have complete reviewed rules and exactly one registered Core strategy. Any
missing prescription, phase relationship, frequency, duration, or provenance is
reported as a non-executable reason and blocks only that entry.

