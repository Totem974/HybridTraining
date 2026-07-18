import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/app/localization/app_strings.dart';

void main() {
  test(
    'keeps internal lift ids independent from French and English labels',
    () {
      const french = AppStrings();
      const english = AppStrings.english();

      expect(french.lift('benchPress'), 'Développé couché');
      expect(english.lift('benchPress'), 'Bench press');
      expect(french.lift('customStableId'), 'customStableId');
    },
  );

  test('localizes program identity without changing its stable key', () {
    const french = AppStrings();
    const english = AppStrings.english();
    const key = 'program.forever_original_fsl';

    expect(
      french.programLabel(key),
      '5/3/1 Forever — Original + First Set Last',
    );
    expect(english.programLabel(key), french.programLabel(key));
    expect(french.rulesReviewed, 'Règles vérifiées');
    expect(english.rulesReviewed, 'Rules reviewed');
  });

  test('describes the historical preset only as compatibility', () {
    const french = AppStrings();
    expect(
      french.compatibilityPresetNotice,
      'Preset de compatibilité disponible pendant la construction du moteur Forever.',
    );
    expect(
      french.compatibilityPresetNotice.toLowerCase(),
      isNot(contains('officiel')),
    );
    expect(
      french.compatibilityPresetNotice.toLowerCase(),
      isNot(contains('recommand')),
    );
  });
}
