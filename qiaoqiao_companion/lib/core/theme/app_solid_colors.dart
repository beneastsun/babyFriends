import 'package:flutter/material.dart';
import 'app_color_schemes.dart';

/// 纯色主题系统 - Material 3 风格
/// 提供统一的纯色访问接口，移除所有渐变
class AppSolidColors {
  AppSolidColors._();

  // ========== 背景色 ==========

  /// 获取背景色
  static Color getBackgroundColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.backgroundDark : scheme.backgroundLight;
  }

  /// 获取表面色
  static Color getSurfaceColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.surfaceDark : scheme.surfaceLight;
  }

  /// 获取卡片色
  static Color getCardColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.cardDark : scheme.cardLight;
  }

  // ========== 主色调 ==========

  /// 获取主色
  static Color getPrimaryColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.primaryDarkMode : scheme.primary;
  }

  /// 获取主色浅色
  static Color getPrimaryLightColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.primaryLightDarkMode : scheme.primaryLight;
  }

  /// 获取主色深色
  static Color getPrimaryDarkColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return scheme.primaryDark;
  }

  /// 获取主色容器
  static Color getPrimaryContainerColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.primaryContainerDarkMode : scheme.primaryContainer;
  }

  // ========== 辅助色 ==========

  /// 获取辅助色
  static Color getSecondaryColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.secondaryDarkMode : scheme.secondary;
  }

  /// 获取辅助色浅色
  static Color getSecondaryLightColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.secondaryLightDarkMode : scheme.secondaryLight;
  }

  /// 获取辅助色深色
  static Color getSecondaryDarkColor(AppThemeType themeType) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return scheme.secondaryDark;
  }

  // ========== 文字颜色 ==========

  /// 获取主要文字颜色
  static Color getTextPrimaryColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.textPrimaryDark : scheme.textPrimaryLight;
  }

  /// 获取次要文字颜色
  static Color getTextSecondaryColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.textSecondaryDark : scheme.textSecondaryLight;
  }

  /// 获取提示文字颜色
  static Color getTextHintColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.textHintDark : scheme.textHintLight;
  }

  // ========== 状态色（统一标准，不随主题变化）==========

  /// 成功色
  static const Color success = Color(0xFF4CAF50);
  static const Color successDark = Color(0xFF81C784);

  /// 警告色
  static const Color warning = Color(0xFFFF9800);
  static const Color warningDark = Color(0xFFFFB74D);

  /// 错误色
  static const Color error = Color(0xFFE53935);
  static const Color errorDark = Color(0xFFEF5350);

  /// 信息色
  static const Color info = Color(0xFF2196F3);
  static const Color infoDark = Color(0xFF64B5F6);

  /// 获取成功色
  static Color getSuccessColor(bool isDark) =>
      isDark ? successDark : success;

  /// 获取警告色
  static Color getWarningColor(bool isDark) =>
      isDark ? warningDark : warning;

  /// 获取错误色
  static Color getErrorColor(bool isDark) =>
      isDark ? errorDark : error;

  /// 获取信息色
  static Color getInfoColor(bool isDark) =>
      isDark ? infoDark : info;

  // ========== 进度状态色 ==========

  /// 根据使用比例获取进度色
  static Color getProgressColor(double percentage, bool isDark) {
    if (percentage < 0.7) return getSuccessColor(isDark);
    if (percentage < 0.9) return getWarningColor(isDark);
    return getErrorColor(isDark);
  }

  // ========== 分类颜色（统一标准）==========

  /// 游戏分类色
  static const Color game = Color(0xFFE91E63);
  static const Color gameLight = Color(0xFFF48FB1);

  /// 视频分类色
  static const Color video = Color(0xFF9C27B0);
  static const Color videoLight = Color(0xFFCE93D8);

  /// 学习分类色
  static const Color study = Color(0xFF4CAF50);
  static const Color studyLight = Color(0xFF81C784);

  /// 阅读分类色
  static const Color reading = Color(0xFF2196F3);
  static const Color readingLight = Color(0xFF64B5F6);

  /// 其他分类色
  static const Color other = Color(0xFF607D8B);
  static const Color otherLight = Color(0xFF90A4AE);

  /// 获取分类颜色
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'game':
        return game;
      case 'video':
        return video;
      case 'study':
        return study;
      case 'reading':
        return reading;
      default:
        return other;
    }
  }

  /// 获取分类浅色
  static Color getCategoryLightColor(String category) {
    switch (category.toLowerCase()) {
      case 'game':
        return gameLight;
      case 'video':
        return videoLight;
      case 'study':
        return studyLight;
      case 'reading':
        return readingLight;
      default:
        return otherLight;
    }
  }

  // ========== 巧巧心情色 ==========

  /// 开心色 (< 70%)
  static const Color qiaoqiaoHappy = Color(0xFF4CAF50);
  static const Color qiaoqiaoHappyLight = Color(0xFF81C784);

  /// 提醒色 (70%-90%)
  static const Color qiaoqiaoRemind = Color(0xFFFF9800);
  static const Color qiaoqiaoRemindLight = Color(0xFFFFB74D);

  /// 严肃色 (90%-100%)
  static const Color qiaoqiaoSerious = Color(0xFFFF5722);
  static const Color qiaoqiaoSeriousLight = Color(0xFFFF8A65);

  /// 难过色 (> 100%)
  static const Color qiaoqiaoSad = Color(0xFF2196F3);
  static const Color qiaoqiaoSadLight = Color(0xFF64B5F6);

  /// 获取巧巧心情颜色
  static Color getQiaoqiaoMoodColor(double usagePercentage) {
    if (usagePercentage < 0.7) return qiaoqiaoHappy;
    if (usagePercentage < 0.9) return qiaoqiaoRemind;
    if (usagePercentage < 1.0) return qiaoqiaoSerious;
    return qiaoqiaoSad;
  }

  /// 获取巧巧心情浅色
  static Color getQiaoqiaoMoodLightColor(double usagePercentage) {
    if (usagePercentage < 0.7) return qiaoqiaoHappyLight;
    if (usagePercentage < 0.9) return qiaoqiaoRemindLight;
    if (usagePercentage < 1.0) return qiaoqiaoSeriousLight;
    return qiaoqiaoSadLight;
  }

  // ========== 积分颜色 ==========

  /// 积分金色
  static const Color pointsGold = Color(0xFFFFB300);
  static const Color pointsGoldLight = Color(0xFFFFD54F);

  /// 积分获得色
  static const Color pointsEarned = Color(0xFF4CAF50);
  static const Color pointsEarnedLight = Color(0xFF81C784);

  /// 积分消耗色
  static const Color pointsSpent = Color(0xFFE53935);
  static const Color pointsSpentLight = Color(0xFFEF5350);

  // ========== 成就等级色 ==========

  /// 铜牌
  static const Color bronze = Color(0xFFCD7F32);
  static const Color bronzeLight = Color(0xFFD4A574);

  /// 银牌
  static const Color silver = Color(0xFF9E9E9E);
  static const Color silverLight = Color(0xFFBDBDBD);

  /// 金牌
  static const Color gold = Color(0xFFFFB300);
  static const Color goldLight = Color(0xFFFFD54F);

  /// 获取奖牌颜色
  static Color getMedalColor(String medalType) {
    switch (medalType.toLowerCase()) {
      case 'bronze':
        return bronze;
      case 'silver':
        return silver;
      case 'gold':
        return gold;
      default:
        return other;
    }
  }

  /// 获取奖牌浅色
  static Color getMedalLightColor(String medalType) {
    switch (medalType.toLowerCase()) {
      case 'bronze':
        return bronzeLight;
      case 'silver':
        return silverLight;
      case 'gold':
        return goldLight;
      default:
        return otherLight;
    }
  }

  // ========== 边框和分割线 ==========

  /// 获取边框色
  static Color getBorderColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.borderDark : scheme.borderLight;
  }

  /// 获取分割线色
  static Color getDividerColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.dividerDark : scheme.dividerLight;
  }

  // ========== Material 3 表面变体 ==========

  /// 获取表面变体色（用于强调组件）
  static Color getSurfaceVariant(AppThemeType themeType, bool isDark) {
    final primary = getPrimaryColor(themeType, isDark);
    // 使用主色的低透明度版本
    return isDark
        ? primary.withOpacity(0.12)
        : primary.withOpacity(0.08);
  }

  /// 获取表面着色色（用于轻微强调）
  static Color getSurfaceTint(AppThemeType themeType, bool isDark) {
    final primary = getPrimaryColor(themeType, isDark);
    return primary.withOpacity(0.05);
  }

  // ========== 阴影色 ==========

  /// 浅色模式阴影
  static const Color shadowLight = Color(0x1F000000);

  /// 深色模式阴影
  static const Color shadowDark = Color(0x3D000000);

  /// 获取阴影色
  static Color getShadowColor(bool isDark) =>
      isDark ? shadowDark : shadowLight;

  // ========== 遮罩色 ==========

  /// 遮罩色（用于弹窗背景）
  static const Color scrim = Color(0x80000000);

  /// 浅遮罩
  static const Color scrimLight = Color(0x40000000);
}
