import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web manifest stays relative to the deployment base', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, Object?>;

    expect(manifest['start_url'], '.');
    expect(manifest['scope'], '.');
  });

  test('release utilities expose base, port and timeout parameters', () {
    final build = File('tool/build_web_release.ps1').readAsStringSync();
    final preview = File('tool/preview_web.ps1').readAsStringSync();
    final chrome = File('tool/run_chrome_e2e.ps1').readAsStringSync();
    final smoke = File('tool/smoke_web_release.ps1').readAsStringSync();

    expect(build, contains('--base-href'));
    expect(preview, contains(r'[string]$BasePath'));
    expect(preview, contains("'index.html'"));
    expect(chrome, contains(r'[string]$DriverPath'));
    expect(chrome, contains(r'[int]$DriverPort'));
    expect(chrome, contains(r'[int]$TimeoutSeconds'));
    expect(chrome, contains('--driver-port='));
    expect(smoke, contains(r'[string]$ChromeExecutable'));
    expect(smoke, contains(r'[string]$BasePath'));
    expect(smoke, contains(r'[int]$Port'));
    expect(smoke, contains('--dump-dom'));
    expect(smoke, contains('poc/531/generator'));
    expect(smoke, contains('<flutter-view|flt-glass-pane'));
    expect(smoke, contains('data-hybrid-route-ready'));
    expect(smoke, contains('poc-531-generator'));
  });

  test(
    'release utilities reject unsafe deployment base paths',
    () async {
      final root = Directory.current.path;
      final build = await Process.run('powershell', [
        '-NoProfile',
        '-File',
        '$root${Platform.pathSeparator}tool${Platform.pathSeparator}build_web_release.ps1',
        '-BaseHref',
        '/../',
      ]);
      final preview = await Process.run('powershell', [
        '-NoProfile',
        '-File',
        '$root${Platform.pathSeparator}tool${Platform.pathSeparator}preview_web.ps1',
        '-BasePath',
        '/bad?path/',
      ]);

      expect(build.exitCode, isNot(0));
      expect(preview.exitCode, isNot(0));
    },
    skip: !Platform.isWindows,
  );
}
