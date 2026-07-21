import 'cycle_web_contract.dart';

abstract interface class CycleWebDraftRepository {
  Future<CycleEditorState?> load();
  Future<void> save(CycleEditorState state);
}
