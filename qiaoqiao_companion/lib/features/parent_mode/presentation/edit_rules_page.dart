import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_colors.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/tabs/app_management_tab.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/tabs/continuous_usage_tab.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/tabs/time_periods_tab.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/tabs/total_time_tab.dart';

/// 修改规则页面 - Tab 布局
class EditRulesPage extends ConsumerStatefulWidget {
  const EditRulesPage({super.key});

  @override
  ConsumerState<EditRulesPage> createState() => _EditRulesPageState();
}

class _EditRulesPageState extends ConsumerState<EditRulesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('规则设置'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.access_time), text: '总时长'),
            Tab(icon: Icon(Icons.schedule), text: '时间段'),
            Tab(icon: Icon(Icons.apps), text: '应用'),
            Tab(icon: Icon(Icons.timer), text: '连续使用'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          TotalTimeTab(),
          TimePeriodsTab(),
          AppManagementTab(),
          ContinuousUsageTab(),
        ],
      ),
    );
  }
}
