import 'package:flutter_test/flutter_test.dart';

import '../../../tool/catalog/catalog_tool.dart' as catalog_tool;

void main() {
  test(
    'all public Cycle variants compile and survive training.db',
    () async {
      final report = await catalog_tool.verifyCatalogCompilation();

      expect(report.variantCount, 37);
      expect(report.failures, isEmpty, reason: report.failures.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
