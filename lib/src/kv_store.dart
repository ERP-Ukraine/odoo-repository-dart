/// Persistent key-value storage for offline work and performance.
abstract class OdooKv {
  /// All the keys in the storage.
  ///
  /// The keys are sorted alphabetically in ascending order.
  Iterable<dynamic> get keys;

  /// Saves the [key] - [value] pair.
  Future<void> put(dynamic key, dynamic value);

  /// Deletes the given [key] from the storage.
  ///
  /// If it does not exist, nothing happens.
  Future<void> delete(dynamic key);

  /// Returns the value associated with the given [key]. If the key does not
  /// exist, `null` is returned.
  ///
  /// If [defaultValue] is specified, it is returned in case the key does not
  /// exist.
  dynamic get(dynamic key, {dynamic defaultValue});

  /// Initializes the storage.
  Future<void> init();

  /// Closes the storage.
  Future<void> close();
}
