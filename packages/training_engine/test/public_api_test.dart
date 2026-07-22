import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  test('publishes the shared Cycle and Forever engine entry points', () {
    const compiler = CycleCompilerImpl();
    expect(compiler, isA<CycleCompiler>());
    expect(<ForeverComposer>[], isEmpty);
  });
}
