import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/gyms/domain/plate_calculator.dart';

void main() {
  const calculator = PlateCalculator();

  test('finds an exact load using only available plate pairs', () {
    final result = calculator.exact(
      target: 100,
      barWeight: 20,
      inventory: const [
        PlateInventoryItem(weight: 20, quantity: 2),
        PlateInventoryItem(weight: 10, quantity: 2),
        PlateInventoryItem(weight: 5, quantity: 2),
        PlateInventoryItem(weight: 2.5, quantity: 4),
      ],
    );

    expect(result, isNotNull);
    expect(result!.perSide.fold(0.0, (sum, plate) => sum + plate), 40);
  });

  test('returns null when the gym inventory cannot build the load', () {
    final result = calculator.exact(
      target: 102.5,
      barWeight: 20,
      inventory: const [PlateInventoryItem(weight: 20, quantity: 2)],
    );

    expect(result, isNull);
  });
}
