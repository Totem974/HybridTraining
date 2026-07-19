# Canonical program catalog

`ProgramLibraryRepository` is the only active catalog contract. Its validator
rejects duplicate identities, missing sources or versions, unavailable unreviewed
rules, missing generators, incompatible frequencies, and impossible transitions.
Legacy persistent IDs are retained or mapped through explicit aliases.

Executable presets are:

- `powerlifting-standard-4-week-v1`
- `beyond-two-cycles-deload-v1`
- `forever-original-fsl-v1`
- `forever-beginner-prep-school-v1`

All other indexed Powerlifting, Beyond, Forever, Original, component, and protocol
entries are documentary unless their implementation status and availability say
otherwise. A documentary or `NEEDS_REVIEW` entry cannot resolve to a generator.
