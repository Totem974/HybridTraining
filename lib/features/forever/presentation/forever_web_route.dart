import 'package:flutter/material.dart';

import 'forever_web_contract.dart';
import 'forever_web_page.dart';

abstract final class ForeverWebRoute {
  static const path = '/forever';

  static Route<void>? build({
    required RouteSettings settings,
    required ForeverWebApplication application,
  }) {
    final uri = Uri.tryParse(settings.name ?? '');
    if (uri?.path != path) return null;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => ForeverWebPage(application: application),
    );
  }
}
