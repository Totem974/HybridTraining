import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final compilerFile = File(
    'lib/features/cycle_generation/domain/cycle_compiler_impl.dart',
  );
  final domainDirectories = [
    Directory('lib/features/training_catalog/domain'),
    Directory('lib/features/cycle_generation/domain'),
  ];

  test('cycle compiler contains no recipe or template-id branching', () {
    final source = compilerFile.readAsStringSync();

    expect(source.toLowerCase(), isNot(contains('boring but big')));
    expect(source.toLowerCase(), isNot(matches(RegExp(r'\bbbb\b'))));
    expect(source.toLowerCase(), isNot(matches(RegExp(r'\bppl\b'))));
    expect(
      source,
      isNot(matches(RegExp(r'(?:if|switch)\s*\([^)]*templateId'))),
    );
    expect(source, isNot(matches(RegExp(r'templateId\s*(?:==|!=)'))));
  });

  test('new domain stays independent from SQLite, Flutter and legacy', () {
    for (final directory in domainDirectories) {
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        expect(
          source,
          isNot(matches(RegExp(r'''import\s+['"][^'"]*(?:sqflite|sqlite)'''))),
          reason: entity.path,
        );
        expect(
          source,
          isNot(matches(RegExp(r'''import\s+['"]package:flutter/'''))),
          reason: entity.path,
        );
        expect(
          source,
          isNot(matches(RegExp(r'''import\s+['"][^'"]*(?:legacy|poc_531)'''))),
          reason: entity.path,
        );
      }
    }
  });
}
