import 'package:flutter/material.dart';

/// Kawaii Dream 设计令牌系统
/// 专为11岁女孩设计的可爱、梦幻、活泼的设计语言
class DesignTokens {
  DesignTokens._();

  // ============================================================
  // 间距系统 (8dp 基础)
  // ============================================================

  /// 无间距
  static const double space0 = 0.0;

  /// 超小间距 - 2dp
  static const double space2 = 2.0;

  /// 超小间距 - 4dp
  static const double space4 = 4.0;

  /// 小中间距 - 6dp
  static const double space6 = 6.0;

  /// 小间距 - 8dp
  static const double space8 = 8.0;

  /// 标准间距 - 10dp
  static const double space10 = 10.0;

  /// 中小间距 - 12dp
  static const double space12 = 12.0;

  /// 中间距 - 14dp
  static const double space14 = 14.0;

  /// 标准间距 - 16dp
  static const double space16 = 16.0;

  /// 中大间距 - 20dp
  static const double space20 = 20.0;

  /// 大间距 - 24dp
  static const double space24 = 24.0;

  /// 超大间距 - 32dp
  static const double space32 = 32.0;

  /// 特大间距 - 48dp
  static const double space48 = 48.0;

  /// 巨大间距 - 64dp
  static const double space64 = 64.0;

  // ============================================================
  // 圆角系统 (超大圆角 - 可爱风格)
  // ============================================================

  /// 微圆角 - 4dp
  static const double radius4 = 4.0;

  /// 小圆角 - 6dp
  static const double radius6 = 6.0;

  /// 小圆角 - 8dp
  static const double radius8 = 8.0;

  /// 中圆角 - 10dp
  static const double radius10 = 10.0;

  /// 标准圆角 - 12dp
  static const double radius12 = 12.0;

  /// 中大圆角 - 14dp
  static const double radius14 = 14.0;

  /// 大圆角 - 16dp
  static const double radius16 = 16.0;

  /// 超大圆角 - 20dp
  static const double radius20 = 20.0;

  /// 特大圆角 - 24dp
  static const double radius24 = 24.0;

  /// 超特大圆角 - 32dp
  static const double radius32 = 32.0;

  /// 胶囊圆角 - 100dp (用于按钮、标签)
  static const double radiusPill = 100.0;

  /// 全圆角
  static const double radiusFull = 9999.0;

  // 向后兼容
  /// @deprecated 使用 radiusPill 替代
  static const double radiusCapsule = radiusPill;

  // ============================================================
  // 边框宽度
  // ============================================================

  /// 细边框 - 1dp
  static const double borderThin = 1.0;

  /// 标准边框 - 1.5dp
  static const double borderMedium = 1.5;

  /// 粗边框 - 2dp
  static const double borderThick = 2.0;

  /// 超粗边框 - 3dp
  static const double borderExtraThick = 3.0;

  // ============================================================
  // 图标尺寸
  // ============================================================

  /// 超小图标 - 14dp
  static const double iconXSmall = 14.0;

  /// 小图标 - 18dp
  static const double iconSmall = 18.0;

  /// 标准图标 - 24dp
  static const double iconMedium = 24.0;

  /// 大图标 - 32dp
  static const double iconLarge = 32.0;

  /// 超大图标 - 48dp
  static const double iconXLarge = 48.0;

  /// 特大图标 - 64dp
  static const double iconXXLarge = 64.0;

  // ============================================================
  // 触摸目标尺寸 (符合 WCAG 无障碍标准)
  // ============================================================

  /// 最小触摸目标 - 48dp (Android 标准)
  static const double touchTargetMin = 48.0;

  /// 舒适触摸目标 - 52dp
  static const double touchTargetComfortable = 52.0;

  /// 大触摸目标 - 56dp
  static const double touchTargetLarge = 56.0;

  // ============================================================
  // 按钮尺寸 (胶囊形)
  // ============================================================

  /// 小按钮高度 - 40dp
  static const double buttonHeightSmall = 40.0;

  /// 标准按钮高度 - 52dp (增大触摸区域)
  static const double buttonHeight = 52.0;

  /// 大按钮高度 - 60dp
  static const double buttonHeightLarge = 60.0;

  /// 按钮最小宽度 - 120dp
  static const double buttonMinWidth = 120.0;

  /// 按钮水平内边距 - 24dp
  static const double buttonPaddingH = 24.0;

  /// 按钮垂直内边距 - 14dp
  static const double buttonPaddingV = 14.0;

  // ============================================================
  // 列表项尺寸
  // ============================================================

  /// 列表项高度 - 56dp
  static const double listItemHeight = 56.0;

  /// 列表项高度（两行）- 72dp
  static const double listItemHeightTwoLine = 72.0;

  /// 列表项高度（三行）- 88dp
  static const double listItemHeightThreeLine = 88.0;

  // ============================================================
  // 卡片尺寸
  // ============================================================

  /// 卡片内边距 - 20dp
  static const double cardPadding = 20.0;

  /// 卡片外部边距 - 16dp
  static const double cardMargin = 16.0;

  /// 卡片最小高度 - 80dp
  static const double cardMinHeight = 80.0;

  // ============================================================
  // 动画时长 (Kawaii Dream 动效系统)
  // ============================================================

  /// 即时反馈 - 50ms
  static const Duration instant = Duration(milliseconds: 50);

  /// 微交互 - 100ms
  static const Duration micro = Duration(milliseconds: 100);

  /// 快速交互 - 150ms
  static const Duration quick = Duration(milliseconds: 150);

  /// 标准动画 - 300ms
  static const Duration normal = Duration(milliseconds: 300);

  /// 慢速动画 - 500ms
  static const Duration slow = Duration(milliseconds: 500);

  /// 更慢动画 - 800ms (强调过渡)
  static const Duration slower = Duration(milliseconds: 800);

  /// 页面过渡 - 400ms
  static const Duration pageTransition = Duration(milliseconds: 400);

  /// 庆祝动画 - 1200ms
  static const Duration celebration = Duration(milliseconds: 1200);

  // 向后兼容别名
  /// @deprecated 使用 quick 替代
  static const Duration animationQuick = quick;

  /// @deprecated 使用 normal 替代
  static const Duration animationNormal = normal;

  /// @deprecated 使用 slow 替代
  static const Duration animationSlow = slow;

  /// @deprecated 使用 pageTransition 替代
  static const Duration animationPageTransition = pageTransition;

  // ============================================================
  // 动画曲线 (Kawaii Dream 活泼曲线)
  // ============================================================

  /// 入场曲线 - easeOutCubic (平滑减速)
  static const Curve curveEnter = Curves.easeOutCubic;

  /// 退场曲线 - easeInCubic (平滑加速)
  static const Curve curveExit = Curves.easeInCubic;

  /// 标准曲线 - easeInOutCubic
  static const Curve curveStandard = Curves.easeInOutCubic;

  /// 弹性曲线 - elasticOut (可爱弹跳)
  static const Curve curveElastic = Curves.elasticOut;

  /// 快入慢出曲线
  static const Curve curveFastOutSlowIn = Curves.fastOutSlowIn;

  /// 弹跳曲线 - bounceOut
  static const Curve curveBounce = Curves.bounceOut;

  /// 减速曲线 - easeOut
  static const Curve curveDecelerate = Curves.easeOut;

  /// 加速曲线 - easeIn
  static const Curve curveAccelerate = Curves.easeIn;

  /// 俏皮曲线 - 超调量弹跳 (Playful)
  static const Curve curvePlayful = Cubic(0.68, -0.6, 0.32, 1.6);

  /// 果冻曲线 - 超调量更大
  static const Curve curveJelly = Cubic(0.5, 1.5, 0.5, 1.0);

  /// 平滑弹性曲线
  static const Curve curveSmoothBounce = Cubic(0.34, 1.56, 0.64, 1.0);

  // ============================================================
  // 交互反馈值
  // ============================================================

  /// 按钮按下缩放值
  static const double buttonPressScale = 0.96;

  /// 卡片交互缩放值
  static const double cardPressScale = 0.98;

  /// 列表项缩放值
  static const double listItemPressScale = 0.97;

  /// 弹跳过冲值
  static const double bounceOvershoot = 1.1;

  /// 果冻过冲值
  static const double jellyOvershoot = 1.15;

  /// 脉冲缩放值
  static const double pulseScale = 1.05;

  /// 淡入起始透明度
  static const double fadeInStart = 0.0;

  /// 淡入结束透明度
  static const double fadeInEnd = 1.0;

  /// 滑动进入距离
  static const double slideInDistance = 24.0;

  // ============================================================
  // 列表交错动画
  // ============================================================

  /// 列表项交错间隔（毫秒）
  static const int listStaggerInterval = 30;

  /// 列表项最大交错延迟（毫秒）
  static const int listStaggerMaxDelay = 300;

  /// 获取列表项交错延迟
  static Duration getListStaggerDelay(int index, [int? totalCount]) {
    final delay = (index * listStaggerInterval).clamp(0, listStaggerMaxDelay);
    return Duration(milliseconds: delay);
  }

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 获取圆角 BorderRadius
  static BorderRadius getBorderRadius(double radius) {
    return BorderRadius.circular(radius);
  }

  /// 获取标准圆角
  static BorderRadius get standardRadius => BorderRadius.circular(radius12);

  /// 获取大圆角
  static BorderRadius get largeRadius => BorderRadius.circular(radius16);

  /// 获取超大圆角
  static BorderRadius get xLargeRadius => BorderRadius.circular(radius20);

  /// 获取胶囊圆角
  static BorderRadius get pillRadius => BorderRadius.circular(radiusPill);

  /// 获取标准内边距
  static EdgeInsets get standardPadding => const EdgeInsets.all(space16);

  /// 获取大内边距
  static EdgeInsets get largePadding => const EdgeInsets.all(space24);

  /// 获取卡片内边距
  static EdgeInsets get cardPaddingInsets => const EdgeInsets.all(cardPadding);

  /// 获取水平间距
  static EdgeInsets horizontalPadding(double spacing) {
    return EdgeInsets.symmetric(horizontal: spacing);
  }

  /// 获取垂直间距
  static EdgeInsets verticalPadding(double spacing) {
    return EdgeInsets.symmetric(vertical: spacing);
  }
}
