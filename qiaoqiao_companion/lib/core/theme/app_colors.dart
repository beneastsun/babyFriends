import 'package:flutter/material.dart';

/// 应用颜色系统 - 星空蓝 + 极光绿
class AppColors {
  AppColors._();

  // ========== 主色调 - 星空蓝 (Starlight Blue) ==========

  /// 主色 - 浅色模式
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryLight = Color(0xFF64B5F6);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryContainer = Color(0xFFE3F2FD);

  /// 主色 - 深色模式
  static const Color primaryDarkMode = Color(0xFF64B5F6);
  static const Color primaryLightDarkMode = Color(0xFF90CAF9);
  static const Color primaryContainerDarkMode = Color(0xFF0D47A1);

  // ========== 辅助色 - 极光绿 (Aurora Green) ==========

  /// 辅助色 - 浅色模式
  static const Color secondary = Color(0xFF00E676);
  static const Color secondaryLight = Color(0xFF69F0AE);
  static const Color secondaryDark = Color(0xFF00C853);

  /// 辅助色 - 深色模式
  static const Color secondaryDarkMode = Color(0xFF69F0AE);
  static const Color secondaryLightDarkMode = Color(0xFFB9F6CA);

  // ========== 语义色 ==========

  /// 成功色
  static const Color success = Color(0xFF00E676);
  static const Color successDarkMode = Color(0xFF69F0AE);

  /// 警告色
  static const Color warning = Color(0xFFFFB300);
  static const Color warningDarkMode = Color(0xFFFFD54F);

  /// 错误色
  static const Color error = Color(0xFFFF5252);
  static const Color errorDarkMode = Color(0xFFFF8A80);

  /// 信息色
  static const Color info = Color(0xFF40C4FF);
  static const Color infoDarkMode = Color(0xFF80D8FF);

  // ========== 应用分类色 ==========

  /// 游戏 - 粉红
  static const Color game = Color(0xFFFF4081);
  static const Color gameLight = Color(0xFFF50057);

  /// 视频 - 紫色
  static const Color video = Color(0xFFAB47BC);
  static const Color videoLight = Color(0xFF8E24AA);

  /// 学习 - 绿色
  static const Color study = Color(0xFF00E676);
  static const Color studyLight = Color(0xFF00C853);

  /// 阅读 - 蓝色
  static const Color reading = Color(0xFF42A5F5);
  static const Color readingLight = Color(0xFF1E88E5);

  /// 其他 - 灰色
  static const Color other = Color(0xFF78909C);
  static const Color otherLight = Color(0xFF546E7A);

  // ========== 向后兼容别名 ==========

  /// @deprecated 使用 game 替代
  static const Color gameColor = game;

  /// @deprecated 使用 video 替代
  static const Color videoColor = video;

  /// @deprecated 使用 study 替代
  static const Color studyColor = study;

  /// @deprecated 使用 reading 替代
  static const Color readingColor = reading;

  /// @deprecated 使用 other 替代
  static const Color otherColor = other;

  // ========== 成就等级色 ==========

  /// 铜牌
  static const Color bronze = Color(0xFFCD7F32);

  /// 银牌
  static const Color silver = Color(0xFFC0C0C0);

  /// 金牌
  static const Color gold = Color(0xFFFFD700);

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

  /// 获取分类渐变色
  static List<Color> getCategoryGradient(String category) {
    switch (category.toLowerCase()) {
      case 'game':
        return [game, gameLight];
      case 'video':
        return [video, videoLight];
      case 'study':
        return [study, studyLight];
      case 'reading':
        return [reading, readingLight];
      default:
        return [other, otherLight];
    }
  }

  // ========== 巧巧心情色 ==========

  /// 开心 - 使用 < 70%
  static const Color qiaoqiaoHappy = Color(0xFF00E676);
  static const Color qiaoqiaoHappyLight = Color(0xFF69F0AE);

  /// 提醒 - 使用 70%-90%
  static const Color qiaoqiaoRemind = Color(0xFFFFB300);
  static const Color qiaoqiaoRemindLight = Color(0xFFFFD54F);

  /// 严肃 - 使用 >= 90%
  static const Color qiaoqiaoSerious = Color(0xFFFF9100);
  static const Color qiaoqiaoSeriousLight = Color(0xFFFF6D00);

  /// 难过 - 超限
  static const Color qiaoqiaoSad = Color(0xFF42A5F5);
  static const Color qiaoqiaoSadLight = Color(0xFF64B5F6);

  /// 获取巧巧心情颜色
  static Color getQiaoqiaoMoodColor(double usagePercentage) {
    if (usagePercentage < 0.7) {
      return qiaoqiaoHappy;
    } else if (usagePercentage < 0.9) {
      return qiaoqiaoRemind;
    } else if (usagePercentage < 1.0) {
      return qiaoqiaoSerious;
    } else {
      return qiaoqiaoSad;
    }
  }

  /// 获取巧巧心情渐变
  static List<Color> getQiaoqiaoMoodGradient(double usagePercentage) {
    if (usagePercentage < 0.7) {
      return [qiaoqiaoHappy, qiaoqiaoHappyLight];
    } else if (usagePercentage < 0.9) {
      return [qiaoqiaoRemind, qiaoqiaoRemindLight];
    } else if (usagePercentage < 1.0) {
      return [qiaoqiaoSerious, qiaoqiaoSeriousLight];
    } else {
      return [qiaoqiaoSad, qiaoqiaoSadLight];
    }
  }

  // ========== 积分颜色 ==========

  static const Color pointsGold = Color(0xFFFFD700);
  static const Color pointsEarned = Color(0xFF00E676);
  static const Color pointsSpent = Color(0xFFFF5252);

  // ========== 背景色 ==========

  /// 浅色模式背景
  static const Color backgroundLight = Color(0xFFF5F9FF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);

  /// 深色模式背景
  static const Color backgroundDark = Color(0xFF0D1B2A);
  static const Color surfaceDark = Color(0xFF1B2838);
  static const Color cardDark = Color(0xFF243447);

  // ========== 文字颜色 ==========

  /// 浅色模式文字
  static const Color textPrimaryLight = Color(0xFF1A237E);
  static const Color textSecondaryLight = Color(0xFF5C6BC0);
  static const Color textHintLight = Color(0xFF9FA8DA);

  /// 深色模式文字
  static const Color textPrimaryDark = Color(0xFFE8EAF6);
  static const Color textSecondaryDark = Color(0xFFB0BEC5);
  static const Color textHintDark = Color(0xFF78909C);

  // ========== 边框和分割线 ==========

  static const Color borderLight = Color(0xFFE3F2FD);
  static const Color borderDark = Color(0xFF37474F);
  static const Color dividerLight = Color(0xFFE8EAF6);
  static const Color dividerDark = Color(0xFF455A64);

  // ========== 玻璃拟态 ==========

  static const Color glassBackgroundLight = Color(0xCCFFFFFF);
  static const Color glassBackgroundDark = Color(0xCC1B2838);
  static const Color glassBorderLight = Color(0x33FFFFFF);
  static const Color glassBorderDark = Color(0x3390CAF9);

  // ========== ColorScheme 生成 ==========

  /// 浅色主题 ColorScheme
  static ColorScheme lightColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      error: error,
      surface: surfaceLight,
    );
  }

  /// 深色主题 ColorScheme
  static ColorScheme darkColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: primaryDarkMode,
      brightness: Brightness.dark,
      primary: primaryDarkMode,
      secondary: secondaryDarkMode,
      error: errorDarkMode,
      surface: surfaceDark,
    );
  }
}
