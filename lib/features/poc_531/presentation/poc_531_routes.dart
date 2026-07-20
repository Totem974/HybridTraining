import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hybrid_training/features/poc_531/domain/core.dart' as core;
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_core_adapter.dart';
import 'package:hybrid_training/features/poc_531/presentation/generator/poc_531_generator_page.dart';

Route<dynamic>? buildPoc531Route(RouteSettings settings) {
  final uri = Uri.tryParse(settings.name ?? '');
  final path = uri?.path ?? settings.name;
  final arguments = settings.arguments is Map<String, Object?>
      ? settings.arguments! as Map<String, Object?>
      : null;
  final queryConfiguration = _configurationFromQuery(uri);
  final initial = <String, Object?>{
    ...?arguments,
    if (uri?.queryParameters['mode'] case final mode?)
      'mode': mode == 'cycle' ? 'classic' : mode,
    ...?queryConfiguration,
  };
  switch (path) {
    case '/poc/531':
    case '/poc/531/generator':
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Poc531GeneratorPage(
          core: const DomainPoc531GeneratorCore(),
          initialConfiguration: initial.isEmpty ? null : initial,
        ),
      );
    default:
      if (path?.startsWith('/poc/531/program/') ?? false) {
        final id = path!.substring('/poc/531/program/'.length);
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
              ...initial,
            },
          ),
        );
      }
      return null;
  }
}

Map<String, Object?>? _configurationFromQuery(Uri? uri) {
  final payload = uri?.queryParameters['configuration'];
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map ? Map<String, Object?>.from(decoded) : null;
  } on FormatException {
    return null;
  }
}
