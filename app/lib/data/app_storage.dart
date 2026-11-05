import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/scene.dart';
import 'models.dart';
import 'pairing_link.dart';

/// Holds the access token. Kept apart from ordinary preferences so it can live in the
/// platform keystore instead of a plain file.
abstract class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class KeystoreSecretStore implements SecretStore {
  const KeystoreSecretStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Everything the app remembers between launches.
class AppStorage {
  AppStorage(this._prefs, this._secrets);

  static Future<AppStorage> open({SecretStore secrets = const KeystoreSecretStore()}) async =>
      AppStorage(await SharedPreferences.getInstance(), secrets);

  static const _linkUrl = 'link.url';
  static const _linkToken = 'link.token';
  static const _selectedMonitor = 'monitor.selected';
  static const _scenes = 'scenes';
  static const _labels = 'labels';
  static const _themeMode = 'theme.mode';
  static const _snapshot = 'monitors.snapshot';

  final SharedPreferences _prefs;
  final SecretStore _secrets;

  Future<PairingLink?> loadLink() async {
    final url = _prefs.getString(_linkUrl);
    final token = await _secrets.read(_linkToken);
    if (url == null || token == null || token.isEmpty) return null;

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    return PairingLink(baseUrl: uri, token: token);
  }

  Future<void> saveLink(PairingLink link) async {
    await _prefs.setString(_linkUrl, link.baseUrl.toString());
    await _secrets.write(_linkToken, link.token);
  }

  Future<void> clearLink() async {
    await _prefs.remove(_linkUrl);
    await _secrets.delete(_linkToken);
    await _prefs.remove(_snapshot);
  }

  /// The monitors as last seen, so the app can show them the moment it opens.
  List<Monitor> loadSnapshot() {
    final raw = _prefs.getString(_snapshot);
    if (raw == null) return const [];

    try {
      return [for (final item in jsonDecode(raw) as List<dynamic>) Monitor.fromJson(item as Map<String, dynamic>)];
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveSnapshot(List<Monitor> monitors) =>
      _prefs.setString(_snapshot, jsonEncode([for (final monitor in monitors) monitor.toJson()]));

  String? get selectedMonitor => _prefs.getString(_selectedMonitor);

  Future<void> saveSelectedMonitor(String id) => _prefs.setString(_selectedMonitor, id);

  /// The saved scenes, or the starter set the first time the app runs.
  List<Scene> loadScenes() {
    final raw = _prefs.getString(_scenes);
    if (raw == null) return Scene.starters();

    try {
      return [for (final item in jsonDecode(raw) as List<dynamic>) Scene.fromJson(item as Map<String, dynamic>)];
    } catch (_) {
      return Scene.starters();
    }
  }

  Future<void> saveScenes(List<Scene> scenes) =>
      _prefs.setString(_scenes, jsonEncode([for (final scene in scenes) scene.toJson()]));

  /// Names the user gave to options, keyed by `LabelKey.of(...)`.
  Map<String, String> loadLabels() {
    final raw = _prefs.getString(_labels);
    if (raw == null) return {};

    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveLabels(Map<String, String> labels) => _prefs.setString(_labels, jsonEncode(labels));

  ThemeMode loadThemeMode() => switch (_prefs.getString(_themeMode)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> saveThemeMode(ThemeMode mode) => _prefs.setString(_themeMode, mode.name);
}
