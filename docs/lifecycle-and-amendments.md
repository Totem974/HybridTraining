# Lifecycle and amendments

UI-independent use cases cover plan creation, amendment preview/apply, program
switch preview/apply, session reschedule/skip/abandon, workout completion,
cycle/block/plan completion, TM decisions, lifecycle advancement, next-plan
creation, and backup export/simulation/apply.

An amendment regenerates future work only. Completed sessions, active work unless
explicitly abandoned, actual results, records, and historical TM rows are
preserved. Preview reports retained, cancelled, regenerated, rescheduled, TM, and
prescription changes. Apply requires confirmation, writes version/reason/rule/date
and before/after/diff snapshots, and runs atomically.

Lifecycle advancement derives session, cycle, block, protocol/test activation,
TM-decision requirement, and plan completion from persisted state. It never
silently preconfirms a future TM.
