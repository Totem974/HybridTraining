import 'package:flutter/material.dart';

import '../../cycle_web/application/cycle_web_contract.dart';
import 'forever_web_contract.dart';
import 'forever_web_page.dart';

abstract final class ForeverWebRoute {
  static const path = '/forever';

  static Route<void>? build({
    required RouteSettings settings,
    required ForeverWebApplication application,
    CycleWebApplication? cycleApplication,
  }) {
    final uri = Uri.tryParse(settings.name ?? '');
    if (uri?.path != path) return null;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => ForeverWebPage(
        application: application,
        cycleApplication: cycleApplication,
      ),
    );
  }
}
