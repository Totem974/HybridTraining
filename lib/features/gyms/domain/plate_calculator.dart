class PlateInventoryItem {
  const PlateInventoryItem({required this.weight, required this.quantity})
    : assert(weight > 0),
      assert(quantity >= 0);

  final double weight;
  final int quantity;
}

class PlateLoad {
  const PlateLoad({
    required this.target,
    required this.barWeight,
    required this.perSide,
  });

  final double target;
  final double barWeight;
  final List<double> perSide;
}

class PlateCalculator {
  const PlateCalculator();

  PlateLoad? exact({
    required double target,
    required double barWeight,
    required List<PlateInventoryItem> inventory,
  }) {
    if (target < barWeight || barWeight <= 0) return null;
    final remaining = target - barWeight;
    if (!_isWhole(remaining / 2)) return null;
    final perSideTarget = _scaled(remaining / 2);
    final sorted = [...inventory]..sort((a, b) => b.weight.compareTo(a.weight));
    final result = <double>[];

    bool search(int index, int remainingWeight) {
      if (remainingWeight == 0) return true;
      if (index == sorted.length || remainingWeight < 0) return false;
      final item = sorted[index];
      final weight = _scaled(item.weight);
      final availablePairs = item.quantity ~/ 2;
      final maximum = availablePairs < remainingWeight ~/ weight
          ? availablePairs
          : remainingWeight ~/ weight;
      for (var count = maximum; count >= 0; count--) {
        for (var plate = 0; plate < count; plate++) {
          result.add(item.weight);
        }
        if (search(index + 1, remainingWeight - count * weight)) return true;
        if (count > 0) result.removeRange(result.length - count, result.length);
      }
      return false;
    }

    if (!search(0, perSideTarget)) return null;
    return PlateLoad(target: target, barWeight: barWeight, perSide: result);
  }

  int _scaled(double value) => (value * 1000).round();

  bool _isWhole(double value) =>
      (value * 1000 - (value * 1000).round()).abs() < 0.0001;
}
