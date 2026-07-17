enum AppEnvironment {
  dev(displayName: 'Hybrid 5/3/1 Dev', detailedLogging: true),
  prod(displayName: 'Hybrid 5/3/1', detailedLogging: false);

  const AppEnvironment({
    required this.displayName,
    required this.detailedLogging,
  });

  final String displayName;
  final bool detailedLogging;
}
