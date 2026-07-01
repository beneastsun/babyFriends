import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_color_schemes.dart';
import 'app_text_styles.dart';
import 'design_tokens.dart';

export 'app_colors.dart';
export 'app_color_schemes.dart';
export 'app_solid_colors.dart';
export 'app_shadows.dart';
export 'app_animations.dart';
export 'app_text_styles.dart';
export 'design_tokens.dart';

// ========== 向后兼容别名 ==========

/// @deprecated 使用 AppColors 替代
class AppSpacing {
  AppSpacing._();

  static const double xs = DesignTokens.space4;
  static const double sm = DesignTokens.space8;
  static const double md = DesignTokens.space16;
  static const double lg = DesignTokens.space24;
  static const double xl = DesignTokens.space32;
  static const double xxl = DesignTokens.space48;
}

/// @deprecated 使用 DesignTokens.radiusXx 替代
class AppBorderRadiusOld {
  AppBorderRadiusOld._();

  static const double sm = DesignTokens.radius4;
  static const double md = DesignTokens.radius8;
  static const double lg = DesignTokens.radius12;
  static const double xl = DesignTokens.radius16;
  static const double full = DesignTokens.radiusFull;
}

/// @deprecated 使用 DesignTokens.radiusXx 或 BorderRadius.circular() 替代
class AppBorderRadius {
  AppBorderRadius._();

  static const double sm = DesignTokens.radius4;
  static const double md = DesignTokens.radius8;
  static const double lg = DesignTokens.radius12;
  static const double xl = DesignTokens.radius16;
  static const double xxl = DesignTokens.radius20;
  static const double full = DesignTokens.radiusFull;

  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);
  static BorderRadius get xlRadius => BorderRadius.circular(xl);
  static BorderRadius get xxlRadius => BorderRadius.circular(xxl);
  static BorderRadius get fullRadius => BorderRadius.circular(full);
}

/// @deprecated 使用 AppColors 替代
class AppThemeColors {
  AppThemeColors._();

  // 主色
  static const Color primaryColor = AppColors.primary;
  static const Color primaryLight = AppColors.primaryLight;
  static const Color primaryDark = AppColors.primaryDark;

  // 辅助色
  static const Color secondaryColor = AppColors.secondary;
  static const Color secondaryLight = AppColors.secondaryLight;

  // 语义色
  static const Color successColor = AppColors.success;
  static const Color warningColor = AppColors.warning;
  static const Color errorColor = AppColors.error;
  static const Color infoColor = AppColors.info;

  // 文本色
  static const Color textPrimary = AppColors.textPrimaryLight;
  static const Color textSecondary = AppColors.textSecondaryLight;
  static const Color textHint = AppColors.textHintLight;

  // 背景色
  static const Color background = AppColors.backgroundLight;
  static const Color surface = AppColors.surfaceLight;
  static const Color card = AppColors.cardLight;

  // 边框/分割线
  static const Color border = AppColors.borderLight;
  static const Color divider = AppColors.dividerLight;
}

/// 应用主题配置 - 星空蓝 + 极光绿
class AppTheme {
  AppTheme._();

  // ========== 向后兼容静态属性 ==========

  /// @deprecated 使用 AppColors.primary 替代
  static const Color primaryColor = AppColors.primary;

  /// @deprecated 使用 AppColors.primaryLight 替代
  static const Color primaryLight = AppColors.primaryLight;

  /// @deprecated 使用 AppColors.primaryDark 替代
  static const Color primaryDark = AppColors.primaryDark;

  /// @deprecated 使用 AppColors.secondary 替代
  static const Color secondaryColor = AppColors.secondary;

  /// @deprecated 使用 AppColors.secondary 替代 (Material 2 accentColor)
  static const Color accentColor = AppColors.secondary;

  /// @deprecated 使用 AppColors.success 替代
  static const Color successColor = AppColors.success;

  /// @deprecated 使用 AppColors.warning 替代
  static const Color warningColor = AppColors.warning;

  /// @deprecated 使用 AppColors.error 替代
  static const Color errorColor = AppColors.error;

  /// @deprecated 使用 AppColors.info 替代
  static const Color infoColor = AppColors.info;

  /// @deprecated 使用 AppColors.textSecondaryLight 替代
  static const Color textSecondary = AppColors.textSecondaryLight;

  /// @deprecated 使用 AppColors.textPrimaryLight 替代
  static const Color textPrimary = AppColors.textPrimaryLight;

  /// @deprecated 使用 AppColors.textHintLight 替代
  static const Color textHint = AppColors.textHintLight;

  /// @deprecated 使用 AppColors.backgroundLight 替代
  static const Color background = AppColors.backgroundLight;

  /// @deprecated 使用 AppColors.surfaceLight 替代
  static const Color surface = AppColors.surfaceLight;

  /// @deprecated 使用 AppColors.cardLight 替代
  static const Color card = AppColors.cardLight;

  /// @deprecated 使用 AppColors.borderLight 替代
  static const Color border = AppColors.borderLight;

  /// @deprecated 使用 AppColors.dividerLight 替代
  static const Color divider = AppColors.dividerLight;

  /// @deprecated 使用 AppColors.surfaceLight 替代
  static const Color surfaceColor = AppColors.surfaceLight;

  /// @deprecated 使用 AppColors.pointsGold 替代
  static const Color pointsColor = AppColors.pointsGold;

  // ========== 巧巧心情色 ==========

  /// @deprecated 使用 AppColors.qiaoqiaoHappy 替代
  static const Color qiaoqiaoHappy = AppColors.qiaoqiaoHappy;

  /// @deprecated 使用 AppColors.qiaoqiaoRemind 替代
  static const Color qiaoqiaoRemind = AppColors.qiaoqiaoRemind;

  /// @deprecated 使用 AppColors.qiaoqiaoSerious 替代
  static const Color qiaoqiaoSerious = AppColors.qiaoqiaoSerious;

  /// @deprecated 使用 AppColors.qiaoqiaoSad 替代
  static const Color qiaoqiaoSad = AppColors.qiaoqiaoSad;

  // ========== 分类颜色 ==========

  /// @deprecated 使用 AppColors.gameColor 替代
  static const Color gameColor = AppColors.gameColor;

  /// @deprecated 使用 AppColors.videoColor 替代
  static const Color videoColor = AppColors.videoColor;

  /// @deprecated 使用 AppColors.studyColor 替代
  static const Color studyColor = AppColors.studyColor;

  /// @deprecated 使用 AppColors.readingColor 替代
  static const Color readingColor = AppColors.readingColor;

  // ========== 方法 ==========

  /// @deprecated 使用 AppColors.getCategoryColor 替代
  static Color getCategoryColor(String category) =>
      AppColors.getCategoryColor(category);

  /// 浅色主题
  static ThemeData get lightTheme {
    final colorScheme = AppColors.lightColorScheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,

      // 背景色
      scaffoldBackgroundColor: AppColors.backgroundLight,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.heading2,
        iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
      ),

      // 卡片
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
        ),
        shadowColor: AppColors.primary.withOpacity(0.1),
      ),

      // 按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, DesignTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space24,
            vertical: DesignTokens.space12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
          ),
          textStyle: AppTextStyles.button,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),

      // 文本按钮
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space16,
            vertical: DesignTokens.space8,
          ),
          textStyle: AppTextStyles.buttonSmall,
        ),
      ),

      // 悬浮按钮
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
        ),
      ),

      // 底部导航
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTextStyles.navLabelActive,
        unselectedLabelStyle: AppTextStyles.navLabel,
      ),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space16,
          vertical: DesignTokens.space12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: AppTextStyles.bodyMedium,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHintLight),
      ),

      // 标签
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryContainer,
        selectedColor: AppColors.primary,
        labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimaryLight),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space12,
          vertical: DesignTokens.space4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
        ),
      ),

      // 进度条
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),

      // 滑块
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.primaryLight.withOpacity(0.3),
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withOpacity(0.2),
        valueIndicatorColor: AppColors.primary,
      ),

      // 开关
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textHintLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight;
          }
          return AppColors.borderLight;
        }),
      ),

      // 复选框
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppColors.borderLight, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.space4),
        ),
      ),

      // 分割线
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
        space: DesignTokens.space24,
      ),

      // 图标
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryLight,
        size: DesignTokens.iconMedium,
      ),

      // 对话框
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius20),
        ),
        titleTextStyle: AppTextStyles.heading2,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),

      // 底部弹窗
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radius20),
          ),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Tab栏
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondaryLight,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.labelLarge,
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  /// 深色主题
  static ThemeData get darkTheme {
    final colorScheme = AppColors.darkColorScheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,

      // 背景色
      scaffoldBackgroundColor: AppColors.backgroundDark,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.heading2Dark,
        iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
      ),

      // 卡片
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
        ),
      ),

      // 按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDarkMode,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, DesignTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space24,
            vertical: DesignTokens.space12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
          ),
          textStyle: AppTextStyles.button,
          elevation: 0,
        ),
      ),

      // 文本按钮
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDarkMode,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space16,
            vertical: DesignTokens.space8,
          ),
          textStyle: AppTextStyles.buttonSmall,
        ),
      ),

      // 悬浮按钮
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryDarkMode,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // 底部导航
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primaryDarkMode,
        unselectedItemColor: AppColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space16,
          vertical: DesignTokens.space12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: const BorderSide(color: AppColors.primaryDarkMode, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: const BorderSide(color: AppColors.errorDarkMode),
        ),
        labelStyle: AppTextStyles.bodyMediumDark,
        hintStyle: AppTextStyles.bodyMediumDark.copyWith(color: AppColors.textHintDark),
      ),

      // 标签
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryContainerDarkMode,
        selectedColor: AppColors.primaryDarkMode,
        labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimaryDark),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space12,
          vertical: DesignTokens.space4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
        ),
      ),

      // 进度条
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryDarkMode,
      ),

      // 滑块
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primaryDarkMode,
        inactiveTrackColor: AppColors.primaryLightDarkMode.withOpacity(0.3),
        thumbColor: AppColors.primaryDarkMode,
        overlayColor: AppColors.primaryDarkMode.withOpacity(0.2),
      ),

      // 开关
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryDarkMode;
          }
          return AppColors.textHintDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLightDarkMode;
          }
          return AppColors.borderDark;
        }),
      ),

      // 复选框
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryDarkMode;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppColors.borderDark, width: 2),
      ),

      // 分割线
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
        space: DesignTokens.space24,
      ),

      // 图标
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryDark,
        size: DesignTokens.iconMedium,
      ),

      // 对话框
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius20),
        ),
        titleTextStyle: AppTextStyles.heading2Dark,
        contentTextStyle: AppTextStyles.bodyMediumDark,
      ),

      // 底部弹窗
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radius20),
          ),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardDark,
        contentTextStyle: AppTextStyles.bodyMediumDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Tab栏
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primaryDarkMode,
        unselectedLabelColor: AppColors.textSecondaryDark,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.labelLarge,
      ),
    );
  }

  /// 根据亮度获取主题
  static ThemeData themeByBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? darkTheme : lightTheme;
  }

  // ========== 多主题支持 ==========

  /// 根据主题类型和亮度获取主题
  static ThemeData getTheme(AppThemeType themeType, {required bool isDark}) {
    final colors = AppColorSchemes.getScheme(themeType);

    return isDark
        ? _buildDarkTheme(colors, themeType)
        : _buildLightTheme(colors, themeType);
  }

  /// 构建浅色主题（基于颜色方案）
  static ThemeData _buildLightTheme(ColorSchemeConfig colors, AppThemeType themeType) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: Brightness.light,
      primary: colors.primary,
      secondary: colors.secondary,
      error: AppColors.error,
      surface: colors.surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,

      // 背景色
      scaffoldBackgroundColor: colors.backgroundLight,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimaryLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.heading2.copyWith(color: colors.textPrimaryLight),
        iconTheme: IconThemeData(color: colors.textPrimaryLight),
      ),

      // 卡片
      cardTheme: CardThemeData(
        color: colors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
        ),
        shadowColor: colors.primary.withOpacity(0.1),
      ),

      // 按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, DesignTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space24,
            vertical: DesignTokens.space12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
          ),
          textStyle: AppTextStyles.button,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),

      // 文本按钮
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space16,
            vertical: DesignTokens.space8,
          ),
          textStyle: AppTextStyles.buttonSmall,
        ),
      ),

      // 悬浮按钮
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius16),
        ),
      ),

      // 底部导航
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTextStyles.navLabelActive.copyWith(color: colors.primary),
        unselectedLabelStyle: AppTextStyles.navLabel,
      ),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space16,
          vertical: DesignTokens.space12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: BorderSide(color: colors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: BorderSide(color: colors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimaryLight),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: colors.textHintLight),
      ),

      // 标签
      chipTheme: ChipThemeData(
        backgroundColor: colors.primaryContainer,
        selectedColor: colors.primary,
        labelStyle: AppTextStyles.labelMedium.copyWith(color: colors.textPrimaryLight),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space12,
          vertical: DesignTokens.space4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
        ),
      ),

      // 进度条
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
      ),

      // 滑块
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.primaryLight.withOpacity(0.3),
        thumbColor: colors.primary,
        overlayColor: colors.primary.withOpacity(0.2),
        valueIndicatorColor: colors.primary,
      ),

      // 开关
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return colors.textHintLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primaryLight;
          }
          return colors.borderLight;
        }),
      ),

      // 复选框
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: colors.borderLight, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.space4),
        ),
      ),

      // 分割线
      dividerTheme: DividerThemeData(
        color: colors.dividerLight,
        thickness: 1,
        space: DesignTokens.space24,
      ),

      // 图标
      iconTheme: IconThemeData(
        color: colors.textPrimaryLight,
        size: DesignTokens.iconMedium,
      ),

      // 对话框
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius20),
        ),
        titleTextStyle: AppTextStyles.heading2.copyWith(color: colors.textPrimaryLight),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimaryLight),
      ),

      // 底部弹窗
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radius20),
          ),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceDark,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Tab栏
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.textSecondaryLight,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.labelLarge,
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  /// 构建深色主题（基于颜色方案）
  static ThemeData _buildDarkTheme(ColorSchemeConfig colors, AppThemeType themeType) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.primaryDarkMode,
      brightness: Brightness.dark,
      primary: colors.primaryDarkMode,
      secondary: colors.secondaryDarkMode,
      error: AppColors.errorDarkMode,
      surface: colors.surfaceDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,

      // 背景色
      scaffoldBackgroundColor: colors.backgroundDark,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colors.textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.heading2Dark,
        iconTheme: IconThemeData(color: colors.textPrimaryDark),
      ),

      // 卡片
      cardTheme: CardThemeData(
        color: colors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
        ),
      ),

      // 按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primaryDarkMode,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, DesignTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space24,
            vertical: DesignTokens.space12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius12),
          ),
          textStyle: AppTextStyles.button,
          elevation: 0,
        ),
      ),

      // 文本按钮
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primaryDarkMode,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space16,
            vertical: DesignTokens.space8,
          ),
          textStyle: AppTextStyles.buttonSmall,
        ),
      ),

      // 悬浮按钮
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primaryDarkMode,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // 底部导航
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: colors.primaryDarkMode,
        unselectedItemColor: colors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space16,
          vertical: DesignTokens.space12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: BorderSide(color: colors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: BorderSide(color: colors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: BorderSide(color: colors.primaryDarkMode, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius8),
          borderSide: const BorderSide(color: AppColors.errorDarkMode),
        ),
        labelStyle: AppTextStyles.bodyMediumDark,
        hintStyle: AppTextStyles.bodyMediumDark.copyWith(color: colors.textHintDark),
      ),

      // 标签
      chipTheme: ChipThemeData(
        backgroundColor: colors.primaryContainerDarkMode,
        selectedColor: colors.primaryDarkMode,
        labelStyle: AppTextStyles.labelMedium.copyWith(color: colors.textPrimaryDark),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space12,
          vertical: DesignTokens.space4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
        ),
      ),

      // 进度条
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primaryDarkMode,
      ),

      // 滑块
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primaryDarkMode,
        inactiveTrackColor: colors.primaryLightDarkMode.withOpacity(0.3),
        thumbColor: colors.primaryDarkMode,
        overlayColor: colors.primaryDarkMode.withOpacity(0.2),
      ),

      // 开关
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primaryDarkMode;
          }
          return colors.textHintDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primaryLightDarkMode;
          }
          return colors.borderDark;
        }),
      ),

      // 复选框
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primaryDarkMode;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: colors.borderDark, width: 2),
      ),

      // 分割线
      dividerTheme: DividerThemeData(
        color: colors.dividerDark,
        thickness: 1,
        space: DesignTokens.space24,
      ),

      // 图标
      iconTheme: IconThemeData(
        color: colors.textPrimaryDark,
        size: DesignTokens.iconMedium,
      ),

      // 对话框
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius20),
        ),
        titleTextStyle: AppTextStyles.heading2Dark,
        contentTextStyle: AppTextStyles.bodyMediumDark,
      ),

      // 底部弹窗
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radius20),
          ),
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.cardDark,
        contentTextStyle: AppTextStyles.bodyMediumDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius12),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Tab栏
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primaryDarkMode,
        unselectedLabelColor: colors.textSecondaryDark,
        labelStyle: AppTextStyles.labelLarge,
        unselectedLabelStyle: AppTextStyles.labelLarge,
      ),
    );
  }
}
