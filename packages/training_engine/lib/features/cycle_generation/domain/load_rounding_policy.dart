/// Selects how a calculated load is aligned to the configured increment.
///
/// [nearest] is the historical HybridTraining behavior. [up] preserves the
/// source calculator behavior for catalog variants that explicitly request it.
enum LoadRoundingPolicy { nearest, up }
