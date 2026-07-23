import '../../cycle_generation/domain/cycle_contract.dart';

/// Resolves catalog-only set parameters into compiler-ready prescriptions.
///
/// The cycle compiler and the public response only consume one ordinary
/// [PrescribedSetDefinition] per generated set. Multiplicity is therefore
/// expanded here, before a source component becomes a plan component.
final class CatalogSetParameterResolver {
  const CatalogSetParameterResolver();

  BlockDefinition resolveBlock(
    BlockDefinition block, {
    Map<String, Object?> optionValues = const {},
    Map<String, Object?> optionDefaults = const {},
  }) {
    final sets = [
      for (final definition in block.sets)
        ...resolveSet(
          definition,
          optionValues: optionValues,
          optionDefaults: optionDefaults,
        ),
    ];
    return BlockDefinition(
      id: block.id,
      role: block.role,
      sets: List.unmodifiable(sets),
      movementId: block.movementId,
      mainWorkSemantics: block.mainWorkSemantics,
    );
  }

  List<PrescribedSetDefinition> resolveSet(
    PrescribedSetDefinition definition, {
    Map<String, Object?> optionValues = const {},
    Map<String, Object?> optionDefaults = const {},
  }) {
    final repetitions = switch (definition.repetitions) {
      ParameterizedFixedRepetitions(
        :final parameterId,
        :final defaultValue,
        :final minimum,
        :final maximum,
      ) =>
        FixedRepetitions(
          _resolveInteger(
            parameterId: parameterId,
            defaultValue: defaultValue,
            minimum: minimum,
            maximum: maximum,
            optionValues: optionValues,
            optionDefaults: optionDefaults,
          ),
        ),
      final value => value,
    };
    final count = switch (definition.multiplicity) {
      FixedSetMultiplicity(:final count) => count,
      ParameterizedSetMultiplicity(
        :final parameterId,
        :final defaultValue,
        :final minimum,
        :final maximum,
      ) =>
        _resolveInteger(
          parameterId: parameterId,
          defaultValue: defaultValue,
          minimum: minimum,
          maximum: maximum,
          optionValues: optionValues,
          optionDefaults: optionDefaults,
        ),
    };
    if (count <= 0) {
      throw const FormatException('Set multiplicity must be positive.');
    }
    return List.unmodifiable([
      for (var index = 0; index < count; index++)
        PrescribedSetDefinition(
          repetitions: repetitions,
          load: definition.load,
          execution: definition.execution,
          runtimeGates: definition.runtimeGates,
        ),
    ]);
  }

  int _resolveInteger({
    required String parameterId,
    required int defaultValue,
    required int minimum,
    required int maximum,
    required Map<String, Object?> optionValues,
    required Map<String, Object?> optionDefaults,
  }) {
    final candidate = optionValues.containsKey(parameterId)
        ? optionValues[parameterId]
        : optionDefaults.containsKey(parameterId)
        ? optionDefaults[parameterId]
        : defaultValue;
    if (candidate is! int) {
      throw FormatException('$parameterId must be an integer.');
    }
    if (candidate < minimum || candidate > maximum) {
      throw FormatException('$parameterId must be from $minimum to $maximum.');
    }
    return candidate;
  }
}
