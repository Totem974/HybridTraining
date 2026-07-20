import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'PowerShell preview serves SPA fallback without escaping its content root',
    () async {
      final workspace = Directory.current;
      final fixtureParent = await Directory.systemTemp.createTemp(
        'hybrid-web-preview-',
      );
      final fixture = Directory(
        '${fixtureParent.path}${Platform.pathSeparator}site',
      )..createSync();
      final sibling = File(
        '${fixtureParent.path}${Platform.pathSeparator}secret.txt',
      )..writeAsStringSync('must-not-be-served');
      File(
        '${fixture.path}${Platform.pathSeparator}index.html',
      ).writeAsStringSync('spa-index');
      File(
        '${fixture.path}${Platform.pathSeparator}asset.txt',
      ).writeAsStringSync('static-asset');

      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      final process = await Process.start('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        '${workspace.path}${Platform.pathSeparator}tool${Platform.pathSeparator}preview_web.ps1',
        '-Port',
        '$port',
        '-BasePath',
        '/hybrid/',
        '-ContentRoot',
        fixture.path,
      ]);

      addTearDown(() async {
        process.kill();
        try {
          await process.exitCode.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          await Process.run('taskkill.exe', [
            '/PID',
            '${process.pid}',
            '/T',
            '/F',
          ]);
          await process.exitCode.timeout(const Duration(seconds: 2));
        }
        if (sibling.existsSync()) sibling.deleteSync();
        if (fixtureParent.existsSync()) {
          fixtureParent.deleteSync(recursive: true);
        }
      });

      final client = HttpClient();
      addTearDown(client.close);
      Future<HttpClientResponse> get(String path) async {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port$path'),
        );
        return request.close();
      }

      HttpClientResponse? root;
      for (var attempt = 0; attempt < 30 && root == null; attempt++) {
        try {
          root = await get('/hybrid/');
        } on SocketException {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      expect(root, isNotNull, reason: 'preview server did not become ready');
      expect(await utf8.decodeStream(root!), 'spa-index');

      final asset = await get('/hybrid/asset.txt');
      expect(asset.statusCode, HttpStatus.ok);
      expect(await utf8.decodeStream(asset), 'static-asset');

      final deepLink = await get('/hybrid/poc/531/generator');
      expect(deepLink.statusCode, HttpStatus.ok);
      expect(await utf8.decodeStream(deepLink), 'spa-index');

      final outsideBase = await get('/asset.txt');
      expect(outsideBase.statusCode, HttpStatus.notFound);
      await outsideBase.drain<void>();

      final traversal = await get('/hybrid/%2e%2e/secret.txt');
      expect(traversal.statusCode, HttpStatus.notFound);
      expect(await utf8.decodeStream(traversal), isNot('must-not-be-served'));

      final rawSocket = await Socket.connect('127.0.0.1', port);
      rawSocket.write(
        'GET /hybrid/%2e%2e/secret.txt HTTP/1.1\r\n'
        'Host: 127.0.0.1\r\nConnection: close\r\n\r\n',
      );
      final rawResponse = await utf8.decoder
          .bind(rawSocket)
          .join()
          .timeout(const Duration(seconds: 2));
      expect(rawResponse, startsWith('HTTP/1.1 404'));
      expect(rawResponse, isNot(contains('must-not-be-served')));
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 15)),
  );
}
