import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// 应用动画系统 - Material 3 风格轻量动效
/// 提供统一的动画定义和预设效果
class AppAnimations {
  AppAnimations._();

  // ========== 时长定义（复用 DesignTokens）==========

  /// 极快动画 - 100ms（微交互）
  static const Duration micro = Duration(milliseconds: 100);

  /// 快速动画 - 150ms（按钮点击）
  static Duration get quick => DesignTokens.animationQuick;

  /// 标准动画 - 250ms（页面过渡）
  static Duration get normal => DesignTokens.animationNormal;

  /// 慢动画 - 400ms（复杂过渡）
  static Duration get slow => DesignTokens.animationSlow;

  /// 页面过渡动画
  static Duration get pageTransition => DesignTokens.animationPageTransition;

  // ========== 曲线定义（复用 DesignTokens）==========

  /// 入场曲线 - easeOutCubic
  static Curve get enter => DesignTokens.curveEnter;

  /// 退场曲线 - easeInCubic
  static Curve get exit => DesignTokens.curveExit;

  /// 标准曲线 - easeInOutCubic
  static Curve get standard => DesignTokens.curveStandard;

  /// 弹性曲线 - elasticOut
  static Curve get elastic => DesignTokens.curveElastic;

  /// 快入慢出曲线
  static Curve get fastOutSlowIn => DesignTokens.curveFastOutSlowIn;

  // ========== Material 3 标准曲线 ==========

  /// 强调曲线 - 用于需要吸引注意力的动画
  static const Curve emphasized = Curves.easeOutQuart;

  /// 减速曲线 - 用于进入屏幕的元素
  static const Curve decelerate = Curves.easeOut;

  /// 加速曲线 - 用于离开屏幕的元素
  static const Curve accelerate = Curves.easeIn;

  /// 线性曲线 - 慎用，通常感觉不自然
  static const Curve linear = Curves.linear;

  // ========== 预设动画值 ==========

  /// 按钮按下缩放值
  static const double buttonPressScale = 0.96;

  /// 卡片交互缩放值
  static const double cardPressScale = 0.98;

  /// 列表项缩放值
  static const double listItemPressScale = 0.97;

  /// 淡入起始透明度
  static const double fadeInStart = 0.0;

  /// 淡入结束透明度
  static const double fadeInEnd = 1.0;

  /// 滑动进入距离
  static const double slideInDistance = 24.0;

  /// 弹跳过冲值
  static const double bounceOvershoot = 1.1;

  // ========== 预设动画配置 ==========

  /// 按钮点击动画
  static AnimatedScaleConfig get buttonPress => AnimatedScaleConfig(
        scale: buttonPressScale,
        duration: quick,
        curve: enter,
      );

  /// 卡片交互动画
  static AnimatedScaleConfig get cardPress => AnimatedScaleConfig(
        scale: cardPressScale,
        duration: quick,
        curve: enter,
      );

  /// 列表项交互动画
  static AnimatedScaleConfig get listItemPress => AnimatedScaleConfig(
        scale: listItemPressScale,
        duration: quick,
        curve: enter,
      );

  /// 淡入动画
  static AnimatedOpacityConfig get fadeIn => AnimatedOpacityConfig(
        opacity: fadeInEnd,
        duration: normal,
        curve: enter,
      );

  /// 淡出动画
  static AnimatedOpacityConfig get fadeOut => AnimatedOpacityConfig(
        opacity: fadeInStart,
        duration: quick,
        curve: exit,
      );

  /// 滑动进入动画（从下方）
  static AnimatedSlideConfig get slideInFromBottom => AnimatedSlideConfig(
        offset: const Offset(0, slideInDistance),
        duration: normal,
        curve: enter,
      );

  /// 滑动进入动画（从右侧）
  static AnimatedSlideConfig get slideInFromRight => AnimatedSlideConfig(
        offset: const Offset(slideInDistance, 0),
        duration: normal,
        curve: enter,
      );

  /// 弹跳动画
  static AnimatedScaleConfig get bounce => AnimatedScaleConfig(
        scale: bounceOvershoot,
        duration: normal,
        curve: elastic,
      );

  /// 脉冲动画
  static AnimatedScaleConfig get pulse => AnimatedScaleConfig(
        scale: 1.05,
        duration: normal,
        curve: fastOutSlowIn,
      );

  // ========== 页面过渡动画 ==========

  /// 页面淡入过渡
  static PageTransitionsBuilder get pageFade => const FadeUpwardsPageTransitionsBuilder();

  /// 页面滑动过渡
  static PageTransitionsBuilder get pageSlide => const CupertinoPageTransitionsBuilder();

  // ========== 列表交错动画 ==========

  /// 列表项交错间隔（毫秒）
  static const int listStaggerInterval = 30;

  /// 列表项最大交错延迟（毫秒）
  static const int listStaggerMaxDelay = 300;

  /// 获取列表项交错延迟
  static Duration getListStaggerDelay(int index, int totalCount) {
    final delay = (index * listStaggerInterval).clamp(0, listStaggerMaxDelay);
    return Duration(milliseconds: delay);
  }

  // ========== 动画工具方法 ==========

  /// 创建缩放动画控制器
  static AnimationController createScaleController(
    TickerProvider vsync, {
    Duration? duration,
  }) {
    return AnimationController(
      duration: duration ?? quick,
      vsync: vsync,
    );
  }

  /// 创建透明度动画控制器
  static AnimationController createOpacityController(
    TickerProvider vsync, {
    Duration? duration,
  }) {
    return AnimationController(
      duration: duration ?? normal,
      vsync: vsync,
    );
  }

  /// 创建曲线动画
  static Animation<double> createCurvedAnimation({
    required AnimationController parent,
    Curve? curve,
  }) {
    return CurvedAnimation(
      parent: parent,
      curve: curve ?? Curves.easeInOutCubic,
    );
  }

  /// 创建交错动画
  static Animation<double> createStaggeredAnimation({
    required AnimationController parent,
    required int index,
    required int totalCount,
    Curve? curve,
  }) {
    final interval = 1.0 / totalCount;
    final begin = index * interval;
    final end = (begin + interval).clamp(0.0, 1.0);

    return CurvedAnimation(
      parent: parent,
      curve: Interval(begin, end, curve: curve ?? Curves.easeOutCubic),
    );
  }
}

/// 缩放动画配置
class AnimatedScaleConfig {
  final double scale;
  final Duration duration;
  final Curve curve;

  const AnimatedScaleConfig({
    required this.scale,
    required this.duration,
    required this.curve,
  });
}

/// 透明度动画配置
class AnimatedOpacityConfig {
  final double opacity;
  final Duration duration;
  final Curve curve;

  const AnimatedOpacityConfig({
    required this.opacity,
    required this.duration,
    required this.curve,
  });
}

/// 滑动动画配置
class AnimatedSlideConfig {
  final Offset offset;
  final Duration duration;
  final Curve curve;

  const AnimatedSlideConfig({
    required this.offset,
    required this.duration,
    required this.curve,
  });
}

/// 交互状态枚举
enum InteractionState {
  /// 默认状态
  normal,

  /// 按下状态
  pressed,

  /// 禁用状态
  disabled,

  /// 聚焦状态
  focused,

  /// 悬停状态
  hovered,
}

/// 交互动画混入 - 可用于需要交互动画的组件
mixin InteractiveAnimationMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  /// 是否按下
  bool _isPressed = false;

  /// 是否禁用
  bool _isDisabled = false;

  /// 缩放动画控制器
  late AnimationController _scaleController;

  /// 缩放动画
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AppAnimations.createScaleController(this);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: AppAnimations.buttonPressScale,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  /// 获取当前缩放值
  double get currentScale => _scaleAnimation.value;

  /// 获取缩放动画
  Animation<double> get scaleAnimation => _scaleAnimation;

  /// 处理按下开始
  void handlePressDown() {
    if (_isDisabled) return;
    setState(() => _isPressed = true);
    _scaleController.forward();
  }

  /// 处理按下结束
  void handlePressUp() {
    if (_isDisabled) return;
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  /// 设置禁用状态
  void setDisabled(bool disabled) {
    setState(() => _isDisabled = disabled);
  }

  /// 获取交互状态
  InteractionState get interactionState {
    if (_isDisabled) return InteractionState.disabled;
    if (_isPressed) return InteractionState.pressed;
    return InteractionState.normal;
  }
}
