import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 音效类型
enum SoundType {
  gentleRemind,   // 温柔提醒
  warningRemind,  // 警告提醒
  finalWarning,   // 最后警告
  lockSound,      // 锁定音效
  success,        // 成功音效
}

/// 音效服务
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isEnabled = true;
  double _volume = 0.7;

  /// 是否启用音效
  bool get isEnabled => _isEnabled;

  /// 设置是否启用音效
  set isEnabled(bool value) {
    _isEnabled = value;
  }

  /// 音量（0.0 - 1.0）
  double get volume => _volume;

  /// 设置音量
  set volume(double value) {
    _volume = value.clamp(0.0, 1.0);
  }

  /// 播放音效
  Future<void> play(SoundType type) async {
    if (!_isEnabled) return;

    try {
      final path = _getSoundPath(type);
      await _player.setVolume(_volume);
      await _player.play(AssetSource(path));
    } catch (e) {
      debugPrint('播放音效失败: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    await _player.stop();
  }

  /// 释放资源
  Future<void> dispose() async {
    await _player.dispose();
  }

  /// 获取音效资源路径
  String _getSoundPath(SoundType type) {
    switch (type) {
      case SoundType.gentleRemind:
        return 'sounds/gentle_remind.mp3';
      case SoundType.warningRemind:
        return 'sounds/warning_remind.mp3';
      case SoundType.finalWarning:
        return 'sounds/final_warning.mp3';
      case SoundType.lockSound:
        return 'sounds/lock_sound.mp3';
      case SoundType.success:
        return 'sounds/success.mp3';
    }
  }
}

/// 音效服务 Provider
final soundServiceProvider = Provider<SoundService>((ref) {
  return SoundService();
});
