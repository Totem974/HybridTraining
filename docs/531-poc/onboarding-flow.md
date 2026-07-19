# Onboarding flow

The POC onboarding is a reversible stepper that builds one typed `UserProfile`
and one set of `LiftInput` values shared with the generator.

1. Welcome and scope.
2. Primary goal, including Powerlifting only as an optional extension.
3. Experience level.
4. Weekly availability and approximate session duration.
5. Available equipment.
6. Conditioning preference or tolerance.
7. Four lift inputs using one-rep max, Training Max, or load/repetitions.
8. Original, Beyond, Forever, or “recommend for me”.
9. Legacy-program permission.
10. Ranked recommendations with reasons, constraints, trade-offs, status,
    frequency, level, and Leader/Anchor requirements.

Selecting a recommendation creates a versioned `ProgramConfiguration` and passes
that exact value to the generator route. Recommendation, compatibility, Training
Max derivation, and generation all call the same Core facade. Back navigation
retains previous values without hidden recalculation.

