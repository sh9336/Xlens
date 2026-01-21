import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

class ThemeService {
  static const String _themeModeKey = 'theme_mode';
  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  Future<AppThemeMode> getThemeMode() async {
    await initialize();
    final savedMode = _prefs.getString(_themeModeKey);
    if (savedMode == null) return AppThemeMode.system;
    return AppThemeMode.values.firstWhere(
      (mode) => mode.toString() == savedMode,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await initialize();
    await _prefs.setString(_themeModeKey, mode.toString());
  }

  Brightness getBrightness(AppThemeMode mode, Brightness systemBrightness) {
    switch (mode) {
      case AppThemeMode.system:
        return systemBrightness;
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
    }
  }
}
