import 'package:flutter/material.dart';

/// 设计令牌 - 间距、圆角、动画时长等
class DesignTokens {
  DesignTokens._();

  // ========== 间距系统 ==========

  /// 调试间距
  static const double space0 = 0.0;

  /// 超小间距
  static const double space2 = 2.0;

  /// 小间距
  static const double space4 = 4.0;

  /// 小中间距
  static const double space6 = 6.0;

  /// 中等间距
  static const double space8 = 8.0;

  /// 标准间距
  static const double space10 = 10.0;

  /// 标准间距
  static const double space12 = 12.0;

  /// 大间距
  static const double space16 = 16.0;

  /// 较大间距
  static const double space20 = 20.0;

  /// 超大间距
  static const double space24 = 24.0;

  /// 特大间距
  static const double space32 = 32.0;

  /// 巨大间距
  static const double space48 = 48.0;

  // ========== 额外间距 ==========

  /// 标准间距14
  static const double space14 = 14.0;

  // ========== 圆角系统 ==========

  /// 超小圆角
  static const double radius4 = 4.0;

  /// 小圆角
  static const double radius6 = 6.0;

  /// 小圆角
  static const double radius8 = 8.0;

  /// 中圆角
  static const double radius10 = 10.0;

  /// 标准圆角
  static const double radius12 = 12.0;

  /// 中大圆角
  static const double radius14 = 14.0;

  /// 大圆角
  static const double radius16 = 16.0;

  /// 超大圆角
  static const double radius20 = 20.0;

  /// 特大圆角
  static const double radius24 = 24.0;

  /// 胶囊圆角
  static const double radiusCapsule = 16.0;

  /// 药丸圆角
  static const double radiusPill = 24.0;

  /// 全圆角
  static const double radiusFull = 9999.0;

  // ========== 边框宽度 ==========

  /// 细边框
  static const double borderThin = 1.0;

  /// 标准边框
  static const double borderMedium = 2.0;

  /// 粗边框
  static const double borderThick = 3.0;

  // ========== 图标尺寸 ==========

  /// 小图标
  static const double iconSmall = 16.0;

  /// 标准图标
  static const double iconMedium = 24.0;

  /// 大图标
  static const double iconLarge = 32.0;

  // ========== 触摸目标尺寸 ==========

  /// 最小触摸目标 (iOS)
  static const double touchTargetMin = 44.0;

  /// 舒适触摸目标
  static const double touchTargetComfortable = 48.0;

  // ========== 按钮尺寸 ==========

  /// 按钮高度
  static const double buttonHeight = 48.0;

  /// 大按钮高度
  static const double buttonHeightLarge = 56.0;

  /// 小按钮高度
  static const double buttonHeightSmall = 40.0;

  // ========== 列表项尺寸 ==========

  /// 列表项高度
  static const double listItemHeight = 64.0;

  /// 列表项高度（两行）
  static const double listItemHeightTwoLine = 72.0;

  // ========== 卡片尺寸 ==========

  /// 卡片内边距
  static const double cardPadding = 20.0;

  /// 卡片外部边距
  static const double cardMargin = 16.0;

  // ========== 动画时长 ==========

  /// 微交互动画
  static const Duration animationQuick = Duration(milliseconds: 150);

  /// 标准动画
  static const Duration animationNormal = Duration(milliseconds: 250);

  /// 慢动画
  static const Duration animationSlow = Duration(milliseconds: 400);

  /// 页面过渡动画
  static const Duration animationPageTransition = Duration(milliseconds: 350);

  // ========== 动画曲线 ==========

  /// 入场曲线
  static const Curve curveEnter = Curves.easeOutCubic;

  /// 退场曲线
  static const Curve curveExit = Curves.easeInCubic;

  /// 标准曲线
  static const Curve curveStandard = Curves.easeInOutCubic;

  /// 弹性曲线
  static const Curve curveElastic = Curves.elasticOut;

  /// 快入慢出曲线
  static const Curve curveFastOutSlowIn = Curves.fastOutSlowIn;
}
