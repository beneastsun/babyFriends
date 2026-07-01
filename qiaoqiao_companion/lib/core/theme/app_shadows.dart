import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_color_schemes.dart';

/// Kawaii Dream 阴影系统
/// 柔和的粉紫色发光阴影，营造梦幻可爱氛围
class AppShadows {
  AppShadows._();

  // ============================================================
  // 基础阴影 - 柔和粉紫色
  // ============================================================

  /// 浅色模式基础阴影
  static BoxShadow light = BoxShadow(
    color: AppColors.secondary.withOpacity(0.08),
    blurRadius: 20,
    offset: const Offset(0, 4),
  );

  /// 深色模式基础阴影
  static BoxShadow dark = BoxShadow(
    color: Colors.black.withOpacity(0.30),
    blurRadius: 20,
    offset: const Offset(0, 4),
  );

  // ============================================================
  // 按钮阴影 - 带发光效果
  // ============================================================

  /// 主按钮阴影 - 粉色发光
  static List<BoxShadow> buttonPrimary = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.30),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  /// 主按钮阴影 - 按下状态
  static List<BoxShadow> buttonPrimaryPressed = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.15),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// 次要按钮阴影 - 紫色发光
  static List<BoxShadow> buttonSecondary = [
    BoxShadow(
      color: AppColors.secondary.withOpacity(0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// 胶囊按钮阴影
  static List<BoxShadow> buttonCapsule = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  /// 通用按钮阴影别名
  static List<BoxShadow> get button => buttonPrimary;

  // ============================================================
  // 卡片阴影 - 柔和梦幻
  // ============================================================

  /// 标准卡片阴影
  static List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.secondary.withOpacity(0.06),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  /// 交互卡片阴影
  static List<BoxShadow> cardInteractive = [
    BoxShadow(
      color: AppColors.secondary.withOpacity(0.10),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// 渐变卡片阴影 - 带发光
  static List<BoxShadow> cardGradient = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.25),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// 概览卡片阴影（渐变背景）
  static List<BoxShadow> cardOverview = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.30),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// 用户卡片阴影
  static List<BoxShadow> cardUser = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.20),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  /// 悬浮卡片阴影 - 更明显的浮起效果
  static List<BoxShadow> cardElevated = [
    BoxShadow(
      color: AppColors.secondary.withOpacity(0.12),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];

  // ============================================================
  // 弹窗阴影 - 柔和发光
  // ============================================================

  /// 对话框阴影
  static List<BoxShadow> dialog = [
    BoxShadow(
      color: AppColors.secondary.withOpacity(0.20),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  /// 玻璃拟态对话框阴影
  static List<BoxShadow> dialogGlass = [
    BoxShadow(
      color: AppColors.secondary.withOpacity(0.15),
      blurRadius: 20,
      offset: const Offset(0, 5),
    ),
  ];

  /// 提醒弹窗阴影 - 橙黄色
  static List<BoxShadow> reminder = [
    BoxShadow(
      color: AppColors.qiaoqiaoRemind.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  /// 提醒弹窗 - 严肃
  static List<BoxShadow> reminderSerious = [
    BoxShadow(
      color: AppColors.qiaoqiaoSerious.withOpacity(0.30),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  /// 提醒弹窗 - 锁定
  static List<BoxShadow> reminderLocked = [
    BoxShadow(
      color: AppColors.qiaoqiaoSad.withOpacity(0.30),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  /// 底部弹窗阴影
  static List<BoxShadow> bottomSheet = [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];

  // ============================================================
  // 导航阴影
  // ============================================================

  /// 悬浮导航栏阴影
  static List<BoxShadow> floatingNav = [
    BoxShadow(
      color: AppColors.secondary.withOpacity(0.15),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// AppBar阴影
  static List<BoxShadow> appBar = [
    BoxShadow(
      color: AppColors.secondary.withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  /// 底部导航栏阴影
  static List<BoxShadow> bottomNav = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, -4),
    ),
  ];

  // ============================================================
  // 列表项阴影
  // ============================================================

  /// 列表项阴影
  static List<BoxShadow> listItem = [
    BoxShadow(
      color: AppColors.secondary.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // ============================================================
  // 发光效果 (Kawaii Dream 特色)
  // ============================================================

  /// 主色发光 - 粉色
  static List<BoxShadow> glowPrimary = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.40),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  /// 辅助色发光 - 紫色
  static List<BoxShadow> glowSecondary = [
    BoxShadow(
      color: AppColors.secondary.withOpacity(0.40),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  /// 成功发光 - 薄荷绿
  static List<BoxShadow> glowSuccess = [
    BoxShadow(
      color: AppColors.tertiary.withOpacity(0.40),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  /// 积分发光 - 金色
  static List<BoxShadow> glowPoints = [
    BoxShadow(
      color: AppColors.pointsGold.withOpacity(0.50),
      blurRadius: 16,
      spreadRadius: 2,
    ),
  ];

  /// 聚焦发光
  static List<BoxShadow> focusGlow = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.30),
      blurRadius: 8,
      spreadRadius: 1,
    ),
  ];

  // ============================================================
  // 成功/错误状态
  // ============================================================

  /// 成功阴影 - 薄荷绿
  static List<BoxShadow> success = [
    BoxShadow(
      color: AppColors.success.withOpacity(0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// 错误阴影 - 珊瑚红
  static List<BoxShadow> error = [
    BoxShadow(
      color: AppColors.error.withOpacity(0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 根据亮度获取基础阴影
  static BoxShadow byBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  /// 根据亮度获取卡片阴影
  static List<BoxShadow> cardByBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];
    }
    return card;
  }

  /// 根据主题类型获取按钮阴影
  static List<BoxShadow> buttonByTheme(AppThemeType themeType) {
    return buttonPrimary;
  }

  /// 根据主题类型获取卡片阴影
  static List<BoxShadow> cardByTheme(AppThemeType themeType, Brightness brightness) {
    return cardByBrightness(brightness);
  }

  /// 根据使用百分比获取进度条阴影
  static List<BoxShadow> progressBar(double percentage) {
    Color shadowColor;
    if (percentage < 0.7) {
      shadowColor = AppColors.success;
    } else if (percentage < 0.9) {
      shadowColor = AppColors.warning;
    } else {
      shadowColor = AppColors.error;
    }
    return [
      BoxShadow(
        color: shadowColor.withOpacity(0.35),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// 根据巧巧心情获取阴影
  static List<BoxShadow> qiaoqiaoMood(double usagePercentage) {
    Color shadowColor = AppColors.getQiaoqiaoMoodColor(usagePercentage);
    return [
      BoxShadow(
        color: shadowColor.withOpacity(0.30),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// 根据主题类型获取发光阴影
  static List<BoxShadow> getGlowByTheme(AppThemeType themeType, bool isDark) {
    final scheme = AppColorSchemes.getScheme(themeType);
    final color = isDark ? scheme.primaryDarkMode : scheme.primary;
    return [
      BoxShadow(
        color: color.withOpacity(0.35),
        blurRadius: 20,
        spreadRadius: 2,
      ),
    ];
  }

  /// 创建自定义阴影
  static BoxShadow custom({
    required Color color,
    double blurRadius = 20,
    Offset offset = const Offset(0, 4),
    double spreadRadius = 0,
  }) {
    return BoxShadow(
      color: color,
      blurRadius: blurRadius,
      offset: offset,
      spreadRadius: spreadRadius,
    );
  }
}
