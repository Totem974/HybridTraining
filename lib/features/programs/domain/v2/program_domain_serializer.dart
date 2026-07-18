import 'program_domain.dart';

class ProgramIdSerializer {
  const ProgramIdSerializer();
  String conceptId(ProgramConceptId id) => id.value;
  String revisionId(ProgramRevisionId id) => id.value;
  String blueprintId(ProgramBlueprintId id) => id.value;
  ProgramConceptId parseConceptId(String value) => ProgramConceptId(value);
  ProgramRevisionId parseRevisionId(String value) => ProgramRevisionId(value);
  ProgramBlueprintId parseBlueprintId(String value) =>
      ProgramBlueprintId(value);
}
