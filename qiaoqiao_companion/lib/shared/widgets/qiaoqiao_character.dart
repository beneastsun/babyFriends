import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 小熊心情枚举
enum QiaoqiaoBearMood {
  /// 开心 - 眨眼微笑，用于正常状态
  happy,
  /// 思考 - 手指触摸下巴，用于即将到达限制
  thinking,
  /// 担心 - 皱眉，用于接近限制
  worried,
  /// 难过 - 流泪，用于超限
  sad,
}

/// 巧巧小熊可爱角色组件
///
/// 根据使用情况显示不同的心情状态，带有可爱的动画效果
class QiaoqiaoBear extends StatefulWidget {
  /// 心情状态
  final QiaoqiaoBearMood mood;

  /// 尺寸（宽高相等）
  final double size;

  /// 是否启用动画
  final bool enableAnimation;

  /// 是否显示装饰元素（思考气泡、泪滴等）
  final bool showDecorations;

  const QiaoqiaoBear({
    super.key,
    this.mood = QiaoqiaoBearMood.happy,
    this.size = 64,
    this.enableAnimation = true,
    this.showDecorations = true,
  });

  @override
  State<QiaoqiaoBear> createState() => _QiaoqiaoBearState();
}

class _QiaoqiaoBearState extends State<QiaoqiaoBear>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _blinkController;
  late AnimationController _accessoryController;
  late Animation<double> _floatAnimation;
  late Animation<double> _blinkAnimation;
  late Animation<double> _accessoryAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // 浮动动画 - 轻微上下浮动
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _floatAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // 眨眼动画
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 1, end: 0.1).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    // 装饰元素动画（思考气泡、泪滴等）
    _accessoryController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _accessoryAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _accessoryController, curve: Curves.elasticOut),
    );

    if (widget.enableAnimation) {
      _startAnimations();
    }
  }

  void _startAnimations() {
    // 浮动动画 - 循环
    _floatController.repeat(reverse: true);

    // 眨眼动画 - 每3秒眨一次
    _blinkCycle();
  }

  void _blinkCycle() {
    if (!mounted || !widget.enableAnimation) return;

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _blinkController.forward().then((_) {
        _blinkController.reverse();
        _blinkCycle();
      });
    });
  }

  @override
  void didUpdateWidget(QiaoqiaoBear oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      // 心情变化时播放装饰元素入场动画
      _accessoryController.forward(from: 0);
    }
    if (oldWidget.enableAnimation != widget.enableAnimation) {
      if (widget.enableAnimation) {
        _startAnimations();
      } else {
        _floatController.stop();
      }
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _blinkController.dispose();
    _accessoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final floatOffset = math.sin(_floatAnimation.value * math.pi) * 3;
        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: child,
        );
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 小熊主体
            _buildBearBody(),
            // 装饰元素
            if (widget.showDecorations) ..._buildDecorations(),
          ],
        ),
      ),
    );
  }

  /// 构建小熊主体
  Widget _buildBearBody() {
    return Center(
      child: Container(
        width: widget.size * 0.85,
        height: widget.size * 0.85,
        decoration: BoxDecoration(
          gradient: _getMoodGradient(),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _getMoodColor().withOpacity(0.3),
              blurRadius: widget.size * 0.2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 耳朵
            ..._buildEars(),
            // 脸部
            _buildFace(),
          ],
        ),
      ),
    );
  }

  /// 构建耳朵
  List<Widget> _buildEars() {
    final earSize = widget.size * 0.22;
    final earOffset = widget.size * 0.28;

    return [
      Positioned(
        top: -earOffset * 0.3,
        left: earOffset * 0.5,
        child: Container(
          width: earSize,
          height: earSize,
          decoration: BoxDecoration(
            color: _getMoodColor().withOpacity(0.8),
            shape: BoxShape.circle,
          ),
        ),
      ),
      Positioned(
        top: -earOffset * 0.3,
        right: earOffset * 0.5,
        child: Container(
          width: earSize,
          height: earSize,
          decoration: BoxDecoration(
            color: _getMoodColor().withOpacity(0.8),
            shape: BoxShape.circle,
          ),
        ),
      ),
    ];
  }

  /// 构建脸部
  Widget _buildFace() {
    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // 眼睛
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildEye(isLeft: true),
                SizedBox(width: widget.size * 0.2),
                _buildEye(isLeft: false),
              ],
            ),
            const Spacer(),
            // 鼻子
            Container(
              width: widget.size * 0.12,
              height: widget.size * 0.08,
              decoration: BoxDecoration(
                color: Colors.brown.shade400,
                borderRadius: BorderRadius.circular(widget.size * 0.04),
              ),
            ),
            const Spacer(flex: 1),
            // 嘴巴
            _buildMouth(),
            const Spacer(flex: 2),
          ],
        );
      },
    );
  }

  /// 构建眼睛
  Widget _buildEye({required bool isLeft}) {
    final eyeSize = widget.size * 0.12;
    final blinkScale = widget.mood == QiaoqiaoBearMood.happy
        ? _blinkAnimation.value
        : 1.0;

    return Transform.scale(
      scaleY: blinkScale,
      child: Container(
        width: eyeSize,
        height: eyeSize,
        decoration: BoxDecoration(
          color: _getEyeColor(),
          shape: BoxShape.circle,
        ),
        // 开心时添加高光
        child: widget.mood == QiaoqiaoBearMood.happy
            ? Align(
                alignment: const Alignment(0.3, -0.3),
                child: Container(
                  width: eyeSize * 0.4,
                  height: eyeSize * 0.4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  /// 构建嘴巴
  Widget _buildMouth() {
    switch (widget.mood) {
      case QiaoqiaoBearMood.happy:
        return _buildHappyMouth();
      case QiaoqiaoBearMood.thinking:
        return _buildThinkingMouth();
      case QiaoqiaoBearMood.worried:
        return _buildWorriedMouth();
      case QiaoqiaoBearMood.sad:
        return _buildSadMouth();
    }
  }

  /// 开心的嘴巴 - 微笑
  Widget _buildHappyMouth() {
    return CustomPaint(
      size: Size(widget.size * 0.25, widget.size * 0.12),
      painter: _SmilePainter(color: Colors.brown.shade400),
    );
  }

  /// 思考的嘴巴 - 小圆圈
  Widget _buildThinkingMouth() {
    return Container(
      width: widget.size * 0.08,
      height: widget.size * 0.08,
      decoration: BoxDecoration(
        color: Colors.brown.shade400,
        shape: BoxShape.circle,
      ),
    );
  }

  /// 担心的嘴巴 - 波浪线
  Widget _buildWorriedMouth() {
    return CustomPaint(
      size: Size(widget.size * 0.2, widget.size * 0.08),
      painter: _WavyMouthPainter(color: Colors.brown.shade400),
    );
  }

  /// 难过的嘴巴 - 下弯
  Widget _buildSadMouth() {
    return CustomPaint(
      size: Size(widget.size * 0.2, widget.size * 0.1),
      painter: _SadMouthPainter(color: Colors.brown.shade400),
    );
  }

  /// 构建装饰元素
  List<Widget> _buildDecorations() {
    switch (widget.mood) {
      case QiaoqiaoBearMood.thinking:
        return [_buildThoughtBubble()];
      case QiaoqiaoBearMood.worried:
        return [_buildSweatDrop()];
      case QiaoqiaoBearMood.sad:
        return [_buildTears()];
      case QiaoqiaoBearMood.happy:
        return [_buildSparkles()];
    }
  }

  /// 思考气泡
  Widget _buildThoughtBubble() {
    return AnimatedBuilder(
      animation: _accessoryController,
      builder: (context, child) {
        return Positioned(
          top: -widget.size * 0.1,
          right: -widget.size * 0.15,
          child: Transform.scale(
            scale: _accessoryAnimation.value,
            child: Opacity(
              opacity: _accessoryAnimation.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: widget.size * 0.35,
                    height: widget.size * 0.25,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(widget.size * 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '?',
                        style: TextStyle(
                          fontSize: widget.size * 0.15,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade300,
                        ),
                      ),
                    ),
                  ),
                  // 小气泡
                  Container(
                    width: widget.size * 0.06,
                    height: widget.size * 0.06,
                    margin: const EdgeInsets.only(right: 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: widget.size * 0.04,
                    height: widget.size * 0.04,
                    margin: const EdgeInsets.only(right: 30),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 汗滴
  Widget _buildSweatDrop() {
    return AnimatedBuilder(
      animation: _accessoryController,
      builder: (context, child) {
        return Positioned(
          top: widget.size * 0.1,
          right: -widget.size * 0.05,
          child: Transform.scale(
            scale: _accessoryAnimation.value,
            child: Opacity(
              opacity: _accessoryAnimation.value,
              child: CustomPaint(
                size: Size(widget.size * 0.1, widget.size * 0.15),
                painter: _SweatDropPainter(color: Colors.lightBlue.shade300),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 眼泪
  Widget _buildTears() {
    return AnimatedBuilder(
      animation: _accessoryController,
      builder: (context, child) {
        return Positioned(
          bottom: widget.size * 0.15,
          left: widget.size * 0.15,
          child: Transform.scale(
            scale: _accessoryAnimation.value,
            child: Opacity(
              opacity: _accessoryAnimation.value * 0.8,
              child: Row(
                children: [
                  CustomPaint(
                    size: Size(widget.size * 0.08, widget.size * 0.12),
                    painter: _TearPainter(color: Colors.lightBlue.shade300),
                  ),
                  SizedBox(width: widget.size * 0.3),
                  CustomPaint(
                    size: Size(widget.size * 0.08, widget.size * 0.12),
                    painter: _TearPainter(color: Colors.lightBlue.shade300),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 闪光点（开心时）
  Widget _buildSparkles() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final sparkleOpacity = 0.3 + math.sin(_floatAnimation.value * math.pi * 2) * 0.3;
        return Positioned(
          top: -widget.size * 0.05,
          right: widget.size * 0.1,
          child: Opacity(
            opacity: sparkleOpacity,
            child: Icon(
              Icons.star_rounded,
              size: widget.size * 0.2,
              color: Colors.yellow.shade400,
            ),
          ),
        );
      },
    );
  }

  /// 获取心情对应的颜色
  Color _getMoodColor() {
    switch (widget.mood) {
      case QiaoqiaoBearMood.happy:
        return const Color(0xFFFFCC80); // 温暖的蜂蜜色
      case QiaoqiaoBearMood.thinking:
        return const Color(0xFFFFE0B2); // 稍浅的蜂蜜色
      case QiaoqiaoBearMood.worried:
        return const Color(0xFFFFF3E0); // 更浅
      case QiaoqiaoBearMood.sad:
        return const Color(0xFFE8EAF6); // 带点蓝灰色
    }
  }

  /// 获取心情对应的渐变
  LinearGradient _getMoodGradient() {
    final baseColor = _getMoodColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        baseColor,
        Color.lerp(baseColor, Colors.brown.shade200, 0.2)!,
      ],
    );
  }

  /// 获取眼睛颜色
  Color _getEyeColor() {
    switch (widget.mood) {
      case QiaoqiaoBearMood.happy:
        return Colors.brown.shade600;
      case QiaoqiaoBearMood.thinking:
        return Colors.brown.shade500;
      case QiaoqiaoBearMood.worried:
        return Colors.brown.shade600;
      case QiaoqiaoBearMood.sad:
        return Colors.brown.shade700;
    }
  }
}

// ========== 自定义绘制器 ==========

/// 微笑绘制器
class _SmilePainter extends CustomPainter {
  final Color color;

  _SmilePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.15
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, size.height * 0.3, size.width, size.height);
    canvas.drawArc(rect, 0.2, math.pi - 0.4, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 波浪嘴绘制器
class _WavyMouthPainter extends CustomPainter {
  final Color color;

  _WavyMouthPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 0.8,
      size.width * 0.5, size.height * 0.4,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.0,
      size.width, size.height * 0.5,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 难过嘴绘制器
class _SadMouthPainter extends CustomPainter {
  final Color color;

  _SadMouthPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.15
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, -size.height * 0.5, size.width, size.height);
    canvas.drawArc(rect, -0.2, -math.pi + 0.4, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 汗滴绘制器
class _SweatDropPainter extends CustomPainter {
  final Color color;

  _SweatDropPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.quadraticBezierTo(
      size.width, size.height * 0.5,
      size.width * 0.5, size.height,
    );
    path.quadraticBezierTo(
      0, size.height * 0.5,
      size.width * 0.5, 0,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 眼泪绘制器
class _TearPainter extends CustomPainter {
  final Color color;

  _TearPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.quadraticBezierTo(
      size.width, size.height * 0.4,
      size.width * 0.5, size.height,
    );
    path.quadraticBezierTo(
      0, size.height * 0.4,
      size.width * 0.5, 0,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 根据使用百分比获取心情
QiaoqiaoBearMood getMoodFromUsagePercentage(double percentage) {
  if (percentage < 0.7) {
    return QiaoqiaoBearMood.happy;
  } else if (percentage < 0.9) {
    return QiaoqiaoBearMood.thinking;
  } else if (percentage < 1.0) {
    return QiaoqiaoBearMood.worried;
  } else {
    return QiaoqiaoBearMood.sad;
  }
}
