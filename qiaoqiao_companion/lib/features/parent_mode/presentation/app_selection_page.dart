import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/services/app_discovery_service.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/providers/monitored_apps_provider.dart';

/// 应用选择页面
class AppSelectionPage extends ConsumerStatefulWidget {
  const AppSelectionPage({super.key});

  @override
  ConsumerState<AppSelectionPage> createState() => _AppSelectionPageState();
}

class _AppSelectionPageState extends ConsumerState<AppSelectionPage> {
  List<InstalledApp> _allApps = [];
  List<InstalledApp> _filteredApps = [];
  final Map<String, String> _selectedApps = {}; // packageName -> appName
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final service = ref.read(appDiscoveryServiceProvider);
    final apps = await service.getInstalledApps();

    // 获取已监控的应用包名
    final monitoredApps = ref.read(monitoredAppsProvider);
    final monitoredPackages = monitoredApps.monitoredPackageNames;

    // 过滤掉已监控的应用
    final unmonitoredApps =
        apps.where((app) => !monitoredPackages.contains(app.packageName)).toList();

    setState(() {
      _allApps = unmonitoredApps;
      _filteredApps = unmonitoredApps;
      _isLoading = false;
    });
  }

  void _filterApps(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredApps = _allApps;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredApps = _allApps.where((app) {
          return app.appName.toLowerCase().contains(lowerQuery) ||
              app.packageName.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('选择应用'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedApps.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: Text(
                '确认(${_selectedApps.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              onChanged: _filterApps,
              decoration: InputDecoration(
                hintText: '搜索应用',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                ),
                filled: true,
                fillColor: AppTheme.surfaceColor,
              ),
            ),
          ),

          // 应用列表
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredApps.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final isSelected =
                              _selectedApps.containsKey(app.packageName);
                          return _buildAppItem(app, isSelected);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppTheme.textHint,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            _searchQuery.isEmpty ? '没有可添加的应用' : '没有找到匹配的应用',
            style: AppTextStyles.body1,
          ),
        ],
      ),
    );
  }

  Widget _buildAppItem(InstalledApp app, bool isSelected) {
    return ListTile(
      leading: buildAppIcon(app, size: 40),
      title: Row(
        children: [
          Expanded(child: Text(app.appName)),
          if (app.category == 'game' || app.category == 'video')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: app.getCategoryColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                app.getCategoryEmoji(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
      subtitle: Text(
        app.packageName,
        style: AppTextStyles.caption,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedApps[app.packageName] = app.appName;
            } else {
              _selectedApps.remove(app.packageName);
            }
          });
        },
      ),
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedApps.remove(app.packageName);
          } else {
            _selectedApps[app.packageName] = app.appName;
          }
        });
      },
    );
  }

  void _confirm() {
    Navigator.pop(context, _selectedApps);
  }
}
