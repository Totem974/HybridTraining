import 'package:flutter_test/flutter_test.dart';

import '../../../tool/catalog/catalog_tool.dart' as catalog_tool;

void main() {
  test(
    'all 19 published Cycle variants compile and survive training.db',
    () async {
      final report = await catalog_tool.verifyCatalogCompilation();

      expect(report.variantCount, 19);
      expect(report.failures, isEmpty, reason: report.failures.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
