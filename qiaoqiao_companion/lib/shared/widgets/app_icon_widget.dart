import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/services/app_category_matcher.dart';
import 'package:qiaoqiao_companion/shared/providers/installed_apps_provider.dart';

/// 通用应用图标组件
///
/// 根据 packageName 自动从 installedAppsProvider 获取图标，
/// 如果没有图标则显示分类 emoji 作为备选。
///
/// 用法：
/// ```dart
/// AppIconWidget(packageName: 'com.tencent.mm', size: 40)
/// ```
class AppIconWidget extends ConsumerWidget {
  final String packageName;
  final double size;
  final String? appName; // 可选，用于分类匹配
  final String? appIcon; // 可选，直接传入图标（Base64）

  const AppIconWidget({
    super.key,
    required this.packageName,
    this.size = 40,
    this.appName,
    this.appIcon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. 如果直接传入了图标，使用它
    if (appIcon != null && appIcon!.isNotEmpty) {
      return _buildIconFromBase64(appIcon!);
    }

    // 2. 从 installedAppsProvider 获取图标
    final installedAppsAsync = ref.watch(installedAppsProvider);

    return installedAppsAsync.when(
      data: (data) {
        final icon = data.getIcon(packageName);
        if (icon != null && icon.isNotEmpty) {
          return _buildIconFromBase64(icon);
        }
        return _buildFallbackIcon(data.getName(packageName));
      },
      loading: () => _buildFallbackIcon(appName),
      error: (_, __) => _buildFallbackIcon(appName),
    );
  }

  Widget _buildIconFromBase64(String base64Icon) {
    try {
      final bytes = base64Decode(base64Icon);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackIcon(appName),
        ),
      );
    } catch (e) {
      return _buildFallbackIcon(appName);
    }
  }

  Widget _buildFallbackIcon(String? name) {
    // 根据包名或应用名称匹配分类
    final category = PresetAppCategories.matchCategory(
      packageName,
      name ?? packageName,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getCategoryColor(category).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          _getCategoryEmoji(category),
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'game':
        return const Color(0xFFFF6B6B);
      case 'video':
        return const Color(0xFF4ECDC4);
      case 'study':
        return const Color(0xFF45B7D1);
      case 'reading':
        return const Color(0xFF96CEB4);
      case 'social':
        return const Color(0xFFFF9F43);
      default:
        return Colors.grey;
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'game':
        return '🎮';
      case 'video':
        return '📺';
      case 'study':
        return '📚';
      case 'reading':
        return '📖';
      case 'social':
        return '💬';
      default:
        return '📱';
    }
  }
}

/// 构建应用图标的辅助函数（无 Provider 版本）
///
/// 用于已知图标 Base64 数据的场景
Widget buildAppIconFromBase64({
  required String? appIcon,
  required String packageName,
  String? appName,
  double size = 40,
}) {
  if (appIcon != null && appIcon.isNotEmpty) {
    try {
      final bytes = base64Decode(appIcon);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackIconStatic(packageName, appName, size),
        ),
      );
    } catch (e) {
      return _buildFallbackIconStatic(packageName, appName, size);
    }
  }
  return _buildFallbackIconStatic(packageName, appName, size);
}

Widget _buildFallbackIconStatic(String packageName, String? appName, double size) {
  final category = PresetAppCategories.matchCategory(
    packageName,
    appName ?? packageName,
  );

  Color color;
  String emoji;

  switch (category) {
    case 'game':
      color = const Color(0xFFFF6B6B);
      emoji = '🎮';
      break;
    case 'video':
      color = const Color(0xFF4ECDC4);
      emoji = '📺';
      break;
    case 'study':
      color = const Color(0xFF45B7D1);
      emoji = '📚';
      break;
    case 'reading':
      color = const Color(0xFF96CEB4);
      emoji = '📖';
      break;
    case 'social':
      color = const Color(0xFFFF9F43);
      emoji = '💬';
      break;
    default:
      color = Colors.grey;
      emoji = '📱';
  }

  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Center(
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.5),
      ),
    ),
  );
}

/// 获取应用显示名称
///
/// 优先使用提供的名称，否则尝试从 installedAppsProvider 获取
/// 如果都没有，返回友好的包名
String getAppDisplayName({
  required String packageName,
  String? appName,
  InstalledAppsData? installedAppsData,
}) {
  // 1. 如果提供了 appName 且不是包名格式，直接使用
  if (appName != null && appName.isNotEmpty && !appName.contains('.')) {
    return appName;
  }

  // 2. 从 installedAppsData 获取
  if (installedAppsData != null) {
    final cachedName = installedAppsData.getName(packageName);
    if (cachedName != null && cachedName.isNotEmpty) {
      return cachedName;
    }
  }

  // 3. 如果 appName 是包名格式，生成友好名称
  if (appName != null && appName.contains('.')) {
    return _generateFriendlyAppName(appName);
  }

  // 4. 从包名生成友好名称
  return _generateFriendlyAppName(packageName);
}

/// 从包名生成友好的应用名称
String _generateFriendlyAppName(String packageName) {
  // 取包名最后一部分作为名称
  final parts = packageName.split('.');
  if (parts.isNotEmpty) {
    final name = parts.last;
    // 首字母大写
    if (name.isNotEmpty) {
      return name[0].toUpperCase() + name.substring(1);
    }
    return name;
  }
  return packageName;
}

/// ConsumerWidget 版本的获取应用显示名称
///
/// 用于在 Widget 中获取名称
class AppDisplayName extends ConsumerWidget {
  final String packageName;
  final String? appName;
  final Widget Function(String displayName) builder;

  const AppDisplayName({
    super.key,
    required this.packageName,
    this.appName,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installedAppsAsync = ref.watch(installedAppsProvider);

    return installedAppsAsync.when(
      data: (data) {
        final displayName = getAppDisplayName(
          packageName: packageName,
          appName: appName,
          installedAppsData: data,
        );
        return builder(displayName);
      },
      loading: () => builder(getAppDisplayName(
        packageName: packageName,
        appName: appName,
      )),
      error: (_, __) => builder(getAppDisplayName(
        packageName: packageName,
        appName: appName,
      )),
    );
  }
}
