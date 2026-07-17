class LoadRounder {
  const LoadRounder({required this.increment}) : assert(increment > 0);

  final double increment;

  double nearest(double load) => (load / increment).round() * increment;
}
