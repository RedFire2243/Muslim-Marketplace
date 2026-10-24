import 'package:shared_preferences/shared_preferences.dart';

/// Minimal persistent string storage, so persistence can be swapped in tests.
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// Device storage: localStorage on the web, platform preferences elsewhere.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._prefs);
  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    final ok = await _prefs.setString(key, value);
    if (!ok) throw StateError('Could not save $key');
  }

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// In-memory storage for tests.
class MemoryStore implements KeyValueStore {
  MemoryStore([Map<String, String>? initial]) : values = {...?initial};
  final Map<String, String> values;

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}
