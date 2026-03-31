import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/features/onboarding/data/onboarding_state.dart';

/// 规则设置步骤
class RulesSetupStep extends ConsumerStatefulWidget {
  const RulesSetupStep({super.key});

  @override
  ConsumerState<RulesSetupStep> createState() => _RulesSetupStepState();
}

class _RulesSetupStepState extends ConsumerState<RulesSetupStep> {
  int _totalMinutes = 180; // 3小时
  int _gameMinutes = 60; // 1小时
  int _videoMinutes = 90; // 1.5小时

  @override
  void initState() {
    super.initState();
    // 初始化时保存默认值
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveToState();
    });
  }

  void _saveToState() {
    ref.read(onboardingProvider.notifier).updateData({
      'total_minutes': _totalMinutes,
      'game_minutes': _gameMinutes,
      'video_minutes': _videoMinutes,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(DesignTokens.space24),
      child: Column(
        children: [
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(DesignTokens.space10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(DesignTokens.radius10),
                ),
                child: Icon(
                  Icons.rule_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: DesignTokens.space12),
              Text(
                '设置使用规则',
                style: AppTextStyles.heading2.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            '家长可以设置每日使用时间限制',
            style: AppTextStyles.labelMedium.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DesignTokens.space20),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 总时间设置
                  _buildTimeSlider(
                    title: '总使用时间',
                    icon: Icons.timer_rounded,
                    color: AppColors.primary,
                    value: _totalMinutes,
                    max: 480,
                    labels: const ['0', '2h', '4h', '6h', '8h'],
                    isDark: isDark,
                    onChanged: (value) {
                      setState(() => _totalMinutes = value.toInt());
                      _saveToState();
                    },
                  ),
                  const SizedBox(height: DesignTokens.space16),

                  // 游戏时间设置
                  _buildTimeSlider(
                    title: '游戏时间',
                    icon: Icons.sports_esports_rounded,
                    color: AppSolidColors.game,
                    value: _gameMinutes,
                    max: 240,
                    labels: const ['0', '1h', '2h', '3h', '4h'],
                    isDark: isDark,
                    onChanged: (value) {
                      setState(() => _gameMinutes = value.toInt());
                      _saveToState();
                    },
                  ),
                  const SizedBox(height: DesignTokens.space16),

                  // 视频时间设置
                  _buildTimeSlider(
                    title: '视频时间',
                    icon: Icons.play_circle_rounded,
                    color: AppSolidColors.video,
                    value: _videoMinutes,
                    max: 360,
                    labels: const ['0', '1.5h', '3h', '4.5h', '6h'],
                    isDark: isDark,
                    onChanged: (value) {
                      setState(() => _videoMinutes = value.toInt());
                      _saveToState();
                    },
                  ),
                  const SizedBox(height: DesignTokens.space20),

                  // 说明
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.space14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.info.withValues(alpha: 0.15),
                          AppColors.info.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(DesignTokens.radius14),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(DesignTokens.space8),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(DesignTokens.radius8),
                          ),
                          child: Icon(
                            Icons.tips_and_updates_rounded,
                            color: AppColors.info,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.space12),
                        Expanded(
                          child: Text(
                            '这些规则之后可以在家长模式中修改',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlider({
    required String title,
    required IconData icon,
    required Color color,
    required int value,
    required int max,
    required List<String> labels,
    required bool isDark,
    required Function(double) onChanged,
  }) {
    final hours = value ~/ 60;
    final minutes = value % 60;
    final displayText = hours > 0
        ? '$hours小时${minutes > 0 ? '$minutes分钟' : ''}'
        : '$minutes分钟';

    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(DesignTokens.radius12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space12,
                  vertical: DesignTokens.space6,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(DesignTokens.radius10),
                ),
                child: Text(
                  displayText,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.2),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              trackHeight: 6,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: max.toDouble(),
              divisions: max - 1,
              onChanged: onChanged,
            ),
          ),
          // 刻度标签
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: labels
                  .map((label) => Text(
                        label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.textHintDark
                              : AppColors.textHintLight,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
