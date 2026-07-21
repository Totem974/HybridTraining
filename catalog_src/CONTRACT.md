# Frozen catalogue document contract (schema version 1)

Every JSON file has exactly `schemaVersion`, `kind`, and the array named by its
kind. Unknown keys are rejected by the catalogue lint.

## Common records

- Labels: `{ "en": string, "fr": string }`.
- Source reference: `{ "ruleId": string, "work": string, "edition": string,
  "section": string, "reviewStatus": "reviewed" | "referenceAppObserved" }`.
- Stable reference: `{ "id": string, "revision": positive integer }`.
- Parameter: `id`, `type`, `scope`, `default`, `minimum`, `maximum`, `step`,
  `allowedValues`, `visibleWhen`, `enabledWhen`, `requiredWhen`.
- Parameter types: `boolean`, `enumeration`, `integer`, `percentage`, `weight`,
  `movement`, `exercise`, `prescription`.
- Scopes: `global`, `perMovement`, `perSession`.
- Conditions are objects with one `type` from `always`, `present`, `equals`,
  `not`, `all`, `any`, `in`, `range`; their operands are explicit JSON fields.

## Document kinds

`inventory` contains `entries`: `id`, `generation`, `classification`, `title`,
optional `cycleTemplateId`, and `sourceRuleIds`. Classification is one of
`cycleTemplate`, `sharedComponent`, `rule`, `schedule`, `protocol`,
`transition`, `documentation`.

`sources` contains `sources`, each using the complete source-reference shape.

`components` contains `components`: `id`, `revision`, `role`, `labels`,
`sourceRuleIds`, `parameterSchemaIds`, `constraints`, `compatibilities`, and a
strict primitive `block` payload.

`schedules` contains `schedules`: `id`, `revision`, `labels`, `sourceRuleIds`,
`type` (`fixed`, `rotating`, `multiMovement`, `finite`), and ordered `sessions`.

`templates` contains `templates`: `id`, `revision`, `labels`, `sourceRuleIds`,
and `variants`. Every variant has `id`, `revision`, `labels`, `sourceRuleIds`,
ordered `weekPlans` (`weekNumber` plus stable `componentIds`),
`optionSchemaId`, `scheduleIds`, optional `assistancePlanIds`, optional
`conditioningDefinitionIds`, `compatibilities`, and `validExample`.
Finite or multi-phase Cycle programs additionally use ordered `phases`, each
containing `id`, `repeatCount`, and `weekPlans`. A simple cycle has `weekPlans`
and no `phases`; a finite program has `phases` and no top-level `weekPlans`.

`optionSchemas` contains `optionSchemas`: `id`, `revision`, `sourceRuleIds`, and
ordered `parameters` using the common parameter shape.

`movements`, `exercises`, `assistancePlans`, and `conditioningDefinitions`
contain an array with that exact name. Records have `id`, `revision`, `labels`,
`sourceRuleIds`, typed capabilities/slots/prescriptions as appropriate, and no
free-form executable expression.

Files may contain one document only. Templates never inline shared components,
schedules, exercises, assistance plans, or conditioning definitions.
