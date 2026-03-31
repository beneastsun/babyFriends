import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qiaoqiao_companion/core/theme/app_color_schemes.dart';

/// 主题状态
class ThemeState {
  final ThemeMode themeMode;
  final bool useDarkMode;
  final AppThemeType themeType;

  const ThemeState({
    required this.themeMode,
    required this.useDarkMode,
    required this.themeType,
  });

  factory ThemeState.initial() => const ThemeState(
    themeMode: ThemeMode.system,
    useDarkMode: false,
    themeType: AppThemeType.current,
  );

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? useDarkMode,
    AppThemeType? themeType,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      useDarkMode: useDarkMode ?? this.useDarkMode,
      themeType: themeType ?? this.themeType,
    );
  }

  bool get isDarkMode => themeMode == ThemeMode.dark ||
      (themeMode == ThemeMode.system && useDarkMode);

  /// 获取当前颜色方案
  ColorSchemeConfig get colorScheme => AppColorSchemes.getScheme(themeType);
}

/// 主题 Notifier
class ThemeNotifier extends StateNotifier<ThemeState> {
  static const String _themeModeKey = 'theme_mode';
  static const String _themeTypeKey = 'theme_type';

  ThemeNotifier() : super(ThemeState.initial()) {
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载主题模式
      final themeModeString = prefs.getString(_themeModeKey);
      ThemeMode mode = ThemeMode.system;
      if (themeModeString != null) {
        switch (themeModeString) {
          case 'light':
            mode = ThemeMode.light;
            break;
          case 'dark':
            mode = ThemeMode.dark;
            break;
          default:
            mode = ThemeMode.system;
        }
      }

      // 加载主题类型
      final themeTypeString = prefs.getString(_themeTypeKey);
      AppThemeType themeType = AppThemeType.current;
      if (themeTypeString != null) {
        switch (themeTypeString) {
          case 'pink':
            themeType = AppThemeType.pink;
            break;
          case 'orange':
            themeType = AppThemeType.orange;
            break;
          default:
            themeType = AppThemeType.current;
        }
      }

      // 获取系统主题状态
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final useDarkMode = brightness == Brightness.dark;

      state = ThemeState(
        themeMode: mode,
        useDarkMode: mode == ThemeMode.dark || (mode == ThemeMode.system && useDarkMode),
        themeType: themeType,
      );
    } catch (e) {
      // 如果加载失败，使用默认值
      state = ThemeState.initial();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String modeString = 'system';
      switch (mode) {
        case ThemeMode.light:
          modeString = 'light';
          break;
        case ThemeMode.dark:
          modeString = 'dark';
          break;
        default:
          modeString = 'system';
      }

      await prefs.setString(_themeModeKey, modeString);

      // 获取系统主题状态
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final useDarkMode = mode == ThemeMode.dark || (mode == ThemeMode.system && brightness == Brightness.dark);

      state = state.copyWith(
        themeMode: mode,
        useDarkMode: useDarkMode,
      );
    } catch (e) {
      // 如果保存失败，只更新状态
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      final useDarkMode = mode == ThemeMode.dark || (mode == ThemeMode.system && brightness == Brightness.dark);

      state = state.copyWith(
        themeMode: mode,
        useDarkMode: useDarkMode,
      );
    }
  }

  /// 设置主题类型
  Future<void> setThemeType(AppThemeType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String typeString = 'current';
      switch (type) {
        case AppThemeType.pink:
          typeString = 'pink';
          break;
        case AppThemeType.orange:
          typeString = 'orange';
          break;
        default:
          typeString = 'current';
      }

      await prefs.setString(_themeTypeKey, typeString);
      state = state.copyWith(themeType: type);
    } catch (e) {
      // 如果保存失败，只更新状态
      state = state.copyWith(themeType: type);
    }
  }

  void updateSystemBrightness(Brightness brightness) {
    if (state.themeMode == ThemeMode.system) {
      state = state.copyWith(
        useDarkMode: brightness == Brightness.dark,
      );
    }
  }

  void toggleTheme() {
    if (state.themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else if (state.themeMode == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      // 如果是系统模式，切换到相反模式
      setThemeMode(state.useDarkMode ? ThemeMode.light : ThemeMode.dark);
    }
  }
}

/// 主题 Provider
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

/// 当前是否为深色模式
final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeProvider).isDarkMode;
});

/// 当前主题模式
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeProvider).themeMode;
});

/// 当前主题类型
final themeTypeProvider = Provider<AppThemeType>((ref) {
  return ref.watch(themeProvider).themeType;
});

/// 当前颜色方案
final colorSchemeProvider = Provider<ColorSchemeConfig>((ref) {
  return ref.watch(themeProvider).colorScheme;
});
