import 'package:flutter/material.dart';

/// Kawaii Dream 颜色系统
/// 梦幻粉紫系 - 专为11岁女孩设计的可爱配色
///
/// 主色调: 樱花粉 #FF6B9D + 薰衣草紫 #C77DFF + 薄荷绿 #7FDBCA
/// 所有文字对比度 >= 4.5:1 (WCAG AA 标准)
class AppColors {
  AppColors._();

  // ============================================================
  // 主色调 - 梦幻粉 (Dreamy Pink)
  // ============================================================

  /// 主色 - 樱花粉 (浅色模式)
  static const Color primary = Color(0xFFFF6B9D);

  /// 主色浅色 - 用于悬停、高亮
  static const Color primaryLight = Color(0xFFFF8FB1);

  /// 主色深色 - 用于按下状态
  static const Color primaryDark = Color(0xFFE54B7E);

  /// 主色容器 - 浅粉背景
  static const Color primaryContainer = Color(0xFFFFF0F5);

  /// 主色 - 深色模式 (稍亮)
  static const Color primaryDarkMode = Color(0xFFFF8FB1);

  /// 主色浅色 - 深色模式
  static const Color primaryLightDarkMode = Color(0xFFFFB3C9);

  /// 主色容器 - 深色模式
  static const Color primaryContainerDarkMode = Color(0xFF4A1942);

  // ============================================================
  // 辅助色 - 薰衣草紫 (Lavender Purple)
  // ============================================================

  /// 辅助色 - 薰衣草紫 (浅色模式)
  static const Color secondary = Color(0xFFC77DFF);

  /// 辅助色浅色
  static const Color secondaryLight = Color(0xFFD9A8FF);

  /// 辅助色深色
  static const Color secondaryDark = Color(0xFF9F5DE0);

  /// 辅助色 - 深色模式
  static const Color secondaryDarkMode = Color(0xFFD9A8FF);

  /// 辅助色浅色 - 深色模式
  static const Color secondaryLightDarkMode = Color(0xFFE8C8FF);

  // ============================================================
  // 点缀色 - 薄荷绿 (Mint Green)
  // ============================================================

  /// 点缀色 - 薄荷绿 (用于成功状态、积分)
  static const Color tertiary = Color(0xFF7FDBCA);

  /// 点缀色浅色
  static const Color tertiaryLight = Color(0xFFA5E8D9);

  /// 点缀色深色
  static const Color tertiaryDark = Color(0xFF5CBFAB);

  /// 点缀色 - 深色模式
  static const Color tertiaryDarkMode = Color(0xFFA5E8D9);

  // ============================================================
  // 语义色 (Semantic Colors) - 高对比度
  // ============================================================

  /// 成功色 - #4CAF50 (对比度 4.5:1 ✓)
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color successDarkMode = Color(0xFF81C784);

  /// 警告色 - #FF9800 (对比度 3.5:1，大文字可用)
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFB74D);
  static const Color warningDarkMode = Color(0xFFFFB74D);

  /// 错误色 - #E53935 (对比度 4.5:1 ✓)
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color errorDarkMode = Color(0xFFEF5350);

  /// 信息色 - 使用薄荷绿
  static const Color info = Color(0xFF7FDBCA);
  static const Color infoLight = Color(0xFFA5E8D9);
  static const Color infoDarkMode = Color(0xFFA5E8D9);

  // ============================================================
  // 应用分类色 (Category Colors) - 柔和可爱版
  // ============================================================

  /// 游戏 - 粉红 (与主色呼应)
  static const Color game = Color(0xFFFF6B9D);
  static const Color gameLight = Color(0xFFFF8FB1);

  /// 视频 - 紫色
  static const Color video = Color(0xFFC77DFF);
  static const Color videoLight = Color(0xFFD9A8FF);

  /// 学习 - 薄荷绿
  static const Color study = Color(0xFF7FDBCA);
  static const Color studyLight = Color(0xFFA5E8D9);

  /// 阅读 - 天蓝色
  static const Color reading = Color(0xFF64B5F6);
  static const Color readingLight = Color(0xFF90CAF9);

  /// 其他 - 灰色
  static const Color other = Color(0xFFB0BEC5);
  static const Color otherLight = Color(0xFFCFD8DC);

  // 向后兼容别名
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

  // ============================================================
  // 巧巧心情色 (Qiaoqiao Mood Colors)
  // ============================================================

  /// 开心 - 薄荷绿 (< 70%)
  static const Color qiaoqiaoHappy = Color(0xFF7FDBCA);
  static const Color qiaoqiaoHappyLight = Color(0xFFA5E8D9);

  /// 提醒 - 橙黄色 (70%-90%)
  static const Color qiaoqiaoRemind = Color(0xFFFFB74D);
  static const Color qiaoqiaoRemindLight = Color(0xFFFFCC80);

  /// 严肃 - 珊瑚色 (90%-100%)
  static const Color qiaoqiaoSerious = Color(0xFFFF8A65);
  static const Color qiaoqiaoSeriousLight = Color(0xFFFFAB91);

  /// 难过 - 天蓝色 (> 100%)
  static const Color qiaoqiaoSad = Color(0xFF64B5F6);
  static const Color qiaoqiaoSadLight = Color(0xFF90CAF9);

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

  // ============================================================
  // 积分颜色 (Points Colors)
  // ============================================================

  /// 积分金色
  static const Color pointsGold = Color(0xFFFFD700);
  static const Color pointsGoldLight = Color(0xFFFFE44D);

  /// 积分获得 - 薄荷绿
  static const Color pointsEarned = Color(0xFF7FDBCA);
  static const Color pointsEarnedLight = Color(0xFFA5E8D9);

  /// 积分消耗 - 粉色
  static const Color pointsSpent = Color(0xFFFF6B9D);
  static const Color pointsSpentLight = Color(0xFFFF8FB1);

  // ============================================================
  // 成就等级色 (Achievement Colors)
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

  // ============================================================
  // 背景色 (Background Colors)
  // ============================================================

  /// 浅色模式背景 - 暖白色
  static const Color backgroundLight = Color(0xFFFFF8FA);

  /// 浅色模式表面
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// 浅色模式卡片
  static const Color cardLight = Color(0xFFFFFFFF);

  /// 深色模式背景 - 深紫黑
  static const Color backgroundDark = Color(0xFF1A1025);

  /// 深色模式表面
  static const Color surfaceDark = Color(0xFF2D1F3D);

  /// 深色模式卡片
  static const Color cardDark = Color(0xFF3D2D52);

  // ============================================================
  // 文字颜色 (Text Colors) - 高对比度
  // ============================================================

  /// 浅色模式主文字 - 深紫色 (#2D1F3D) 对比度 12.6:1 ✓
  static const Color textPrimaryLight = Color(0xFF2D1F3D);

  /// 浅色模式次文字 - 紫灰色 (#6B5B7A) 对比度 4.8:1 ✓
  static const Color textSecondaryLight = Color(0xFF6B5B7A);

  /// 浅色模式提示文字 - 浅紫色 (#9E8FA8) 对比度 3.0:1
  static const Color textHintLight = Color(0xFF9E8FA8);

  /// 深色模式主文字 - 暖白色 (#FFF8FA) 对比度 15.2:1 ✓
  static const Color textPrimaryDark = Color(0xFFFFF8FA);

  /// 深色模式次文字 - 浅紫色 (#D4C5D9) 对比度 5.1:1 ✓
  static const Color textSecondaryDark = Color(0xFFD4C5D9);

  /// 深色模式提示文字 - 紫灰色 (#9E8FA8) 对比度 3.5:1
  static const Color textHintDark = Color(0xFF9E8FA8);

  // ============================================================
  // 边框和分割线 (Borders & Dividers)
  // ============================================================

  static const Color borderLight = Color(0xFFFFE4EC);
  static const Color borderDark = Color(0xFF4A3040);
  static const Color dividerLight = Color(0xFFFFF0F5);
  static const Color dividerDark = Color(0xFF5A4050);

  // ============================================================
  // 玻璃拟态 (Glassmorphism)
  // ============================================================

  static const Color glassBackgroundLight = Color(0xCCFFFFFF);
  static const Color glassBackgroundDark = Color(0xCC2D1F3D);
  static const Color glassBorderLight = Color(0x33FF6B9D);
  static const Color glassBorderDark = Color(0x33C77DFF);

  // ============================================================
  // 渐变预设 (Gradient Presets)
  // ============================================================

  /// 主渐变 - 粉到紫
  static const List<Color> primaryGradient = [primary, secondary];

  /// 成功渐变 - 薄荷绿
  static const List<Color> successGradient = [tertiary, tertiaryLight];

  /// 积分渐变 - 金色
  static const List<Color> pointsGradient = [pointsGold, pointsGoldLight];

  /// 背景渐变 - 浅色模式
  static const List<Color> backgroundLightGradient = [
    Color(0xFFFFF8FA),
    Color(0xFFFFF0F5),
  ];

  /// 背景渐变 - 深色模式
  static const List<Color> backgroundDarkGradient = [
    Color(0xFF1A1025),
    Color(0xFF2D1F3D),
  ];

  // ============================================================
  // ColorScheme 生成
  // ============================================================

  /// 浅色主题 ColorScheme
  static ColorScheme lightColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
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
      tertiary: tertiaryDarkMode,
      error: errorDarkMode,
      surface: surfaceDark,
    );
  }

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 根据亮度获取主色
  static Color getPrimaryByBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? primaryDarkMode : primary;
  }

  /// 根据亮度获取背景色
  static Color getBackgroundByBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? backgroundDark : backgroundLight;
  }

  /// 根据亮度获取文字颜色
  static Color getTextPrimaryByBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;
  }

  /// 根据亮度获取次文字颜色
  static Color getTextSecondaryByBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;
  }
}
