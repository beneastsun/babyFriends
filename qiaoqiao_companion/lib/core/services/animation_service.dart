import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';

/// 巧巧心情枚举
enum QiaoqiaoMood {
  happy,    // 开心
  remind,   // 提醒
  serious,  // 严肃
  sad,      // 难过
}

/// 巧巧动画头像组件
class QiaoqiaoAnimatedAvatar extends StatefulWidget {
  final QiaoqiaoMood mood;
  final double size;
  final bool loop;

  const QiaoqiaoAnimatedAvatar({
    super.key,
    this.mood = QiaoqiaoMood.happy,
    this.size = 80,
    this.loop = true,
  });

  @override
  State<QiaoqiaoAnimatedAvatar> createState() => _QiaoqiaoAnimatedAvatarState();
}

class _QiaoqiaoAnimatedAvatarState extends State<QiaoqiaoAnimatedAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.loop) {
      _controller.repeat();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: _buildAnimatedAvatar(),
    );
  }

  Widget _buildAnimatedAvatar() {
    // 由于没有实际的Lottie动画文件，使用带动画的静态图标作为替代
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.1),
          child: Container(
            decoration: BoxDecoration(
              color: _getMoodColor().withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getMoodEmoji(),
                style: TextStyle(fontSize: widget.size * 0.5),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getMoodColor() {
    switch (widget.mood) {
      case QiaoqiaoMood.happy:
        return const Color(0xFFFFEB3B);
      case QiaoqiaoMood.remind:
        return const Color(0xFFFFB74D);
      case QiaoqiaoMood.serious:
        return const Color(0xFFFF9800);
      case QiaoqiaoMood.sad:
        return const Color(0xFF90CAF9);
    }
  }

  String _getMoodEmoji() {
    switch (widget.mood) {
      case QiaoqiaoMood.happy:
        return '😊';
      case QiaoqiaoMood.remind:
        return '🤔';
      case QiaoqiaoMood.serious:
        return '😤';
      case QiaoqiaoMood.sad:
        return '😢';
    }
  }
}

/// 动画服务
class AnimationService {
  AnimationService._();

  /// 根据使用情况获取巧巧心情
  static QiaoqiaoMood getMoodFromUsage({
    required int usedMinutes,
    required int totalMinutes,
    required bool isExceeded,
  }) {
    if (isExceeded) {
      return QiaoqiaoMood.sad;
    }

    final ratio = usedMinutes / totalMinutes;

    if (ratio >= 0.9) {
      return QiaoqiaoMood.serious;
    } else if (ratio >= 0.7) {
      return QiaoqiaoMood.remind;
    } else {
      return QiaoqiaoMood.happy;
    }
  }

  /// 获取动画资源路径
  static String getAnimationPath(QiaoqiaoMood mood) {
    switch (mood) {
      case QiaoqiaoMood.happy:
        return 'assets/animations/qiaoqiao_happy.json';
      case QiaoqiaoMood.remind:
        return 'assets/animations/qiaoqiao_remind.json';
      case QiaoqiaoMood.serious:
        return 'assets/animations/qiaoqiao_serious.json';
      case QiaoqiaoMood.sad:
        return 'assets/animations/qiaoqiao_sad.json';
    }
  }
}

/// Lottie动画组件包装器
class QiaoqiaoLottieAnimation extends StatelessWidget {
  final QiaoqiaoMood mood;
  final double size;
  final bool repeat;

  const QiaoqiaoLottieAnimation({
    super.key,
    required this.mood,
    this.size = 80,
    this.repeat = true,
  });

  @override
  Widget build(BuildContext context) {
    // 尝试加载Lottie动画，如果失败则显示静态表情
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        AnimationService.getAnimationPath(mood),
        width: size,
        height: size,
        fit: BoxFit.contain,
        repeat: repeat,
        errorBuilder: (context, error, stackTrace) {
          // 如果Lottie文件不存在，显示静态表情
          return Container(
            decoration: BoxDecoration(
              color: _getMoodColor().withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getMoodEmoji(),
                style: TextStyle(fontSize: size * 0.5),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getMoodColor() {
    switch (mood) {
      case QiaoqiaoMood.happy:
        return const Color(0xFFFFEB3B);
      case QiaoqiaoMood.remind:
        return const Color(0xFFFFB74D);
      case QiaoqiaoMood.serious:
        return const Color(0xFFFF9800);
      case QiaoqiaoMood.sad:
        return const Color(0xFF90CAF9);
    }
  }

  String _getMoodEmoji() {
    switch (mood) {
      case QiaoqiaoMood.happy:
        return '😊';
      case QiaoqiaoMood.remind:
        return '🤔';
      case QiaoqiaoMood.serious:
        return '😤';
      case QiaoqiaoMood.sad:
        return '😢';
    }
  }
}
