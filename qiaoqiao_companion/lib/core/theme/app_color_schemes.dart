import 'package:flutter/material.dart';

/// Kawaii Dream 主题类型枚举
enum AppThemeType {
  /// 梦幻粉紫 (默认) - 樱花粉 + 薰衣草紫 + 薄荷绿
  kawaiiDream,

  /// 彩虹糖果 - 多彩糖果色
  rainbowCandy,

  /// 柔和马卡龙 - 低饱和温柔色
  softMacaron,
}

/// 主题类型扩展
extension AppThemeTypeExtension on AppThemeType {
  /// 主题名称
  String get name {
    switch (this) {
      case AppThemeType.kawaiiDream:
        return '梦幻粉紫';
      case AppThemeType.rainbowCandy:
        return '彩虹糖果';
      case AppThemeType.softMacaron:
        return '柔和马卡龙';
    }
  }

  /// 主题描述
  String get description {
    switch (this) {
      case AppThemeType.kawaiiDream:
        return '樱花粉 + 薰衣草紫 + 薄荷绿';
      case AppThemeType.rainbowCandy:
        return '多彩糖果色 · 活泼跳跃';
      case AppThemeType.softMacaron:
        return '低饱和度 · 温柔优雅';
    }
  }

  /// 主题图标
  IconData get icon {
    switch (this) {
      case AppThemeType.kawaiiDream:
        return Icons.favorite_rounded;
      case AppThemeType.rainbowCandy:
        return Icons.palette_rounded;
      case AppThemeType.softMacaron:
        return Icons.bedtime_rounded;
    }
  }

  /// 主题预览色（用于选择器显示）
  Color get previewColor {
    switch (this) {
      case AppThemeType.kawaiiDream:
        return const Color(0xFFFF6B9D);
      case AppThemeType.rainbowCandy:
        return const Color(0xFFFF6B9D);
      case AppThemeType.softMacaron:
        return const Color(0xFFE8B4C8);
    }
  }
}

/// 颜色方案配置
class ColorSchemeConfig {
  // 主色调
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color primaryContainer;

  final Color primaryDarkMode;
  final Color primaryLightDarkMode;
  final Color primaryContainerDarkMode;

  // 辅助色
  final Color secondary;
  final Color secondaryLight;
  final Color secondaryDark;

  final Color secondaryDarkMode;
  final Color secondaryLightDarkMode;

  // 点缀色
  final Color tertiary;
  final Color tertiaryLight;
  final Color tertiaryDark;
  final Color tertiaryDarkMode;

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
    required this.tertiary,
    required this.tertiaryLight,
    required this.tertiaryDark,
    required this.tertiaryDarkMode,
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

/// Kawaii Dream 颜色方案集合
class AppColorSchemes {
  AppColorSchemes._();

  /// 梦幻粉紫主题 (默认)
  static const ColorSchemeConfig kawaiiDream = ColorSchemeConfig(
    // 主色调 - 樱花粉
    primary: Color(0xFFFF6B9D),
    primaryLight: Color(0xFFFF8FB1),
    primaryDark: Color(0xFFE54B7E),
    primaryContainer: Color(0xFFFFF0F5),
    primaryDarkMode: Color(0xFFFF8FB1),
    primaryLightDarkMode: Color(0xFFFFB3C9),
    primaryContainerDarkMode: Color(0xFF4A1942),

    // 辅助色 - 薰衣草紫
    secondary: Color(0xFFC77DFF),
    secondaryLight: Color(0xFFD9A8FF),
    secondaryDark: Color(0xFF9F5DE0),
    secondaryDarkMode: Color(0xFFD9A8FF),
    secondaryLightDarkMode: Color(0xFFE8C8FF),

    // 点缀色 - 薄荷绿
    tertiary: Color(0xFF7FDBCA),
    tertiaryLight: Color(0xFFA5E8D9),
    tertiaryDark: Color(0xFF5CBFAB),
    tertiaryDarkMode: Color(0xFFA5E8D9),

    // 背景色 - 浅色模式
    backgroundLight: Color(0xFFFFF8FA),
    surfaceLight: Color(0xFFFFFFFF),
    cardLight: Color(0xFFFFFFFF),

    // 背景色 - 深色模式
    backgroundDark: Color(0xFF1A1025),
    surfaceDark: Color(0xFF2D1F3D),
    cardDark: Color(0xFF3D2D52),

    // 文字颜色 - 浅色模式 (高对比度)
    textPrimaryLight: Color(0xFF2D1F3D),
    textSecondaryLight: Color(0xFF6B5B7A),
    textHintLight: Color(0xFF9E8FA8),

    // 文字颜色 - 深色模式
    textPrimaryDark: Color(0xFFFFF8FA),
    textSecondaryDark: Color(0xFFD4C5D9),
    textHintDark: Color(0xFF9E8FA8),

    // 边框和分割线
    borderLight: Color(0xFFFFE4EC),
    borderDark: Color(0xFF4A3040),
    dividerLight: Color(0xFFFFF0F5),
    dividerDark: Color(0xFF5A4050),
  );

  /// 彩虹糖果主题
  static const ColorSchemeConfig rainbowCandy = ColorSchemeConfig(
    // 主色调 - 糖果粉
    primary: Color(0xFFFF6090),
    primaryLight: Color(0xFFFF8CB3),
    primaryDark: Color(0xFFE64070),
    primaryContainer: Color(0xFFFFEBF0),
    primaryDarkMode: Color(0xFFFF8CB3),
    primaryLightDarkMode: Color(0xFFFFB0CC),
    primaryContainerDarkMode: Color(0xFF501830),

    // 辅助色 - 糖果紫
    secondary: Color(0xFFB388FF),
    secondaryLight: Color(0xFFD4B8FF),
    secondaryDark: Color(0xFF8855E0),
    secondaryDarkMode: Color(0xFFD4B8FF),
    secondaryLightDarkMode: Color(0xFFE8D4FF),

    // 点缀色 - 糖果蓝
    tertiary: Color(0xFF80D4FF),
    tertiaryLight: Color(0xFFB0E4FF),
    tertiaryDark: Color(0xFF50B8E6),
    tertiaryDarkMode: Color(0xFFB0E4FF),

    // 背景色 - 浅色模式
    backgroundLight: Color(0xFFFFFBFE),
    surfaceLight: Color(0xFFFFFFFF),
    cardLight: Color(0xFFFFFFFF),

    // 背景色 - 深色模式
    backgroundDark: Color(0xFF1A0A20),
    surfaceDark: Color(0xFF2A1535),
    cardDark: Color(0xFF3A2045),

    // 文字颜色 - 浅色模式
    textPrimaryLight: Color(0xFF2A1535),
    textSecondaryLight: Color(0xFF6A5075),
    textHintLight: Color(0xFF9A85A5),

    // 文字颜色 - 深色模式
    textPrimaryDark: Color(0xFFFBF5FF),
    textSecondaryDark: Color(0xFFD8C5E0),
    textHintDark: Color(0xFFA895B0),

    // 边框和分割线
    borderLight: Color(0xFFFFD0E0),
    borderDark: Color(0xFF503060),
    dividerLight: Color(0xFFFFE8F0),
    dividerDark: Color(0xFF604070),
  );

  /// 柔和马卡龙主题
  static const ColorSchemeConfig softMacaron = ColorSchemeConfig(
    // 主色调 - 马卡龙粉
    primary: Color(0xFFE8B4C8),
    primaryLight: Color(0xFFF0C8D8),
    primaryDark: Color(0xFFD090A8),
    primaryContainer: Color(0xFFF8E8F0),
    primaryDarkMode: Color(0xFFF0C8D8),
    primaryLightDarkMode: Color(0xFFF8D8E8),
    primaryContainerDarkMode: Color(0xFF402838),

    // 辅助色 - 马卡龙紫
    secondary: Color(0xFFC8B8E8),
    secondaryLight: Color(0xFFD8C8F0),
    secondaryDark: Color(0xFFA898C8),
    secondaryDarkMode: Color(0xFFD8C8F0),
    secondaryLightDarkMode: Color(0xFFE8D8F8),

    // 点缀色 - 马卡龙绿
    tertiary: Color(0xFFB8D8C8),
    tertiaryLight: Color(0xFFC8E8D8),
    tertiaryDark: Color(0xFF98B8A8),
    tertiaryDarkMode: Color(0xFFC8E8D8),

    // 背景色 - 浅色模式
    backgroundLight: Color(0xFFFAF8FA),
    surfaceLight: Color(0xFFFFFFFF),
    cardLight: Color(0xFFFFFFFF),

    // 背景色 - 深色模式
    backgroundDark: Color(0xFF1A1820),
    surfaceDark: Color(0xFF2A2835),
    cardDark: Color(0xFF3A3848),

    // 文字颜色 - 浅色模式
    textPrimaryLight: Color(0xFF2A2835),
    textSecondaryLight: Color(0xFF6A6078),
    textHintLight: Color(0xFF9A90A8),

    // 文字颜色 - 深色模式
    textPrimaryDark: Color(0xFFF8F5FA),
    textSecondaryDark: Color(0xFFD0C8D8),
    textHintDark: Color(0xFFA098A8),

    // 边框和分割线
    borderLight: Color(0xFFE8D8E0),
    borderDark: Color(0xFF403848),
    dividerLight: Color(0xFFF0E8F0),
    dividerDark: Color(0xFF504858),
  );

  /// 根据主题类型获取颜色方案
  static ColorSchemeConfig getScheme(AppThemeType type) {
    switch (type) {
      case AppThemeType.kawaiiDream:
        return kawaiiDream;
      case AppThemeType.rainbowCandy:
        return rainbowCandy;
      case AppThemeType.softMacaron:
        return softMacaron;
    }
  }

  /// 所有主题类型
  static const List<AppThemeType> allTypes = [
    AppThemeType.kawaiiDream,
    AppThemeType.rainbowCandy,
    AppThemeType.softMacaron,
  ];

  /// 默认主题
  static const AppThemeType defaultType = AppThemeType.kawaiiDream;

  // ============================================================
  // 向后兼容
  // ============================================================

  /// @deprecated 使用 kawaiiDream 替代
  static const ColorSchemeConfig current = kawaiiDream;

  /// @deprecated 使用 kawaiiDream 替代
  static const ColorSchemeConfig pink = kawaiiDream;
}
