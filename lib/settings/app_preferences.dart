import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences extends ChangeNotifier {
  AppPreferences(this._storage) {
    final stored = _storage.getString(_themeKey);
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }
  static const _themeKey = 'fitcheck.theme';
  final SharedPreferences _storage;
  late ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;
  Future<void> setThemeMode(ThemeMode mode) async {
    if (!await _storage.setString(_themeKey, mode.name)) {
      throw StateError('Could not save theme preference');
    }
    _themeMode = mode;
    notifyListeners();
  }
}
