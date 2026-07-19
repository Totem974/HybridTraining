# Migrations and backups

Database version 5 supports tested v1→v5, v2→v5, v3→v5, and v4→v5 upgrades.
Migrations preserve legacy rows, convert resumable v3 execution into the unified
runtime where possible, add v5 canonical metadata and generic prescriptions, and
roll back atomically on interruption. Old tables remain until a later migration
can remove them without compromising restore compatibility.

Native backup schema v5 exports canonical and compatibility tables. V1–v4 backups
remain accepted: absent later tables normalize to empty collections, validation
and a detailed dry run happen before writes, and apply replaces data in one
transaction. Invalid versions or rows produce an error report rather than silent
loss.
