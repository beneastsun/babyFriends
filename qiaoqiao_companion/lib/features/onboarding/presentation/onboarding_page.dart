import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/platform/platform.dart';
import 'package:qiaoqiao_companion/features/onboarding/data/onboarding_state.dart';
import 'package:qiaoqiao_companion/features/onboarding/presentation/steps/welcome_step.dart';
import 'package:qiaoqiao_companion/features/onboarding/presentation/steps/permission_guide_step.dart';
import 'package:qiaoqiao_companion/features/onboarding/presentation/steps/rules_setup_step.dart';
import 'package:qiaoqiao_companion/features/onboarding/presentation/steps/app_category_step.dart';
import 'package:qiaoqiao_companion/features/onboarding/presentation/steps/intro_child_step.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/app_button.dart';

/// 权限步骤的索引（第2步，索引为1）
const int kPermissionStepIndex = 1;

/// Onboarding页面
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  final List<Widget> _steps = [
    const WelcomeStep(),
    const PermissionGuideStep(),
    const RulesSetupStep(),
    const AppCategoryStep(),
    const IntroChildStep(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 进度指示器
              _buildProgressBar(state.currentStep, isDark),
              // 页面内容
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    // 由Provider控制
                  },
                  children: _steps,
                ),
              ),
              // 底部导航
              _buildBottomNav(state.currentStep, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(int currentStep, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space20,
        vertical: DesignTokens.space16,
      ),
      child: Column(
        children: [
          // 步骤文字
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${currentStep + 1}',
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                ' / ${_steps.length}',
                style: AppTextStyles.heading3.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space12),
          // 进度条
          Row(
            children: List.generate(_steps.length, (index) {
              final isActive = index <= currentStep;
              final isCurrent = index == currentStep;

              return Expanded(
                child: AnimatedContainer(
                  duration: DesignTokens.animationNormal,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: isCurrent ? 6 : 4,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : (isDark
                        ? AppColors.surfaceDark
                        : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: isCurrent ? AppShadows.button : null,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(int currentStep, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 上一步按钮
          if (currentStep > 0)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _previousStep,
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space20,
                    vertical: DesignTokens.space12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      const SizedBox(width: DesignTokens.space6),
                      Text(
                        '上一步',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 100),

          // 下一步/完成按钮
          AppButtonPrimary(
            onPressed: _nextStep,
            icon: Icon(
              currentStep == _steps.length - 1
                  ? Icons.check_rounded
                  : Icons.arrow_forward_rounded,
              size: 18,
            ),
            child: Text(
              currentStep == _steps.length - 1 ? '开始使用' : '下一步',
            ),
          ),
        ],
      ),
    );
  }

  void _previousStep() {
    ref.read(onboardingProvider.notifier).previousStep();
    _pageController.previousPage(
      duration: DesignTokens.animationPageTransition,
      curve: Curves.easeOutCubic,
    );
  }

  void _nextStep() async {
    final state = ref.read(onboardingProvider);

    // 权限步骤检查：必须授予必要权限才能继续
    if (state.currentStep == kPermissionStepIndex) {
      final hasUsageStats = await UsageStatsService.hasPermission();
      final hasOverlay = await OverlayService.hasPermission();

      if (!hasUsageStats || !hasOverlay) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: DesignTokens.space8),
                  Text('请先授予使用统计和悬浮窗权限'),
                ],
              ),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radius12),
              ),
            ),
          );
        }
        return;
      }
    }

    if (state.currentStep == _steps.length - 1) {
      // 完成
      await ref.read(onboardingProvider.notifier).complete();
      if (mounted) {
        context.go('/home');
      }
    } else {
      ref.read(onboardingProvider.notifier).nextStep();
      _pageController.nextPage(
        duration: DesignTokens.animationPageTransition,
        curve: Curves.easeOutCubic,
      );
    }
  }
}
