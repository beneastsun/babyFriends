import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Kawaii Dream 动画系统
/// 丰富活泼的动效 - 弹跳、摇摆、果冻、呼吸等可爱效果
class AppAnimations {
  AppAnimations._();

  // ============================================================
  // 时长定义（复用 DesignTokens）
  // ============================================================

  /// 即时反馈 - 50ms
  static Duration get instant => DesignTokens.instant;

  /// 微交互 - 100ms
  static Duration get micro => DesignTokens.micro;

  /// 快速动画 - 150ms
  static Duration get quick => DesignTokens.quick;

  /// 标准动画 - 300ms
  static Duration get normal => DesignTokens.normal;

  /// 慢动画 - 500ms
  static Duration get slow => DesignTokens.slow;

  /// 更慢动画 - 800ms
  static Duration get slower => DesignTokens.slower;

  /// 页面过渡动画
  static Duration get pageTransition => DesignTokens.pageTransition;

  /// 庆祝动画 - 1200ms
  static Duration get celebration => DesignTokens.celebration;

  // ============================================================
  // 曲线定义（复用 DesignTokens + Kawaii 专属）
  // ============================================================

  /// 入场曲线 - easeOutCubic
  static Curve get enter => DesignTokens.curveEnter;

  /// 退场曲线 - easeInCubic
  static Curve get exit => DesignTokens.curveExit;

  /// 标准曲线 - easeInOutCubic
  static Curve get standard => DesignTokens.curveStandard;

  /// 弹性曲线 - elasticOut (可爱弹跳)
  static Curve get elastic => DesignTokens.curveElastic;

  /// 快入慢出曲线
  static Curve get fastOutSlowIn => DesignTokens.curveFastOutSlowIn;

  /// 弹跳曲线
  static Curve get bounce => DesignTokens.curveBounce;

  /// 俏皮曲线 - 超调量弹跳
  static Curve get playful => DesignTokens.curvePlayful;

  /// 果冻曲线
  static Curve get jelly => DesignTokens.curveJelly;

  /// 平滑弹性曲线
  static Curve get smoothBounce => DesignTokens.curveSmoothBounce;

  // ============================================================
  // 预设动画值
  // ============================================================

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

  /// 果冻过冲值
  static const double jellyOvershoot = 1.15;

  /// 脉冲缩放值
  static const double pulseScale = 1.05;

  /// 摇摆角度 (弧度)
  static const double wiggleAngle = 0.1; // 约 5.7 度

  // ============================================================
  // 预设动画配置 - 基础动画
  // ============================================================

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

  /// 滑动进入动画（从上方）
  static AnimatedSlideConfig get slideInFromTop => AnimatedSlideConfig(
        offset: const Offset(0, -slideInDistance),
        duration: normal,
        curve: enter,
      );

  /// 滑动进入动画（从左侧）
  static AnimatedSlideConfig get slideInFromLeft => AnimatedSlideConfig(
        offset: const Offset(-slideInDistance, 0),
        duration: normal,
        curve: enter,
      );

  // ============================================================
  // Kawaii Dream 专属动画配置
  // ============================================================

  /// 弹跳入场动画 (Bounce In)
  /// 0.0 → 1.1 → 0.95 → 1.0
  static AnimatedScaleSequenceConfig get bounceIn => AnimatedScaleSequenceConfig(
        keyframes: [
          ScaleKeyframe(scale: 0.0, duration: Duration.zero),
          ScaleKeyframe(scale: 1.1, duration: Duration(milliseconds: 200), curve: Curves.easeOut),
          ScaleKeyframe(scale: 0.95, duration: Duration(milliseconds: 100), curve: Curves.easeInOut),
          ScaleKeyframe(scale: 1.0, duration: Duration(milliseconds: 100), curve: Curves.easeOut),
        ],
      );

  /// 弹跳退场动画 (Bounce Out)
  /// 1.0 → 1.1 → 0.0
  static AnimatedScaleSequenceConfig get bounceOut => AnimatedScaleSequenceConfig(
        keyframes: [
          ScaleKeyframe(scale: 1.0, duration: Duration.zero),
          ScaleKeyframe(scale: 1.1, duration: Duration(milliseconds: 100), curve: Curves.easeIn),
          ScaleKeyframe(scale: 0.0, duration: Duration(milliseconds: 200), curve: Curves.easeIn),
        ],
      );

  /// 果冻动画 (Jelly)
  /// 1.0 → 1.15 → 0.9 → 1.05 → 1.0
  static AnimatedScaleSequenceConfig get jellyScale => AnimatedScaleSequenceConfig(
        keyframes: [
          ScaleKeyframe(scale: 1.0, duration: Duration.zero),
          ScaleKeyframe(scale: 1.15, duration: Duration(milliseconds: 150), curve: playful),
          ScaleKeyframe(scale: 0.9, duration: Duration(milliseconds: 100), curve: Curves.easeInOut),
          ScaleKeyframe(scale: 1.05, duration: Duration(milliseconds: 100), curve: Curves.easeOut),
          ScaleKeyframe(scale: 1.0, duration: Duration(milliseconds: 100), curve: Curves.easeOut),
        ],
      );

  /// 摇摆动画 (Wiggle)
  /// -5° → 5° → -5° → 0°
  static AnimatedRotationSequenceConfig get wiggle => AnimatedRotationSequenceConfig(
        keyframes: [
          RotationKeyframe(angle: 0.0, duration: Duration.zero),
          RotationKeyframe(angle: wiggleAngle, duration: Duration(milliseconds: 50), curve: Curves.easeOut),
          RotationKeyframe(angle: -wiggleAngle, duration: Duration(milliseconds: 50), curve: Curves.easeInOut),
          RotationKeyframe(angle: wiggleAngle * 0.5, duration: Duration(milliseconds: 50), curve: Curves.easeInOut),
          RotationKeyframe(angle: 0.0, duration: Duration(milliseconds: 50), curve: Curves.easeOut),
        ],
      );

  /// 脉冲动画 (Pulse)
  /// 1.0 → 1.05 → 1.0
  static AnimatedScaleConfig get pulse => AnimatedScaleConfig(
        scale: pulseScale,
        duration: normal,
        curve: fastOutSlowIn,
      );

  /// 心跳动画 (Heartbeat)
  /// 1.0 → 1.1 → 1.0 → 1.1 → 1.0
  static AnimatedScaleSequenceConfig get heartbeat => AnimatedScaleSequenceConfig(
        keyframes: [
          ScaleKeyframe(scale: 1.0, duration: Duration.zero),
          ScaleKeyframe(scale: 1.1, duration: Duration(milliseconds: 150), curve: Curves.easeOut),
          ScaleKeyframe(scale: 1.0, duration: Duration(milliseconds: 100), curve: Curves.easeIn),
          ScaleKeyframe(scale: 1.1, duration: Duration(milliseconds: 150), curve: Curves.easeOut),
          ScaleKeyframe(scale: 1.0, duration: Duration(milliseconds: 300), curve: Curves.easeOut),
        ],
      );

  /// 抖动动画 (Shake) - 水平抖动
  static AnimatedSlideSequenceConfig get shake => AnimatedSlideSequenceConfig(
        keyframes: [
          SlideKeyframe(offset: const Offset(0, 0), duration: Duration.zero),
          SlideKeyframe(offset: const Offset(-8, 0), duration: Duration(milliseconds: 50)),
          SlideKeyframe(offset: const Offset(8, 0), duration: Duration(milliseconds: 50)),
          SlideKeyframe(offset: const Offset(-4, 0), duration: Duration(milliseconds: 50)),
          SlideKeyframe(offset: const Offset(4, 0), duration: Duration(milliseconds: 50)),
          SlideKeyframe(offset: const Offset(0, 0), duration: Duration(milliseconds: 50)),
        ],
      );

  /// 成功弹跳 (Success Pop)
  static AnimatedScaleSequenceConfig get successPop => AnimatedScaleSequenceConfig(
        keyframes: [
          ScaleKeyframe(scale: 0.0, duration: Duration.zero),
          ScaleKeyframe(scale: 1.2, duration: Duration(milliseconds: 200), curve: playful),
          ScaleKeyframe(scale: 0.9, duration: Duration(milliseconds: 100), curve: Curves.easeInOut),
          ScaleKeyframe(scale: 1.0, duration: Duration(milliseconds: 100), curve: Curves.easeOut),
        ],
      );

  /// 错误抖动 (Error Shake)
  static AnimatedSlideSequenceConfig get errorShake => AnimatedSlideSequenceConfig(
        keyframes: [
          SlideKeyframe(offset: const Offset(0, 0), duration: Duration.zero),
          SlideKeyframe(offset: const Offset(-10, 0), duration: Duration(milliseconds: 80)),
          SlideKeyframe(offset: const Offset(10, 0), duration: Duration(milliseconds: 80)),
          SlideKeyframe(offset: const Offset(-6, 0), duration: Duration(milliseconds: 80)),
          SlideKeyframe(offset: const Offset(6, 0), duration: Duration(milliseconds: 80)),
          SlideKeyframe(offset: const Offset(-2, 0), duration: Duration(milliseconds: 80)),
          SlideKeyframe(offset: const Offset(0, 0), duration: Duration(milliseconds: 80)),
        ],
      );

  // ============================================================
  // 循环动画配置
  // ============================================================

  /// 呼吸动画 (Breathing) - 2秒循环
  static AnimatedScaleConfig get breathing => AnimatedScaleConfig(
        scale: 1.02,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
        repeat: true,
        reverse: true,
      );

  /// 浮动动画 (Floating) - 3秒循环
  static AnimatedSlideConfig get floating => AnimatedSlideConfig(
        offset: const Offset(0, -4),
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeInOut,
        repeat: true,
        reverse: true,
      );

  /// 闪烁动画 (Sparkle) - 1.5秒循环
  static AnimatedOpacityConfig get sparkle => AnimatedOpacityConfig(
        opacity: 0.5,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeInOut,
        repeat: true,
        reverse: true,
      );

  // ============================================================
  // 页面过渡动画
  // ============================================================

  /// 页面淡入过渡
  static PageTransitionsBuilder get pageFade => const FadeUpwardsPageTransitionsBuilder();

  /// 页面滑动过渡 (iOS 风格)
  static PageTransitionsBuilder get pageSlide => const CupertinoPageTransitionsBuilder();

  /// 页面缩放过渡 (可爱风格)
  static PageTransitionsBuilder get pageZoom => const ZoomPageTransitionsBuilder();

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
  // 动画工具方法
  // ============================================================

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

  /// 创建循环动画
  static AnimationController createRepeatingController(
    TickerProvider vsync, {
    required Duration duration,
    bool reverse = true,
  }) {
    final controller = AnimationController(
      duration: duration,
      vsync: vsync,
    );
    if (reverse) {
      controller.repeat(reverse: true);
    } else {
      controller.repeat();
    }
    return controller;
  }
}

// ============================================================
// 动画配置类
// ============================================================

/// 缩放动画配置
class AnimatedScaleConfig {
  final double scale;
  final Duration duration;
  final Curve curve;
  final bool repeat;
  final bool reverse;

  const AnimatedScaleConfig({
    required this.scale,
    required this.duration,
    required this.curve,
    this.repeat = false,
    this.reverse = false,
  });
}

/// 缩放关键帧
class ScaleKeyframe {
  final double scale;
  final Duration duration;
  final Curve curve;

  const ScaleKeyframe({
    required this.scale,
    required this.duration,
    this.curve = Curves.linear,
  });
}

/// 缩放序列动画配置
class AnimatedScaleSequenceConfig {
  final List<ScaleKeyframe> keyframes;

  const AnimatedScaleSequenceConfig({required this.keyframes});

  /// 获取总时长
  Duration get totalDuration {
    return keyframes.fold<Duration>(
      Duration.zero,
      (total, keyframe) => total + keyframe.duration,
    );
  }
}

/// 透明度动画配置
class AnimatedOpacityConfig {
  final double opacity;
  final Duration duration;
  final Curve curve;
  final bool repeat;
  final bool reverse;

  const AnimatedOpacityConfig({
    required this.opacity,
    required this.duration,
    required this.curve,
    this.repeat = false,
    this.reverse = false,
  });
}

/// 滑动动画配置
class AnimatedSlideConfig {
  final Offset offset;
  final Duration duration;
  final Curve curve;
  final bool repeat;
  final bool reverse;

  const AnimatedSlideConfig({
    required this.offset,
    required this.duration,
    required this.curve,
    this.repeat = false,
    this.reverse = false,
  });
}

/// 滑动关键帧
class SlideKeyframe {
  final Offset offset;
  final Duration duration;
  final Curve curve;

  const SlideKeyframe({
    required this.offset,
    required this.duration,
    this.curve = Curves.linear,
  });
}

/// 滑动序列动画配置
class AnimatedSlideSequenceConfig {
  final List<SlideKeyframe> keyframes;

  const AnimatedSlideSequenceConfig({required this.keyframes});

  /// 获取总时长
  Duration get totalDuration {
    return keyframes.fold<Duration>(
      Duration.zero,
      (total, keyframe) => total + keyframe.duration,
    );
  }
}

/// 旋转关键帧
class RotationKeyframe {
  final double angle;
  final Duration duration;
  final Curve curve;

  const RotationKeyframe({
    required this.angle,
    required this.duration,
    this.curve = Curves.linear,
  });
}

/// 旋转序列动画配置
class AnimatedRotationSequenceConfig {
  final List<RotationKeyframe> keyframes;

  const AnimatedRotationSequenceConfig({required this.keyframes});

  /// 获取总时长
  Duration get totalDuration {
    return keyframes.fold<Duration>(
      Duration.zero,
      (total, keyframe) => total + keyframe.duration,
    );
  }
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
      curve: AppAnimations.enter,
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

/// 弹跳动画混入 - 更活泼的交互效果
mixin BouncyAnimationMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: AppAnimations.quick,
      vsync: this,
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.02), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  double get bounceScale => _bounceAnimation.value;

  void triggerBounce() {
    _bounceController.forward(from: 0);
  }
}
