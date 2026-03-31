import 'package:flutter/material.dart';

/// 主题类型枚举
enum AppThemeType {
  current, // 星空蓝+极光绿（默认）
  pink, // 樱花粉+薰衣草紫
  orange, // 阳光橙+薄荷绿
  // 以下主题已移除
  // blue, // 海洋蓝+珊瑚红
  // candy, // 糖果紫+蜜桃粉
}

/// 主题类型扩展
extension AppThemeTypeExtension on AppThemeType {
  /// 主题名称
  String get name {
    switch (this) {
      case AppThemeType.current:
        return '星空蓝';
      case AppThemeType.pink:
        return '樱花粉';
      case AppThemeType.orange:
        return '阳光橙';
    }
  }

  /// 主题描述
  String get description {
    switch (this) {
      case AppThemeType.current:
        return '星空蓝 + 极光绿';
      case AppThemeType.pink:
        return '樱花粉 + 薰衣草紫';
      case AppThemeType.orange:
        return '阳光橙 + 薄荷绿';
    }
  }

  /// 主题图标
  IconData get icon {
    switch (this) {
      case AppThemeType.current:
        return Icons.nights_stay_rounded;
      case AppThemeType.pink:
        return Icons.local_florist_rounded;
      case AppThemeType.orange:
        return Icons.wb_sunny_rounded;
    }
  }

  /// 主题预览色（用于选择器显示）
  Color get previewColor {
    switch (this) {
      case AppThemeType.current:
        return const Color(0xFF2196F3);
      case AppThemeType.pink:
        return const Color(0xFFE91E63);
      case AppThemeType.orange:
        return const Color(0xFFFF9800);
    }
  }
}

/// 颜色方案配置
class ColorSchemeConfig {
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color primaryContainer;

  final Color primaryDarkMode;
  final Color primaryLightDarkMode;
  final Color primaryContainerDarkMode;

  final Color secondary;
  final Color secondaryLight;
  final Color secondaryDark;

  final Color secondaryDarkMode;
  final Color secondaryLightDarkMode;

  // 背景色 - 浅色模式
  final Color backgroundLight;
  final Color surfaceLight;
  final Color cardLight;

  // 背景色 - 深色模式
  final Color backgroundDark;
  final Color surfaceDark;
  final Color cardDark;

  // 文字颜色 - 浅色模式
  final Color textPrimaryLight;
  final Color textSecondaryLight;
  final Color textHintLight;

  // 文字颜色 - 深色模式
  final Color textPrimaryDark;
  final Color textSecondaryDark;
  final Color textHintDark;

  // 边框和分割线
  final Color borderLight;
  final Color borderDark;
  final Color dividerLight;
  final Color dividerDark;

  const ColorSchemeConfig({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.primaryContainer,
    required this.primaryDarkMode,
    required this.primaryLightDarkMode,
    required this.primaryContainerDarkMode,
    required this.secondary,
    required this.secondaryLight,
    required this.secondaryDark,
    required this.secondaryDarkMode,
    required this.secondaryLightDarkMode,
    required this.backgroundLight,
    required this.surfaceLight,
    required this.cardLight,
    required this.backgroundDark,
    required this.surfaceDark,
    required this.cardDark,
    required this.textPrimaryLight,
    required this.textSecondaryLight,
    required this.textHintLight,
    required this.textPrimaryDark,
    required this.textSecondaryDark,
    required this.textHintDark,
    required this.borderLight,
    required this.borderDark,
    required this.dividerLight,
    required this.dividerDark,
  });
}

/// 应用颜色方案集合
class AppColorSchemes {
  AppColorSchemes._();

  /// 当前的星空蓝 + 极光绿主题
  static const ColorSchemeConfig current = ColorSchemeConfig(
    // 主色调 - 星空蓝
    primary: Color(0xFF2196F3),
    primaryLight: Color(0xFF64B5F6),
    primaryDark: Color(0xFF1976D2),
    primaryContainer: Color(0xFFE3F2FD),
    primaryDarkMode: Color(0xFF64B5F6),
    primaryLightDarkMode: Color(0xFF90CAF9),
    primaryContainerDarkMode: Color(0xFF0D47A1),

    // 辅助色 - 极光绿
    secondary: Color(0xFF00E676),
    secondaryLight: Color(0xFF69F0AE),
    secondaryDark: Color(0xFF00C853),
    secondaryDarkMode: Color(0xFF69F0AE),
    secondaryLightDarkMode: Color(0xFFB9F6CA),

    // 背景色 - 浅色模式
    backgroundLight: Color(0xFFF5F9FF),
    surfaceLight: Color(0xFFFFFFFF),
    cardLight: Color(0xFFFFFFFF),

    // 背景色 - 深色模式
    backgroundDark: Color(0xFF0D1B2A),
    surfaceDark: Color(0xFF1B2838),
    cardDark: Color(0xFF243447),

    // 文字颜色 - 浅色模式
    textPrimaryLight: Color(0xFF1A237E),
    textSecondaryLight: Color(0xFF5C6BC0),
    textHintLight: Color(0xFF9FA8DA),

    // 文字颜色 - 深色模式
    textPrimaryDark: Color(0xFFE8EAF6),
    textSecondaryDark: Color(0xFFB0BEC5),
    textHintDark: Color(0xFF78909C),

    // 边框和分割线
    borderLight: Color(0xFFE3F2FD),
    borderDark: Color(0xFF37474F),
    dividerLight: Color(0xFFE8EAF6),
    dividerDark: Color(0xFF455A64),
  );

  /// 樱花粉 + 薰衣草紫主题
  static const ColorSchemeConfig pink = ColorSchemeConfig(
    // 主色调 - 樱花粉
    primary: Color(0xFFE91E63),
    primaryLight: Color(0xFFF48FB1),
    primaryDark: Color(0xFFC2185B),
    primaryContainer: Color(0xFFFCE4EC),
    primaryDarkMode: Color(0xFFF48FB1),
    primaryLightDarkMode: Color(0xFFF8BBD9),
    primaryContainerDarkMode: Color(0xFF880E4F),

    // 辅助色 - 薰衣草紫
    secondary: Color(0xFFBA68C8),
    secondaryLight: Color(0xFFCE93D8),
    secondaryDark: Color(0xFF9C27B0),
    secondaryDarkMode: Color(0xFFCE93D8),
    secondaryLightDarkMode: Color(0xFFE1BEE7),

    // 背景色 - 浅色模式
    backgroundLight: Color(0xFFFFF5F8),
    surfaceLight: Color(0xFFFFFFFF),
    cardLight: Color(0xFFFFFFFF),

    // 背景色 - 深色模式
    backgroundDark: Color(0xFF1A0A14),
    surfaceDark: Color(0xFF2A1520),
    cardDark: Color(0xFF3A2030),

    // 文字颜色 - 浅色模式
    textPrimaryLight: Color(0xFF4A1942),
    textSecondaryLight: Color(0xFF8E5C7C),
    textHintLight: Color(0xFFB89CA8),

    // 文字颜色 - 深色模式
    textPrimaryDark: Color(0xFFF8E8EF),
    textSecondaryDark: Color(0xFFD4B8C4),
    textHintDark: Color(0xFFA08894),

    // 边框和分割线
    borderLight: Color(0xFFFCE4EC),
    borderDark: Color(0xFF4A3040),
    dividerLight: Color(0xFFF8E8EF),
    dividerDark: Color(0xFF5A4050),
  );

  /// 阳光橙 + 薄荷绿主题
  static const ColorSchemeConfig orange = ColorSchemeConfig(
    // 主色调 - 阳光橙
    primary: Color(0xFFFF9800),
    primaryLight: Color(0xFFFFB74D),
    primaryDark: Color(0xFFF57C00),
    primaryContainer: Color(0xFFFFF3E0),
    primaryDarkMode: Color(0xFFFFB74D),
    primaryLightDarkMode: Color(0xFFFFCC80),
    primaryContainerDarkMode: Color(0xFFE65100),

    // 辅助色 - 薄荷绿
    secondary: Color(0xFF26A69A),
    secondaryLight: Color(0xFF4DB6AC),
    secondaryDark: Color(0xFF00897B),
    secondaryDarkMode: Color(0xFF4DB6AC),
    secondaryLightDarkMode: Color(0xFF80CBC4),

    // 背景色 - 浅色模式
    backgroundLight: Color(0xFFFFFBF5),
    surfaceLight: Color(0xFFFFFFFF),
    cardLight: Color(0xFFFFFFFF),

    // 背景色 - 深色模式
    backgroundDark: Color(0xFF1A1408),
    surfaceDark: Color(0xFF2A2010),
    cardDark: Color(0xFF3A2C18),

    // 文字颜色 - 浅色模式
    textPrimaryLight: Color(0xFF5D4037),
    textSecondaryLight: Color(0xFF8D6E63),
    textHintLight: Color(0xFFBCAAA4),

    // 文字颜色 - 深色模式
    textPrimaryDark: Color(0xFFFBE9E7),
    textSecondaryDark: Color(0xFFD7CCC8),
    textHintDark: Color(0xFFA1887F),

    // 边框和分割线
    borderLight: Color(0xFFFFF3E0),
    borderDark: Color(0xFF4A3C28),
    dividerLight: Color(0xFFEFEBE9),
    dividerDark: Color(0xFF5A4C38),
  );

  /// 根据主题类型获取颜色方案
  static ColorSchemeConfig getScheme(AppThemeType type) {
    switch (type) {
      case AppThemeType.current:
        return current;
      case AppThemeType.pink:
        return pink;
      case AppThemeType.orange:
        return orange;
    }
  }

  /// 所有主题类型
  static const List<AppThemeType> allTypes = [
    AppThemeType.current,
    AppThemeType.pink,
    AppThemeType.orange,
  ];
}
