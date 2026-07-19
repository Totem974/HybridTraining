import 'package:flutter/material.dart';
import 'package:hybrid_training/features/poc_531/application/configuration_form_mapper.dart';
import 'package:hybrid_training/features/poc_531/domain/core.dart' as core;
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_core_adapter.dart';
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_page.dart';
import 'package:hybrid_training/features/poc_531/presentation/onboarding/poc_531_onboarding_page.dart';
import 'package:hybrid_training/features/poc_531/presentation/poc_531_landing_page.dart';

Route<dynamic>? buildPoc531Route(RouteSettings settings) {
  switch (settings.name) {
    case '/poc/531':
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Poc531LandingPage(),
      );
    case '/poc/531/generator':
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Poc531GeneratorPage(
          core: const DomainPoc531GeneratorCore(),
          initialConfiguration: settings.arguments is Map<String, Object?>
              ? settings.arguments! as Map<String, Object?>
              : null,
        ),
      );
    case '/poc/531/onboarding':
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => Poc531OnboardingPage(
          onProgramSelected: (configuration) {
            Navigator.of(context).pushReplacementNamed(
              '/poc/531/generator',
              arguments: programConfigurationToForm(configuration),
            );
          },
        ),
      );
    default:
      if (settings.name?.startsWith('/poc/531/program/') ?? false) {
        final id = settings.name!.substring('/poc/531/program/'.length);
        final definition = core.getProgramDefinition(id);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Poc531GeneratorPage(
            core: const DomainPoc531GeneratorCore(),
            initialConfiguration: {
              'programId': definition?.id ?? id,
              if (definition?.generation != null)
                'generation': definition!.generation!.name,
              'status': 'all',
            },
          ),
        );
      }
      return null;
  }
}
