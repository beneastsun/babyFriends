import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_color_schemes.dart';

/// 应用渐变定义
///
/// **已废弃**: 请使用 [AppSolidColors] 替代渐变系统。
/// Material 3 风格推荐使用纯色 + 阴影，///
/// 迁移指南:
/// - `AppGradients.primary` → `AppSolidColors.getPrimaryColor(themeType, isDark)`
/// - `AppGradients.getPrimaryGradient(themeType)` → `AppSolidColors.getPrimaryColor(themeType, isDark)`
/// - 渐变背景 → 纯色背景 + AppShadows
@Deprecated('Use AppSolidColors instead for Material 3 solid color design')
class AppGradients {
  AppGradients._();

  // ========== 主渐变（静态 - 向后兼容）==========

  /// 主渐变 - 星空蓝到极光绿
  static const LinearGradient primary = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 次要渐变 - 极光绿
  static const LinearGradient secondary = LinearGradient(
    colors: [AppColors.secondary, AppColors.secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 主渐变 - 水平方向
  static const LinearGradient primaryHorizontal = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// 主渐变 - 垂直方向
  static const LinearGradient primaryVertical = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ========== 动态主题渐变 ==========

  /// 获取主渐变（根据主题类型）
  static LinearGradient getPrimaryGradient(AppThemeType themeType) {
    final colors = AppColorSchemes.getScheme(themeType);
    return LinearGradient(
      colors: [colors.primary, colors.secondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// 获取次要渐变（根据主题类型）
  static LinearGradient getSecondaryGradient(AppThemeType themeType) {
    final colors = AppColorSchemes.getScheme(themeType);
    return LinearGradient(
      colors: [colors.secondary, colors.secondaryLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// 获取背景渐变（根据主题类型和亮度）
  static LinearGradient getBackgroundGradient(AppThemeType themeType, bool isDark) {
    final colors = AppColorSchemes.getScheme(themeType);
    if (isDark) {
      return LinearGradient(
        colors: [colors.backgroundDark, colors.surfaceDark],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    } else {
      return LinearGradient(
        colors: [colors.backgroundLight, colors.surfaceLight],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
  }

  /// 获取卡片渐变（根据主题类型）
  static LinearGradient getCardGradient(AppThemeType themeType, bool isDark) {
    final colors = AppColorSchemes.getScheme(themeType);
    if (isDark) {
      return LinearGradient(
        colors: [colors.cardDark, colors.surfaceDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return LinearGradient(
        colors: [colors.cardLight, colors.surfaceLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  // ========== 背景渐变 ==========

  /// 浅色模式背景渐变
  static const LinearGradient backgroundLight = LinearGradient(
    colors: [Color(0xFFE3F2FD), Color(0xFFE8F5E9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// 深色模式背景渐变
  static const LinearGradient backgroundDark = LinearGradient(
    colors: [Color(0xFF0D1B2A), Color(0xFF1B2838)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// 卡片深色渐变
  static const LinearGradient cardDark = LinearGradient(
    colors: [Color(0xFF1E3A5F), Color(0xFF1B4332)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ========== 巧巧心情渐变（各主题）==========

  /// 获取巧巧开心渐变
  static LinearGradient getQiaoqiaoHappyGradient(AppThemeType themeType) {
    final colors = AppColorSchemes.getScheme(themeType);
    return LinearGradient(
      colors: [colors.secondary, colors.secondaryLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// 获取巧巧提醒渐变
  static LinearGradient getQiaoqiaoRemindGradient(AppThemeType themeType) {
    return const LinearGradient(
      colors: [AppColors.warning, AppColors.warningDarkMode],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// 获取巧巧严肃渐变
  static LinearGradient getQiaoqiaoSeriousGradient(AppThemeType themeType) {
    return const LinearGradient(
      colors: [AppColors.qiaoqiaoSerious, AppColors.qiaoqiaoSeriousLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// 获取巧巧难过渐变
  static LinearGradient getQiaoqiaoSadGradient(AppThemeType themeType) {
    final colors = AppColorSchemes.getScheme(themeType);
    return LinearGradient(
      colors: [colors.primaryLight, colors.primary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// 获取巧巧心情渐变（根据使用比例）
  static LinearGradient getQiaoqiaoMoodGradient(AppThemeType themeType, double usagePercentage) {
    if (usagePercentage < 0.7) {
      return getQiaoqiaoHappyGradient(themeType);
    } else if (usagePercentage < 0.9) {
      return getQiaoqiaoRemindGradient(themeType);
    } else if (usagePercentage < 1.0) {
      return getQiaoqiaoSeriousGradient(themeType);
    } else {
      return getQiaoqiaoSadGradient(themeType);
    }
  }

  // ========== 分类渐变 ==========

  /// 游戏渐变
  static const LinearGradient game = LinearGradient(
    colors: [AppColors.game, AppColors.gameLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 视频渐变
  static const LinearGradient video = LinearGradient(
    colors: [AppColors.video, AppColors.videoLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 学习渐变
  static const LinearGradient study = LinearGradient(
    colors: [AppColors.study, AppColors.studyLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 阅读渐变
  static const LinearGradient reading = LinearGradient(
    colors: [AppColors.reading, AppColors.readingLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 获取分类渐变（静态 - 向后兼容）
  static LinearGradient getCategoryGradient(String category) {
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
        return primary;
    }
  }

  /// 获取分类渐变（动态 - 支持主题）
  static LinearGradient getCategoryGradientWithTheme(String category, AppThemeType themeType) {
    // 统一使用标准分类颜色
    return getCategoryGradient(category);
  }

  // ========== 巧巧心情渐变（静态 - 向后兼容）==========

  /// 开心渐变
  static const LinearGradient qiaoqiaoHappy = LinearGradient(
    colors: [AppColors.qiaoqiaoHappy, AppColors.qiaoqiaoHappyLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 提醒渐变
  static const LinearGradient qiaoqiaoRemind = LinearGradient(
    colors: [AppColors.qiaoqiaoRemind, AppColors.qiaoqiaoRemindLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 严肃渐变
  static const LinearGradient qiaoqiaoSerious = LinearGradient(
    colors: [AppColors.qiaoqiaoSerious, AppColors.qiaoqiaoSeriousLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 难过渐变
  static const LinearGradient qiaoqiaoSad = LinearGradient(
    colors: [AppColors.qiaoqiaoSad, AppColors.qiaoqiaoSadLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 获取巧巧心情渐变（向后兼容）
  static LinearGradient getQiaoqiaoMoodGradientLegacy(double usagePercentage) {
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

  // ========== 语义渐变（静态 - 向后兼容）==========

  /// 成功渐变
  static const LinearGradient success = LinearGradient(
    colors: [AppColors.success, AppColors.secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 警告渐变
  static const LinearGradient warning = LinearGradient(
    colors: [AppColors.warning, AppColors.warningDarkMode],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 错误渐变
  static const LinearGradient error = LinearGradient(
    colors: [AppColors.error, Color(0xFFD50000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 信息渐变
  static const LinearGradient info = LinearGradient(
    colors: [AppColors.info, Color(0xFF00B0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ========== 语义渐变（动态 - 支持主题）==========

  /// 获取成功渐变（根据主题类型）
  static LinearGradient getSuccessGradient(AppThemeType themeType) {
    final colors = AppColorSchemes.getScheme(themeType);
    return LinearGradient(
      colors: [colors.secondary, colors.secondaryLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// 获取警告渐变（根据主题类型）
  static LinearGradient getWarningGradient(AppThemeType themeType) {
    return const LinearGradient(
      colors: [AppColors.warning, AppColors.warningDarkMode],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// 获取错误渐变（根据主题类型）
  static LinearGradient getErrorGradient(AppThemeType themeType) {
    return const LinearGradient(
      colors: [AppColors.error, Color(0xFFD50000)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// 获取信息渐变（根据主题类型）
  static LinearGradient getInfoGradient(AppThemeType themeType) {
    return const LinearGradient(
      colors: [AppColors.info, Color(0xFF00B0FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // ========== 积分渐变（静态）==========

  /// 积分金色渐变
  static const LinearGradient pointsGold = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFAB00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 积分获得渐变
  static const LinearGradient pointsEarned = LinearGradient(
    colors: [AppColors.pointsEarned, AppColors.secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 积分消耗渐变
  static const LinearGradient pointsSpent = LinearGradient(
    colors: [AppColors.pointsSpent, Color(0xFFD50000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ========== 积分渐变（动态 - 支持主题）==========

  /// 获取积分金色渐变
  static LinearGradient getPointsGoldGradient(AppThemeType themeType) {
    return pointsGold;
  }

  /// 获取积分获得渐变
  static LinearGradient getPointsEarnedGradient(AppThemeType themeType) {
    final colors = AppColorSchemes.getScheme(themeType);
    return LinearGradient(
      colors: [colors.secondary, colors.secondaryLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// 获取积分消耗渐变
  static LinearGradient getPointsSpentGradient(AppThemeType themeType) {
    return pointsSpent;
  }

  // ========== 特殊效果渐变 ==========

  /// 玻璃效果渐变
  static const LinearGradient glassLight = LinearGradient(
    colors: [Color(0x88FFFFFF), Color(0x44FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassDark = LinearGradient(
    colors: [Color(0x881B2838), Color(0x440D1B2A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 导航栏渐变
  static const LinearGradient navBarLight = LinearGradient(
    colors: [Color(0xDDFFFFFF), Color(0xEEFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient navBarDark = LinearGradient(
    colors: [Color(0xDD1B2838), Color(0xEE0D1B2A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Shimmer 渐变（骨架屏）
  static const LinearGradient shimmer = LinearGradient(
    colors: [
      Color(0xFFE0E0E0),
      Color(0xFFF5F5F5),
      Color(0xFFE0E0E0),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient shimmerDark = LinearGradient(
    colors: [
      Color(0xFF37474F),
      Color(0xFF455A64),
      Color(0xFF37474F),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // ========== 进度条渐变 ==========

  /// 进度条渐变（静态 - 基于使用比例）
  static LinearGradient progressBar(double percentage) {
    if (percentage < 0.7) {
      return success;
    } else if (percentage < 0.9) {
      return warning;
    } else {
      return error;
    }
  }

  /// 进度条渐变（动态 - 支持主题）
  static LinearGradient getProgressBarGradient(double percentage, AppThemeType themeType) {
    if (percentage < 0.7) {
      return success;
    } else if (percentage < 0.9) {
      return warning;
    } else {
      return error;
    }
  }

  // ========== 概览卡片渐变 ==========

  /// 概览卡片渐变
  static const LinearGradient overviewCard = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 1.0],
  );

  /// 用户卡片渐变
  static const LinearGradient userCard = LinearGradient(
    colors: [AppColors.primary, Color(0xFF1565C0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 获取用户卡片渐变（根据主题类型）
  static LinearGradient getUserCardGradient(AppThemeType themeType) {
    final colors = AppColorSchemes.getScheme(themeType);
    return LinearGradient(
      colors: [colors.primary, colors.primaryDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// 获取概览卡片渐变（根据主题类型）
  static LinearGradient getOverviewCardGradient(AppThemeType themeType) {
    final colors = AppColorSchemes.getScheme(themeType);
    return LinearGradient(
      colors: [colors.primary, colors.secondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: const [0.0, 1.0],
    );
  }

  // ========== 成就渐变（静态）==========

  /// 成就卡片渐变
  static const LinearGradient achievement = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 铜牌渐变
  static const LinearGradient bronze = LinearGradient(
    colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 银牌渐变
  static const LinearGradient silver = LinearGradient(
    colors: [Color(0xFFC0C0C0), Color(0xFF808080)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 金牌渐变
  static const LinearGradient gold = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ========== 成就渐变（动态 - 支持主题)==========

  /// 获取成就卡片渐变
  static LinearGradient getAchievementGradient(AppThemeType themeType) {
    return achievement;
  }

  /// 获取奖牌渐变
  static LinearGradient getMedalGradient(String medalType, AppThemeType themeType) {
    switch (medalType.toLowerCase()) {
      case 'bronze':
        return bronze;
      case 'silver':
        return silver;
      case 'gold':
        return gold;
      default:
        return primary;
    }
  }

  // ========== 兑换券卡片渐变 ==========

  /// 兑换券卡片渐变（根据主题类型）
  static LinearGradient getCouponCardGradient(AppThemeType themeType) {
    final colors = AppColorSchemes.getScheme(themeType);
    return LinearGradient(
      colors: [colors.primary, colors.primaryDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
