import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/presentation/program_library_screen.dart';

void main() {
  Future<void> pumpLibrary(WidgetTester tester, {double scale = 1}) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const ProgramLibraryScreen(mode: ProgramLibraryMode.select),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    '390x844 library supports tabs, search, detail and selection policy',
    (tester) async {
      await pumpLibrary(tester);
      expect(find.text('Programmes'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('program-search')),
        'awesome',
      );
      await tester.pump();
      expect(find.text('Full Body (1000% Awesome)'), findsOneWidget);
      await tester.tap(find.text('Full Body (1000% Awesome)'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('select-program')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large font has no overflow', (tester) async {
    await pumpLibrary(tester, scale: 1.8);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Composants'));
    await tester.pumpAndSettle();
    expect(find.text('First Set Last'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Beginner Prep School can be selected outside onboarding', (
    tester,
  ) async {
    await pumpLibrary(tester);
    await tester.enterText(
      find.byKey(const Key('program-search')),
      'Beginner Prep School',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('entry-preset-forever-beginner-prep-school')),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('select-program')),
    );
    expect(button.onPressed, isNotNull);
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
