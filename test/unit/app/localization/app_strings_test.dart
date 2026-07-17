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
}
