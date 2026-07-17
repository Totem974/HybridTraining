import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';
import 'package:hybrid_training/app/hybrid_training_app.dart';

void main() {
  testWidgets('shows the Base0 foundation in the dev environment', (
    tester,
  ) async {
    await tester.pumpWidget(
      const HybridTrainingApp(environment: AppEnvironment.dev),
    );

    expect(find.text('Hybrid 5/3/1 Dev'), findsOneWidget);
    expect(find.text('Base0 foundation'), findsOneWidget);
  });

  testWidgets('hides the debug banner in production', (tester) async {
    await tester.pumpWidget(
      const HybridTrainingApp(environment: AppEnvironment.prod),
    );

    expect(tester.widgetList(find.byType(Banner)), isEmpty);
  });
}
