import 'package:flutter/material.dart';
import 'package:hybrid_training/features/poc_531/domain/core.dart' as core;
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_core_adapter.dart';
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_page.dart';

Route<dynamic>? buildPoc531Route(RouteSettings settings) {
  switch (settings.name) {
    case '/poc/531':
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
    default:
      if (settings.name?.startsWith('/poc/531/program/') ?? false) {
        final id = settings.name!.substring('/poc/531/program/'.length);
        final definition = core.getProgramDefinition(id);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Poc531GeneratorPage(
            core: const DomainPoc531GeneratorCore(),
            initialConfiguration: {
              'mode': definition?.generation == core.Generation.forever
                  ? 'forever'
                  : 'classic',
              if (definition?.generation == core.Generation.forever)
                'foreverTemplateId': definition?.id ?? id,
            },
          ),
        );
      }
      return null;
  }
}
