import 'package:flutter/material.dart';
import 'package:hybrid_training/app/bootstrap/app_environment.dart';

class HybridTrainingApp extends StatelessWidget {
  const HybridTrainingApp({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: environment.detailedLogging,
      title: environment.displayName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF42566F)),
        useMaterial3: true,
      ),
      home: FoundationScreen(environment: environment),
    );
  }
}

class FoundationScreen extends StatelessWidget {
  const FoundationScreen({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(environment.displayName)),
      body: const Center(child: Text('Base0 foundation')),
    );
  }
}
