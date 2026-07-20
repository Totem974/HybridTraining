// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'forever_series_storage.dart';

ForeverSeriesStorage createSeriesStorage() => createSeriesStorageWithFallback(
  getCapability: () => html.window.localStorage,
  createStorage: _BrowserForeverSeriesStorage.new,
);

final class _BrowserForeverSeriesStorage implements ForeverSeriesStorage {
  const _BrowserForeverSeriesStorage(this._storage);

  final html.Storage _storage;

  @override
  String? read(String key) => _storage[key];

  @override
  void write(String key, String value) => _storage[key] = value;
}
