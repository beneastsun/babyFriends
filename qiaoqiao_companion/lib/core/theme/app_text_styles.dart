import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// 应用文字样式系统
class AppTextStyles {
  AppTextStyles._();

  // ========== 基础字体设置 ==========

  /// Display 字体 - Nunito（标题、大数字）
  static TextStyle get _displayFont => GoogleFonts.nunito();

  /// Body 字体 - Quicksand（正文、标签）
  static TextStyle get _bodyFont => GoogleFonts.quicksand();

  // ========== Display 样式 ==========

  /// 超大标题
  static TextStyle get displayLarge => _displayFont.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.5,
        color: AppColors.textPrimaryLight,
      );

  /// 大标题
  static TextStyle get displayMedium => _displayFont.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimaryLight,
      );

  /// 中标题
  static TextStyle get displaySmall => _displayFont.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimaryLight,
      );

  /// Display1 - 大号显示样式（向后兼容）
  static TextStyle get display1 => _displayFont.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.1,
        color: AppColors.textPrimaryLight,
      );

  // ========== Heading 样式 ==========

  /// 标题1
  static TextStyle get heading1 => _displayFont.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimaryLight,
      );

  /// 标题2
  static TextStyle get heading2 => _displayFont.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.textPrimaryLight,
      );

  /// 标题3
  static TextStyle get heading3 => _displayFont.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.textPrimaryLight,
      );

  // ========== Body 样式 ==========

  /// 大正文
  static TextStyle get bodyLarge => _bodyFont.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        letterSpacing: 0.25,
        color: AppColors.textPrimaryLight,
      );

  /// 标准正文
  static TextStyle get bodyMedium => _bodyFont.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.textPrimaryLight,
      );

  /// 小正文
  static TextStyle get bodySmall => _bodyFont.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.textSecondaryLight,
      );

  // ========== Label 样式 ==========

  /// 标签
  static TextStyle get labelLarge => _bodyFont.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimaryLight,
      );

  /// 小标签
  static TextStyle get labelMedium => _bodyFont.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textSecondaryLight,
      );

  /// 超小标签
  static TextStyle get labelSmall => _bodyFont.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textSecondaryLight,
      );

  // ========== 特殊样式 ==========

  /// 积分数字
  static TextStyle get points => _displayFont.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 1.0,
        color: AppColors.pointsGold,
      );

  /// 大积分数字
  static TextStyle get pointsLarge => _displayFont.copyWith(
        fontSize: 64,
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: AppColors.pointsGold,
      );

  /// 倒计时数字
  static TextStyle get timer => _displayFont.copyWith(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: AppColors.textPrimaryLight,
      );

  /// 小倒计时
  static TextStyle get timerSmall => _displayFont.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: AppColors.textPrimaryLight,
      );

  /// 按钮
  static TextStyle get button => _bodyFont.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.5,
        color: Colors.white,
      );

  /// 小按钮
  static TextStyle get buttonSmall => _bodyFont.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.3,
        color: Colors.white,
      );

  /// 说明文字
  static TextStyle get caption => _bodyFont.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textHintLight,
      );

  /// 链接
  static TextStyle get link => _bodyFont.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.primary,
        decoration: TextDecoration.underline,
      );

  // ========== 获得积分样式 ==========

  /// 积分获得（绿色）
  static TextStyle get pointsEarned => points.copyWith(
        color: AppColors.pointsEarned,
      );

  /// 积分消耗（红色）
  static TextStyle get pointsSpent => points.copyWith(
        color: AppColors.pointsSpent,
      );

  // ========== 上下文样式 ==========

  /// 卡片标题
  static TextStyle get cardTitle => heading2.copyWith(
        color: Colors.white,
      );

  /// 卡片正文
  static TextStyle get cardBody => bodyMedium.copyWith(
        color: Colors.white.withOpacity(0.9),
      );

  /// 导航栏标签
  static TextStyle get navLabel => _bodyFont.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.0,
      );

  /// 导航栏标签（激活状态）
  static TextStyle get navLabelActive => navLabel.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      );

  // ========== 深色模式样式 ==========

  /// 深色模式 - 标题1
  static TextStyle get heading1Dark => heading1.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// 深色模式 - 标题2
  static TextStyle get heading2Dark => heading2.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// 深色模式 - 正文
  static TextStyle get bodyLargeDark => bodyLarge.copyWith(
        color: AppColors.textPrimaryDark,
      );

  /// 深色模式 - 次要文字
  static TextStyle get bodyMediumDark => bodyMedium.copyWith(
        color: AppColors.textSecondaryDark,
      );

  // ========== 辅助方法 ==========

  /// 根据亮度获取标题样式
  static TextStyle heading1ByBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? heading1Dark : heading1;
  }

  /// 根据亮度获取正文样式
  static TextStyle bodyByBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? bodyLargeDark : bodyLarge;
  }

  /// 获取分类颜色样式
  static TextStyle categoryLabel(String category) {
    return labelMedium.copyWith(
      color: AppColors.getCategoryColor(category),
    );
  }

  // ========== 向后兼容别名 ==========

  /// @deprecated 使用 bodyMedium 替代
  static TextStyle get body2 => bodyMedium;

  /// @deprecated 使用 bodyLarge 替代
  static TextStyle get body1 => bodyLarge;

  /// @deprecated 使用 labelMedium 替代
  static TextStyle get caption2 => labelMedium;

  /// @deprecated 使用 labelSmall 替代
  static TextStyle get caption3 => labelSmall;

  /// @deprecated 使用 heading1 替代
  static TextStyle get h1 => heading1;

  /// @deprecated 使用 heading2 替代
  static TextStyle get h2 => heading2;

  /// @deprecated 使用 heading3 替代
  static TextStyle get h3 => heading3;
}
