import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/widgets/egg_character.dart';

/// 蛋仔升级全屏庆祝 overlay
/// 触发时显示：Lottie 动画 + 语音鼓励 + 庆祝卡片
class EggUpgradeOverlay {
  static OverlayEntry? _entry;
  static final AudioPlayer _audioPlayer = AudioPlayer();

  /// 显示升级庆祝
  static void show(BuildContext context, {
    required EggStyle style,
    required int newStage,
    int durationSec = 3,
  }) {
    if (_entry != null) return; // 防止重复触发

    _entry = OverlayEntry(
      builder: (context) => _UpgradeWidget(
        style: style,
        stage: newStage,
        durationSec: durationSec,
        onComplete: () => _remove(),
      ),
    );

    Overlay.of(context).insert(_entry!);

    // 播放升级音效（占位：使用系统提示音）
    _playUpgradeSound(style, newStage);
  }

  static void _remove() {
    _entry?.remove();
    _entry = null;
  }

  static Future<void> _playUpgradeSound(EggStyle style, int stage) async {
    try {
      // 占位：尝试播放 assets/audio/egg/{style}_{stage}.mp3
      // 如果文件不存在则静默失败
      await _audioPlayer.play(AssetSource('audio/egg/${style.code}_$stage.mp3'));
    } catch (_) {
      // 音频文件不存在时静默处理
    }
  }
}

class _UpgradeWidget extends StatefulWidget {
  final EggStyle style;
  final int stage;
  final int durationSec;
  final VoidCallback onComplete;

  const _UpgradeWidget({
    required this.style,
    required this.stage,
    required this.durationSec,
    required this.onComplete,
  });

  @override
  State<_UpgradeWidget> createState() => _UpgradeWidgetState();
}

class _UpgradeWidgetState extends State<_UpgradeWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);

    _fadeController.forward();
    _scaleController.forward();

    // durationSec 秒后自动关闭
    Timer(Duration(seconds: widget.durationSec), () {
      if (mounted) {
        _fadeController.reverse().then((_) => widget.onComplete());
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  static const _stageNames = ['蛋宝宝', '小蛋仔', '活力蛋', '闪亮蛋', '超级蛋'];
  static const _stageMessages = [
    '开始养成之旅！',
    '继续加油哦！',
    '越来越棒了！',
    '闪闪发光！',
    '完美达成！你太厉害了！',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedStage = widget.stage.clamp(0, 4);

    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 星星粒子效果（占位：用 emoji 代替）
                    const Text('✨🎉✨', style: TextStyle(fontSize: 24)),
                    const SizedBox(height: 16),
                    // 蛋仔形象
                    EggCharacter(style: widget.style, stage: clampedStage, size: 120),
                    const SizedBox(height: 16),
                    // 升级标题
                    Text(
                      '升级了！',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _stageNames[clampedStage],
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stageMessages[clampedStage],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // 倒计时进度条
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        value: null, // 不确定进度
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
