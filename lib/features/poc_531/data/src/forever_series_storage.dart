/// Minimal synchronous capability shared by browser and non-Web adapters.
abstract interface class ForeverSeriesStorage {
  String? read(String key);

  void write(String key, String value);
}

/// Non-durable storage used where no platform persistence adapter is selected.
final class MemoryForeverSeriesStorage implements ForeverSeriesStorage {
  MemoryForeverSeriesStorage([Map<String, String>? values])
    : _values = values ?? <String, String>{};

  final Map<String, String> _values;

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;
}

/// Explicit failure adapter used when durable browser storage is unavailable.
///
/// It deliberately never stores values: callers must surface the failure
/// instead of reporting success for data that would disappear on refresh.
final class UnavailableForeverSeriesStorage implements ForeverSeriesStorage {
  const UnavailableForeverSeriesStorage();

  Never _unavailable() => throw StateError(
    'Durable browser storage is unavailable. The Forever series was not saved.',
  );

  @override
  String? read(String key) => _unavailable();

  @override
  void write(String key, String value) => _unavailable();
}

/// Builds a platform store, exposing an explicit failure adapter when merely
/// accessing the capability is denied by browser privacy/security policies.
ForeverSeriesStorage createSeriesStorageWithFallback<T>({
  required T Function() getCapability,
  required ForeverSeriesStorage Function(T capability) createStorage,
}) {
  try {
    return createStorage(getCapability());
  } on Object {
    return const UnavailableForeverSeriesStorage();
  }
}
