import '../domain/workspace_program.dart';

abstract interface class WorkspaceProgramRepository {
  Future<void> save(WorkspaceProgram program);
  Future<WorkspaceProgram> load(String id);
}
