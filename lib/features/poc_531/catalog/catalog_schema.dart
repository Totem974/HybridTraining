import '../domain/models.dart';

class CatalogRecord {
  const CatalogRecord({
    required this.definition,
    required this.nature,
    required this.ambiguity,
  });

  final ProgramDefinition definition;
  final String nature;
  final bool ambiguity;
}
