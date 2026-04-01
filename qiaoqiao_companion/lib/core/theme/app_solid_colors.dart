import 'package:flutter/material.dart';
import 'app_color_schemes.dart';

/// Kawaii Dream 纯色主题系统
/// Material 3 风格 + 可爱梦幻配色
/// 提供统一的纯色访问接口
class AppSolidColors {
  AppSolidColors._();

  // ============================================================
  // 背景色
  // ============================================================

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

  // ============================================================
  // 主色调
  // ============================================================

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

  // ============================================================
  // 辅助色
  // ============================================================

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

  // ============================================================
  // 点缀色
  // ============================================================

  /// 获取点缀色
  static Color getTertiaryColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return isDark ? scheme.tertiaryDarkMode : scheme.tertiary;
  }

  /// 获取点缀色浅色
  static Color getTertiaryLightColor(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    return scheme.tertiaryLight;
  }

  // ============================================================
  // 文字颜色 (高对比度)
  // ============================================================

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

  // ============================================================
  // 状态色（统一标准，不随主题变化）
  // ============================================================

  /// 成功色 - 薄荷绿 (对比度 4.5:1 ✓)
  static const Color success = Color(0xFF7FDBCA);
  static const Color successDark = Color(0xFFA5E8D9);

  /// 警告色 - 橙黄色
  static const Color warning = Color(0xFFFFB74D);
  static const Color warningDark = Color(0xFFFFCC80);

  /// 错误色 - 珊瑚红 (对比度 4.5:1 ✓)
  static const Color error = Color(0xFFFF8A65);
  static const Color errorDark = Color(0xFFFFAB91);

  /// 信息色 - 使用主题色
  static const Color info = Color(0xFF64B5F6);
  static const Color infoDark = Color(0xFF90CAF9);

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

  // ============================================================
  // 进度状态色 (Kawaii Dream 柔和版)
  // ============================================================

  /// 根据使用比例获取进度色
  static Color getProgressColor(double percentage, bool isDark) {
    if (percentage < 0.7) return getSuccessColor(isDark);
    if (percentage < 0.9) return getWarningColor(isDark);
    return getErrorColor(isDark);
  }

  // ============================================================
  // 分类颜色 (Kawaii Dream 可爱版)
  // ============================================================

  /// 游戏分类色 - 樱花粉
  static const Color game = Color(0xFFFF6B9D);
  static const Color gameLight = Color(0xFFFF8FB1);

  /// 视频分类色 - 薰衣草紫
  static const Color video = Color(0xFFC77DFF);
  static const Color videoLight = Color(0xFFD9A8FF);

  /// 学习分类色 - 薄荷绿
  static const Color study = Color(0xFF7FDBCA);
  static const Color studyLight = Color(0xFFA5E8D9);

  /// 阅读分类色 - 天蓝色
  static const Color reading = Color(0xFF64B5F6);
  static const Color readingLight = Color(0xFF90CAF9);

  /// 其他分类色 - 灰紫色
  static const Color other = Color(0xFFB0BEC5);
  static const Color otherLight = Color(0xFFCFD8DC);

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

  /// 获取分类渐变
  static List<Color> getCategoryGradient(String category) {
    return [getCategoryColor(category), getCategoryLightColor(category)];
  }

  // ============================================================
  // 巧巧心情色 (Kawaii Dream 版)
  // ============================================================

  /// 开心色 - 薄荷绿 (< 70%)
  static const Color qiaoqiaoHappy = Color(0xFF7FDBCA);
  static const Color qiaoqiaoHappyLight = Color(0xFFA5E8D9);

  /// 提醒色 - 橙黄色 (70%-90%)
  static const Color qiaoqiaoRemind = Color(0xFFFFB74D);
  static const Color qiaoqiaoRemindLight = Color(0xFFFFCC80);

  /// 严肃色 - 珊瑚色 (90%-100%)
  static const Color qiaoqiaoSerious = Color(0xFFFF8A65);
  static const Color qiaoqiaoSeriousLight = Color(0xFFFFAB91);

  /// 难过色 - 天蓝色 (> 100%)
  static const Color qiaoqiaoSad = Color(0xFF64B5F6);
  static const Color qiaoqiaoSadLight = Color(0xFF90CAF9);

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

  /// 获取巧巧心情渐变
  static List<Color> getQiaoqiaoMoodGradient(double usagePercentage) {
    return [
      getQiaoqiaoMoodColor(usagePercentage),
      getQiaoqiaoMoodLightColor(usagePercentage),
    ];
  }

  // ============================================================
  // 积分颜色
  // ============================================================

  /// 积分金色
  static const Color pointsGold = Color(0xFFFFD700);
  static const Color pointsGoldLight = Color(0xFFFFE44D);

  /// 积分获得色 - 薄荷绿
  static const Color pointsEarned = Color(0xFF7FDBCA);
  static const Color pointsEarnedLight = Color(0xFFA5E8D9);

  /// 积分消耗色 - 樱花粉
  static const Color pointsSpent = Color(0xFFFF6B9D);
  static const Color pointsSpentLight = Color(0xFFFF8FB1);

  // ============================================================
  // 成就等级色
  // ============================================================

  /// 铜牌
  static const Color bronze = Color(0xFFCD7F32);
  static const Color bronzeLight = Color(0xFFD4A574);

  /// 银牌
  static const Color silver = Color(0xFF9E9E9E);
  static const Color silverLight = Color(0xFFBDBDBD);

  /// 金牌
  static const Color gold = Color(0xFFFFD700);
  static const Color goldLight = Color(0xFFFFE44D);

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

  // ============================================================
  // 边框和分割线
  // ============================================================

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

  // ============================================================
  // Material 3 表面变体
  // ============================================================

  /// 获取表面变体色（用于强调组件）
  static Color getSurfaceVariant(AppThemeType themeType, bool isDark) {
    final primary = getPrimaryColor(themeType, isDark);
    return isDark
        ? primary.withOpacity(0.12)
        : primary.withOpacity(0.08);
  }

  /// 获取表面着色色（用于轻微强调）
  static Color getSurfaceTint(AppThemeType themeType, bool isDark) {
    final primary = getPrimaryColor(themeType, isDark);
    return primary.withOpacity(0.05);
  }

  // ============================================================
  // 阴影色 (Kawaii Dream 柔和发光)
  // ============================================================

  /// 浅色模式阴影 - 粉紫色
  static const Color shadowLight = Color(0x1FC77DFF);

  /// 深色模式阴影 - 更深的紫色
  static const Color shadowDark = Color(0x3DC77DFF);

  /// 主色发光阴影
  static Color get glowShadowLight => const Color(0x33FF6B9D);

  /// 辅助色发光阴影
  static Color get glowShadowSecondary => const Color(0x33C77DFF);

  /// 获取阴影色
  static Color getShadowColor(bool isDark) =>
      isDark ? shadowDark : shadowLight;

  /// 获取发光阴影
  static List<BoxShadow> getGlowShadow(AppThemeType themeType, bool isDark) {
    final primary = getPrimaryColor(themeType, isDark);
    return [
      BoxShadow(
        color: primary.withOpacity(0.25),
        blurRadius: 20,
        spreadRadius: 2,
      ),
    ];
  }

  // ============================================================
  // 遮罩色
  // ============================================================

  /// 遮罩色（用于弹窗背景）
  static const Color scrim = Color(0x80000000);

  /// 浅遮罩
  static const Color scrimLight = Color(0x40000000);

  /// 柔和遮罩 - 紫色调
  static const Color scrimSoft = Color(0x662D1F3D);
}
