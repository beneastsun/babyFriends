import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/points_history.dart';
import 'package:qiaoqiao_companion/shared/providers/providers.dart';
import 'package:qiaoqiao_companion/core/theme/app_solid_colors.dart';

/// 积分历史页面
class PointsHistoryPage extends ConsumerStatefulWidget {
  const PointsHistoryPage({super.key});

  @override
  ConsumerState<PointsHistoryPage> createState() => _PointsHistoryPageState();
}

class _PointsHistoryPageState extends ConsumerState<PointsHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PointsHistory> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final pointsState = ref.read(pointsProvider);
    final history = pointsState.recentHistory;

    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  List<PointsHistory> _filterByType(PointsTransactionType? type) {
    if (type == null) return _history;
    return _history.where((h) => h.type == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pointsState = ref.watch(pointsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: AppSolidColors.getBackgroundColor(AppThemeType.current, isDark),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 标题栏
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.space16,
                  DesignTokens.space8,
                  DesignTokens.space16,
                  DesignTokens.space16,
                ),
                child: Row(
                  children: [
                    Text(
                      '积分记录',
                      style: AppTextStyles.heading1.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),

              // 积分概览卡片
              _buildOverviewCard(pointsState.balance),

              // Tab栏
              Container(
                margin: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
                  boxShadow: AppShadows.card,
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
                  ),
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorPadding: const EdgeInsets.all(DesignTokens.space4),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondaryLight,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: AppTextStyles.labelMedium,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: '全部'),
                    Tab(text: '获得'),
                    Tab(text: '消耗'),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.space16),

              // 积分历史列表
              Expanded(
                child: _isLoading
                    ? Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildHistoryList(null),
                          _buildHistoryList(PointsTransactionType.earned),
                          _buildHistoryList(PointsTransactionType.spent),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(int points) {
    return Container(
      margin: const EdgeInsets.all(DesignTokens.space16),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppSolidColors.pointsGold,
        borderRadius: BorderRadius.circular(DesignTokens.radius20),
        boxShadow: AppShadows.button,
      ),
      child: Stack(
        children: [
          // 装饰性圆形
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // 内容
          Padding(
            padding: const EdgeInsets.all(DesignTokens.space24),
            child: Column(
              children: [
                // 积分数字
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(width: DesignTokens.space8),
                    Text(
                      '$points',
                      style: AppTextStyles.pointsLarge.copyWith(
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space4),
                Text(
                  '当前积分',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: DesignTokens.space20),

                // 统计信息
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space16,
                    vertical: DesignTokens.space12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(DesignTokens.radius12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        '今日获得',
                        _calculateTodayEarned(),
                        Icons.trending_up_rounded,
                        Colors.white,
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      _buildStatItem(
                        '今日消耗',
                        _calculateTodaySpent(),
                        Icons.trending_down_rounded,
                        Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: DesignTokens.space4),
            Text(
              '$value',
              style: AppTextStyles.heading3.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.space4),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  int _calculateTodayEarned() {
    final today = DateTime.now();
    return _history
        .where((h) =>
            h.type == PointsTransactionType.earned &&
            _isSameDay(h.createdAt, today))
        .fold(0, (sum, h) => sum + h.points);
  }

  int _calculateTodaySpent() {
    final today = DateTime.now();
    return _history
        .where((h) =>
            h.type == PointsTransactionType.spent &&
            _isSameDay(h.createdAt, today))
        .fold(0, (sum, h) => sum + h.points);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildHistoryList(PointsTransactionType? type) {
    final filtered = _filterByType(type);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(DesignTokens.space24),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 48,
                color: AppColors.textHintLight,
              ),
            ),
            const SizedBox(height: DesignTokens.space16),
            Text(
              '暂无记录',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHintLight,
              ),
            ),
          ],
        ),
      );
    }

    // 按日期分组
    final grouped = _groupByDate(filtered);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.space16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        return _buildDateGroup(entry.key, entry.value);
      },
    );
  }

  Map<DateTime, List<PointsHistory>> _groupByDate(List<PointsHistory> history) {
    final Map<DateTime, List<PointsHistory>> grouped = {};

    for (final item in history) {
      final date = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );

      grouped.putIfAbsent(date, () => []);
      grouped[date]!.add(item);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, grouped[key]!)),
    );
  }

  Widget _buildDateGroup(DateTime date, List<PointsHistory> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日期标题
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DesignTokens.space8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space12,
                  vertical: DesignTokens.space6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusCapsule),
                ),
                child: Text(
                  _formatDate(date),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 该日期的记录
        ...items.map((item) => _buildHistoryItem(item)),

        const SizedBox(height: DesignTokens.space8),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    if (_isSameDay(date, today)) {
      return '今天';
    } else if (_isSameDay(date, yesterday)) {
      return '昨天';
    } else {
      return '${date.month}月${date.day}日';
    }
  }

  Widget _buildHistoryItem(PointsHistory item) {
    final isEarned = item.type == PointsTransactionType.earned;
    final gradientColor = isEarned ? AppSolidColors.success : AppSolidColors.error;
    final sign = isEarned ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.space8),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(DesignTokens.radius16),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space16),
        child: Row(
          children: [
            // 图标
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: gradientColor,
                borderRadius: BorderRadius.circular(DesignTokens.radius14),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(item.category),
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: DesignTokens.space12),

            // 描述
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space4),
                  Text(
                    _formatTime(item.createdAt),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textHintLight,
                    ),
                  ),
                ],
              ),
            ),

            // 积分变化
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.space12,
                vertical: DesignTokens.space8,
              ),
              decoration: BoxDecoration(
                color: gradientColor,
                borderRadius: BorderRadius.circular(DesignTokens.radius10),
              ),
              child: Text(
                '$sign${item.points}',
                style: AppTextStyles.labelLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(PointsCategory category) {
    switch (category) {
      case PointsCategory.restReward:
        return Icons.bedtime_rounded;
      case PointsCategory.studyReward:
        return Icons.school_rounded;
      case PointsCategory.exerciseReward:
        return Icons.fitness_center_rounded;
      case PointsCategory.readingReward:
        return Icons.menu_book_rounded;
      case PointsCategory.choreReward:
        return Icons.home_rounded;
      case PointsCategory.couponExchange:
        return Icons.card_giftcard_rounded;
      case PointsCategory.timePenalty:
        return Icons.timer_off_rounded;
      case PointsCategory.ruleViolation:
        return Icons.warning_rounded;
      case PointsCategory.dailyBonus:
        return Icons.today_rounded;
      case PointsCategory.achievementBonus:
        return Icons.emoji_events_rounded;
      case PointsCategory.other:
        return Icons.stars_rounded;
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// 积分来源类型的详细说明
class PointsSourceDetail {
  final PointsCategory category;
  final String name;
  final String description;
  final int basePoints;
  final IconData icon;

  const PointsSourceDetail({
    required this.category,
    required this.name,
    required this.description,
    required this.basePoints,
    required this.icon,
  });

  static List<PointsSourceDetail> get sources => [
    PointsSourceDetail(
      category: PointsCategory.restReward,
      name: '按时休息',
      description: '在提醒后按时休息',
      basePoints: PointsConstants.restReward,
      icon: Icons.bedtime_rounded,
    ),
    PointsSourceDetail(
      category: PointsCategory.studyReward,
      name: '学习奖励',
      description: '完成学习任务',
      basePoints: PointsConstants.studyReward,
      icon: Icons.school_rounded,
    ),
    PointsSourceDetail(
      category: PointsCategory.exerciseReward,
      name: '运动奖励',
      description: '完成运动目标',
      basePoints: PointsConstants.exerciseReward,
      icon: Icons.fitness_center_rounded,
    ),
    PointsSourceDetail(
      category: PointsCategory.readingReward,
      name: '阅读奖励',
      description: '完成阅读目标',
      basePoints: PointsConstants.readingReward,
      icon: Icons.menu_book_rounded,
    ),
    PointsSourceDetail(
      category: PointsCategory.choreReward,
      name: '家务奖励',
      description: '完成家务任务',
      basePoints: PointsConstants.choreReward,
      icon: Icons.home_rounded,
    ),
    PointsSourceDetail(
      category: PointsCategory.couponExchange,
      name: '兑换加时券',
      description: '使用积分兑换游戏时间',
      basePoints: 0,
      icon: Icons.card_giftcard_rounded,
    ),
    PointsSourceDetail(
      category: PointsCategory.timePenalty,
      name: '超时惩罚',
      description: '超出时间限制',
      basePoints: PointsConstants.overtimePenalty,
      icon: Icons.timer_off_rounded,
    ),
    PointsSourceDetail(
      category: PointsCategory.ruleViolation,
      name: '违规惩罚',
      description: '违反使用规则',
      basePoints: PointsConstants.ruleViolationPenalty,
      icon: Icons.warning_rounded,
    ),
    PointsSourceDetail(
      category: PointsCategory.dailyBonus,
      name: '每日签到',
      description: '每日登录奖励',
      basePoints: PointsConstants.dailyBonus,
      icon: Icons.today_rounded,
    ),
    PointsSourceDetail(
      category: PointsCategory.achievementBonus,
      name: '成就奖励',
      description: '达成特定成就',
      basePoints: 0,
      icon: Icons.emoji_events_rounded,
    ),
  ];
}
