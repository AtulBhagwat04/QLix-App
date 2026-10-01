import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/cache_manager.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  final CacheManager _cacheManager;

  ThemeCubit(this._cacheManager) : super(_resolveInitialTheme(_cacheManager));

  static ThemeMode _resolveInitialTheme(CacheManager cache) {
    final saved = cache.getThemeMode();
    switch (saved) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  void setThemeMode(ThemeMode mode) {
    emit(mode);
    String modeString = 'light';
    if (mode == ThemeMode.dark) modeString = 'dark';
    if (mode == ThemeMode.system) modeString = 'system';
    _cacheManager.saveThemeMode(modeString);
  }
}
