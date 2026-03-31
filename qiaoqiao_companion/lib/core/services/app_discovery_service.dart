import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/platform/usage_stats_service.dart';
import 'package:qiaoqiao_companion/core/services/app_category_matcher.dart';

/// 已安装应用信息
class InstalledApp {
  final String packageName;
  final String appName;
  final String? category;
  final String? appIcon; // Base64 编码的应用图标
  final bool isSystemApp;

  const InstalledApp({
    required this.packageName,
    required this.appName,
    this.category,
    this.appIcon,
    this.isSystemApp = false,
  });

  /// 获取分类枚举
  AppCategoryType get categoryType {
    switch (category) {
      case 'game':
        return AppCategoryType.game;
      case 'video':
        return AppCategoryType.video;
      case 'study':
        return AppCategoryType.study;
      case 'reading':
        return AppCategoryType.reading;
      case 'social':
        return AppCategoryType.social;
      default:
        return AppCategoryType.other;
    }
  }

  /// 获取排序优先级（游戏和视频排前面，系统应用排后面）
  int get sortPriority {
    // 游戏和视频最高优先级
    if (category == 'game' || category == 'video') return 0;
    // 社交应用
    if (category == 'social') return 1;
    // 学习和阅读
    if (category == 'study' || category == 'reading') return 2;
    // 其他非系统应用
    if (!isSystemApp) return 3;
    // 系统应用最低优先级
    return 4;
  }

  /// 获取分类颜色
  Color getCategoryColor() {
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

  /// 获取分类图标
  IconData getCategoryIcon() {
    switch (category) {
      case 'game':
        return Icons.games;
      case 'video':
        return Icons.video_library;
      case 'study':
        return Icons.school;
      case 'reading':
        return Icons.book;
      case 'social':
        return Icons.people;
      default:
        return Icons.apps;
    }
  }

  /// 获取分类 emoji
  String getCategoryEmoji() {
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstalledApp &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;
}

/// 应用分类类型
enum AppCategoryType {
  game,
  video,
  study,
  reading,
  social,
  other,
}

/// 应用发现服务 - 获取设备上已安装的应用列表
class AppDiscoveryService {
  /// 系统应用包名前缀（需要过滤）
  static const _systemPackagePrefixes = [
    'com.android.',
    'android.',
    'com.google.android.',
    'com.samsung.',
    'com.miui.',
    'com.xiaomi.',
  ];

  /// 本应用包名
  static const _selfPackage = 'com.qiaoqiao.qiaoqiao_companion';

  /// 获取已安装应用列表
  Future<List<InstalledApp>> getInstalledApps() async {
    try {
      // 使用 UsageStatsService 获取已安装应用
      final apps = await UsageStatsService.getInstalledApps();
      final installedApps = apps.where(_shouldInclude).map((appInfo) {
        // 自动匹配分类
        final category = PresetAppCategories.matchCategory(
          appInfo.packageName,
          appInfo.appName,
        );
        return InstalledApp(
          packageName: appInfo.packageName,
          appName: appInfo.appName,
          category: category,
          appIcon: appInfo.appIcon,
          isSystemApp: appInfo.isSystemApp,
        );
      }).toList();

      // 排序：游戏和视频排前面，系统应用排后面
      installedApps.sort((a, b) {
        // 首先按优先级排序
        final priorityCompare = a.sortPriority.compareTo(b.sortPriority);
        if (priorityCompare != 0) return priorityCompare;
        // 同优先级按名称排序
        return a.appName.compareTo(b.appName);
      });

      return installedApps;
    } catch (e) {
      debugPrint('Failed to get installed apps: $e');
      return [];
    }
  }

  /// 判断是否应该包含该应用
  bool _shouldInclude(AppInfo app) {
    // 排除本应用
    if (app.packageName == _selfPackage) return false;

    // 排除系统应用前缀
    for (final prefix in _systemPackagePrefixes) {
      if (app.packageName.startsWith(prefix)) return false;
    }

    return true;
  }

  /// 搜索应用
  Future<List<InstalledApp>> searchApps(String query) async {
    final apps = await getInstalledApps();
    if (query.isEmpty) return apps;

    final lowerQuery = query.toLowerCase();
    return apps.where((app) {
      return app.appName.toLowerCase().contains(lowerQuery) ||
          app.packageName.toLowerCase().contains(lowerQuery);
    }).toList();
  }
}

/// 构建应用图标的辅助方法
Widget buildAppIcon(InstalledApp app, {double size = 40}) {
  // 如果有 Base64 编码的图标，显示真实图标
  if (app.appIcon != null && app.appIcon!.isNotEmpty) {
    try {
      final bytes = base64Decode(app.appIcon!);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackIcon(app, size),
        ),
      );
    } catch (e) {
      return _buildFallbackIcon(app, size);
    }
  }
  return _buildFallbackIcon(app, size);
}

Widget _buildFallbackIcon(InstalledApp app, double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: app.getCategoryColor().withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Center(
      child: Text(
        app.getCategoryEmoji(),
        style: TextStyle(fontSize: size * 0.5),
      ),
    ),
  );
}

final appDiscoveryServiceProvider = Provider<AppDiscoveryService>((ref) {
  return AppDiscoveryService();
});
