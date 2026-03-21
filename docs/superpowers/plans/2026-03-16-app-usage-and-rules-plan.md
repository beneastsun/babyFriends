# 单应用使用时长查看与规则设置 - 实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在首页展示每个应用的今日使用时长，支持对单个应用设置工作日/节假日时间限制

**Architecture:** 复用现有 Rule 模型的 appSingle 类型，新增 AppUsageSummary 模型和 appUsageListProvider，修改 RuleCheckerService 支持单应用规则优先检查

**Tech Stack:** Flutter + Dart + Riverpod + SQLite (sqflite)

**Spec:** `docs/superpowers/specs/2026-03-16-app-usage-and-rules-design.md`

---

## File Structure

### New Files
| File | Purpose |
|------|---------|
| `lib/shared/models/limit_source.dart` | 限制来源枚举 |
| `lib/shared/models/app_usage_summary.dart` | 应用使用汇总模型 |
| `lib/shared/providers/app_usage_list_provider.dart` | 应用列表 Provider |
| `lib/features/home/presentation/widgets/app_usage_list.dart` | 应用使用列表组件 |
| `lib/features/home/presentation/widgets/app_limit_dialog.dart` | 时间限制设置对话框 |
| `lib/features/app_list/presentation/app_list_page.dart` | 完整应用列表页面 |

### Modified Files
| File | Changes |
|------|---------|
| `lib/shared/models/models.dart` | 导出新模型 |
| `lib/shared/providers/providers.dart` | 导出新 Provider |
| `lib/core/database/daos/app_usage_dao.dart` | 新增 getTodayAggregated() |
| `lib/core/database/daos/rule_dao.dart` | 新增 deleteByTypeAndTarget(), getAppRule() |
| `lib/features/home/presentation/home_page.dart` | 使用新的 app 列表组件 |
| `lib/app/router.dart` | 新增路由 |
| `lib/core/services/rule_checker_service.dart` | 支持单应用规则检查 |

---

## Chunk 1: Data Layer - Models and DAOs

### Task 1.1: LimitSource 枚举

**Files:**
- Create: `lib/shared/models/limit_source.dart`
- Modify: `lib/shared/models/models.dart`

- [ ] **Step 1: Create LimitSource enum**

```dart
// lib/shared/models/limit_source.dart

/// 限制来源枚举
enum LimitSource {
  singleApp('single_app', '单应用规则'),
  category('category', '分类规则'),
  total('total', '总时间规则'),
  none('none', '无限制');

  final String code;
  final String label;

  const LimitSource(this.code, this.label);

  static LimitSource fromCode(String code) {
    return LimitSource.values.firstWhere(
      (e) => e.code == code,
      orElse: () => LimitSource.none,
    );
  }
}
```

- [ ] **Step 2: Export in models.dart**

Add to `lib/shared/models/models.dart`:
```dart
export 'limit_source.dart';
```

- [ ] **Step 3: Verify compilation**

Run: `cd qiaoqiao_companion && flutter analyze lib/shared/models/`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/shared/models/limit_source.dart lib/shared/models/models.dart
git commit -m "feat: add LimitSource enum for distinguishing limit source"
```

---

### Task 1.2: AppUsageSummary 模型

**Files:**
- Create: `lib/shared/models/app_usage_summary.dart`
- Modify: `lib/shared/models/models.dart`

- [ ] **Step 1: Create AppUsageSummary model**

```dart
// lib/shared/models/app_usage_summary.dart

import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

/// 应用使用汇总模型
class AppUsageSummary {
  final String packageName;
  final String appName;
  final AppCategory category;
  final int todayDurationSeconds;
  final int? limitMinutes;
  final LimitSource limitSource;
  final bool hasRule;

  const AppUsageSummary({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.todayDurationSeconds,
    this.limitMinutes,
    required this.limitSource,
    required this.hasRule,
  });

  /// 使用时长（Duration）
  Duration get todayDuration => Duration(seconds: todayDurationSeconds);

  /// 使用进度 (0.0 - 1.0)，仅当有规则时返回
  double? get progress {
    if (limitMinutes == null || limitMinutes! <= 0) return null;
    return (todayDurationSeconds / (limitMinutes! * 60)).clamp(0.0, 1.0);
  }

  /// 是否接近限制 (>= 90%)
  bool get isNearLimit {
    final p = progress;
    return p != null && p >= 0.9;
  }

  /// 是否已超限
  bool get isExceeded {
    final p = progress;
    return p != null && p >= 1.0;
  }

  /// 剩余时间（分钟）
  int? get remainingMinutes {
    if (limitMinutes == null) return null;
    final usedMinutes = (todayDurationSeconds / 60).ceil();
    final remaining = limitMinutes! - usedMinutes;
    return remaining > 0 ? remaining : 0;
  }

  /// 状态文案
  String get statusText {
    if (hasRule) {
      return '已设置：$limitMinutes分钟/天';
    }
    switch (limitSource) {
      case LimitSource.category:
        return '受${category.label}限制（$limitMinutes分钟）';
      case LimitSource.total:
        return '受总时间限制';
      case LimitSource.none:
        if (category == AppCategory.study) {
          return '学习类，无单独限制';
        }
        return '未设置限制';
      case LimitSource.singleApp:
        return '已设置：$limitMinutes分钟/天';
    }
  }

  AppUsageSummary copyWith({
    String? packageName,
    String? appName,
    AppCategory? category,
    int? todayDurationSeconds,
    int? limitMinutes,
    LimitSource? limitSource,
    bool? hasRule,
  }) {
    return AppUsageSummary(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      category: category ?? this.category,
      todayDurationSeconds: todayDurationSeconds ?? this.todayDurationSeconds,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      limitSource: limitSource ?? this.limitSource,
      hasRule: hasRule ?? this.hasRule,
    );
  }

  @override
  String toString() {
    return 'AppUsageSummary($packageName, ${todayDuration.inMinutes}min, limit: $limitMinutes min, source: $limitSource)';
  }
}
```

- [ ] **Step 2: Export in models.dart**

Add to `lib/shared/models/models.dart`:
```dart
export 'app_usage_summary.dart';
```

- [ ] **Step 3: Verify compilation**

Run: `cd qiaoqiao_companion && flutter analyze lib/shared/models/`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/shared/models/app_usage_summary.dart lib/shared/models/models.dart
git commit -m "feat: add AppUsageSummary model for app usage display"
```

---

### Task 1.3: AppUsageDao 新增 getTodayAggregated()

**Files:**
- Modify: `lib/core/database/daos/app_usage_dao.dart`

- [ ] **Step 1: Add getTodayAggregated method**

Add to `lib/core/database/daos/app_usage_dao.dart`:

```dart
  /// 获取指定日期的应用使用汇总（按包名聚合）
  Future<List<Map<String, dynamic>>> getAggregatedByDate(String date) async {
    final db = await _database.database;
    return await db.rawQuery('''
      SELECT
        package_name,
        app_name,
        category,
        SUM(duration) as total_duration
      FROM ${DatabaseConstants.tableAppUsageRecords}
      WHERE date = ?
      GROUP BY package_name
      ORDER BY total_duration DESC
    ''', [date]);
  }
```

- [ ] **Step 2: Verify compilation**

Run: `cd qiaoqiao_companion && flutter analyze lib/core/database/daos/`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/core/database/daos/app_usage_dao.dart
git commit -m "feat: add getAggregatedByDate method to AppUsageDao"
```

---

### Task 1.4: RuleDao 新增方法

**Files:**
- Modify: `lib/core/database/daos/rule_dao.dart`

- [ ] **Step 1: Add deleteByTypeAndTarget method**

Add to `lib/core/database/daos/rule_dao.dart`:

```dart
  /// 删除指定类型和目标的规则
  Future<int> deleteByTypeAndTarget(RuleType type, String? target) async {
    final db = await _database.database;
    if (target != null) {
      return await db.delete(
        DatabaseConstants.tableRules,
        where: 'rule_type = ? AND target = ?',
        whereArgs: [type.code, target],
      );
    } else {
      return await db.delete(
        DatabaseConstants.tableRules,
        where: 'rule_type = ? AND target IS NULL',
        whereArgs: [type.code],
      );
    }
  }

  /// 获取单个应用的规则
  Future<Rule?> getAppRule(String packageName) async {
    return await getByTypeAndTarget(RuleType.appSingle, packageName);
  }
```

- [ ] **Step 2: Verify compilation**

Run: `cd qiaoqiao_companion && flutter analyze lib/core/database/daos/`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/core/database/daos/rule_dao.dart
git commit -m "feat: add deleteByTypeAndTarget and getAppRule to RuleDao"
```

---

## Chunk 2: Provider Layer

### Task 2.1: appUsageListProvider

**Files:**
- Create: `lib/shared/providers/app_usage_list_provider.dart`
- Modify: `lib/shared/providers/providers.dart`

- [ ] **Step 1: Create appUsageListProvider**

```dart
// lib/shared/providers/app_usage_list_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';  // for firstOrNull
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/database/database_service.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/models/daily_stats.dart';  // for formatDate

/// 应用使用汇总列表
final appUsageListProvider =
    FutureProvider<List<AppUsageSummary>>((ref) async {
  final db = AppDatabase.instance;
  final appUsageDao = AppUsageDao(db);
  final ruleDao = RuleDao(db);
  final categoryDao = AppCategoryDao(db);

  final today = DailyStats.formatDate(DateTime.now());
  final isWeekend = _isWeekend(DateTime.now());

  // 1. 获取今日应用使用汇总
  final aggregatedData = await appUsageDao.getAggregatedByDate(today);

  // 2. 获取所有启用的规则
  final rules = await ruleDao.getEnabled();

  // 3. 构建汇总列表
  final List<AppUsageSummary> result = [];

  for (final data in aggregatedData) {
    final packageName = data['package_name'] as String;
    final appName = data['app_name'] as String? ?? packageName;
    final category = AppCategory.fromCode(data['category'] as String? ?? 'other');
    final totalDuration = data['total_duration'] as int;

    // 查找单应用规则
    final appRule = rules.where((r) =>
      r.ruleType == RuleType.appSingle &&
      r.target == packageName
    ).firstOrNull;

    // 查找分类规则
    final categoryRule = rules.where((r) =>
      r.ruleType == RuleType.appCategory &&
      r.target == category.code
    ).firstOrNull;

    // 查找总时间规则
    final totalRule = rules.where((r) =>
      r.ruleType == RuleType.totalTime
    ).firstOrNull;

    // 确定限制来源和限额
    int? limitMinutes;
    LimitSource limitSource;
    bool hasRule = false;

    if (appRule != null) {
      limitMinutes = isWeekend
        ? appRule.weekendLimitMinutes ?? appRule.weekdayLimitMinutes
        : appRule.weekdayLimitMinutes;
      limitSource = LimitSource.singleApp;
      hasRule = true;
    } else if (categoryRule != null) {
      limitMinutes = isWeekend
        ? categoryRule.weekendLimitMinutes ?? categoryRule.weekdayLimitMinutes
        : categoryRule.weekdayLimitMinutes;
      limitSource = LimitSource.category;
    } else if (totalRule != null) {
      limitMinutes = isWeekend
        ? totalRule.weekendLimitMinutes ?? totalRule.weekdayLimitMinutes
        : totalRule.weekdayLimitMinutes;
      limitSource = LimitSource.total;
    } else {
      limitMinutes = null;
      limitSource = LimitSource.none;
    }

    result.add(AppUsageSummary(
      packageName: packageName,
      appName: appName,
      category: category,
      todayDurationSeconds: totalDuration,
      limitMinutes: limitMinutes,
      limitSource: limitSource,
      hasRule: hasRule,
    ));
  }

  return result;
});

/// 今日总使用时间 Provider
final todayTotalUsageProvider = FutureProvider<int>((ref) async {
  final summaries = await ref.watch(appUsageListProvider.future);
  return summaries.fold(0, (sum, s) => sum + s.todayDurationSeconds);
});

/// 今日总限额 Provider
final todayTotalLimitProvider = FutureProvider<int?>((ref) async {
  final db = AppDatabase.instance;
  final ruleDao = RuleDao(db);
  final rules = await ruleDao.getEnabled();
  final totalRule = rules.where((r) => r.ruleType == RuleType.totalTime).firstOrNull;

  if (totalRule == null) return null;

  return _isWeekend(DateTime.now())
    ? totalRule.weekendLimitMinutes ?? totalRule.weekdayLimitMinutes
    : totalRule.weekdayLimitMinutes;
});

bool _isWeekend(DateTime date) {
  final weekday = date.weekday;
  return weekday == DateTime.saturday || weekday == DateTime.sunday;
}
```

- [ ] **Step 2: Export in providers.dart**

Add to `lib/shared/providers/providers.dart`:
```dart
export 'app_usage_list_provider.dart';
```

- [ ] **Step 3: Verify compilation**

Run: `cd qiaoqiao_companion && flutter analyze lib/shared/providers/`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/shared/providers/app_usage_list_provider.dart lib/shared/providers/providers.dart
git commit -m "feat: add appUsageListProvider for app usage display"
```

---

## Chunk 3: UI Components

### Task 3.1: AppUsageList 组件

**Files:**
- Create: `lib/features/home/presentation/widgets/app_usage_list.dart`

- [ ] **Step 1: Create AppUsageList widget**

```dart
// lib/features/home/presentation/widgets/app_usage_list.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/providers/providers.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/features/home/presentation/widgets/app_limit_dialog.dart';

/// 应用使用列表组件
class AppUsageList extends ConsumerWidget {
  final int maxItems;
  final bool showViewAll;

  const AppUsageList({
    super.key,
    this.maxItems = 5,
    this.showViewAll = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSummaries = ref.watch(appUsageListProvider);

    return asyncSummaries.when(
      data: (summaries) => _buildList(context, ref, summaries),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('加载失败: $error'),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<AppUsageSummary> summaries) {
    final displaySummaries = summaries.take(maxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '应用使用明细',
          style: AppTextStyles.body1.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        if (displaySummaries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              '今天还没有使用应用',
              style: AppTextStyles.body2,
              textAlign: TextAlign.center,
            ),
          )
        else
          ...displaySummaries.map((summary) => _AppUsageItem(
            summary: summary,
            onTap: () => _showLimitDialog(context, ref, summary),
          )),

        if (showViewAll && summaries.length > maxItems) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push('/app-list'),
              icon: const Icon(Icons.expand_more, size: 18),
              label: const Text('查看全部应用'),
            ),
          ),
        ],
      ],
    );
  }

  void _showLimitDialog(BuildContext context, WidgetRef ref, AppUsageSummary summary) {
    showDialog(
      context: context,
      builder: (context) => AppLimitDialog(summary: summary),
    );
  }
}

/// 单个应用使用项
class _AppUsageItem extends StatelessWidget {
  final AppUsageSummary summary;
  final VoidCallback onTap;

  const _AppUsageItem({
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            // 应用图标占位
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getCategoryColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _getCategoryEmoji(),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // 应用名称和使用时间
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.appName,
                    style: AppTextStyles.body1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary.statusText,
                    style: AppTextStyles.caption.copyWith(
                      color: _getStatusColor(),
                    ),
                  ),
                ],
              ),
            ),

            // 使用时间
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDuration(summary.todayDuration),
                  style: AppTextStyles.body2,
                ),
                if (summary.progress != null)
                  Text(
                    summary.remainingMinutes != null
                      ? '剩余 ${summary.remainingMinutes} 分钟'
                      : '',
                    style: AppTextStyles.caption.copyWith(
                      color: summary.isNearLimit
                        ? AppTheme.warningColor
                        : AppTheme.textHint,
                    ),
                  ),
              ],
            ),

            // 箭头
            const Icon(Icons.chevron_right, size: 20, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (summary.category) {
      case AppCategory.game:
        return AppTheme.gameColor;
      case AppCategory.video:
        return AppTheme.videoColor;
      case AppCategory.study:
        return AppTheme.studyColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _getCategoryEmoji() {
    switch (summary.category) {
      case AppCategory.game:
        return '🎮';
      case AppCategory.video:
        return '📺';
      case AppCategory.study:
        return '📚';
      case AppCategory.reading:
        return '📖';
      default:
        return '📱';
    }
  }

  Color _getStatusColor() {
    if (summary.isExceeded) return AppTheme.errorColor;
    if (summary.isNearLimit) return AppTheme.warningColor;
    return AppTheme.textHint;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 1) return '< 1分钟';
    if (minutes < 60) return '$minutes分钟';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '$hours小时';
    return '$hours小时$remainingMinutes分';
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd qiaoqiao_companion && flutter analyze lib/features/home/presentation/widgets/`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/widgets/app_usage_list.dart
git commit -m "feat: add AppUsageList widget for displaying app usage"
```

---

### Task 3.2: AppLimitDialog 对话框

**Files:**
- Create: `lib/features/home/presentation/widgets/app_limit_dialog.dart`

- [ ] **Step 1: Create AppLimitDialog widget**

```dart
// lib/features/home/presentation/widgets/app_limit_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/daos.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 时间限制设置对话框
class AppLimitDialog extends ConsumerStatefulWidget {
  final AppUsageSummary summary;

  const AppLimitDialog({
    super.key,
    required this.summary,
  });

  @override
  ConsumerState<AppLimitDialog> createState() => _AppLimitDialogState();
}

class _AppLimitDialogState extends ConsumerState<AppLimitDialog> {
  late TextEditingController _weekdayController;
  late TextEditingController _weekendController;
  bool _weekdayCustom = false;
  bool _weekendCustom = false;
  bool _isLoading = false;

  final List<int> _presetMinutes = [15, 30, 60];

  @override
  void initState() {
    super.initState();
    _weekdayController = TextEditingController();
    _weekendController = TextEditingController();
    _loadExistingRule();
  }

  Future<void> _loadExistingRule() async {
    final db = AppDatabase.instance;
    final ruleDao = RuleDao(db);
    final rule = await ruleDao.getAppRule(widget.summary.packageName);

    if (rule != null && mounted) {
      setState(() {
        if (rule.weekdayLimitMinutes != null) {
          _weekdayController.text = rule.weekdayLimitMinutes.toString();
          if (!_presetMinutes.contains(rule.weekdayLimitMinutes)) {
            _weekdayCustom = true;
          }
        }
        if (rule.weekendLimitMinutes != null) {
          _weekendController.text = rule.weekendLimitMinutes.toString();
          if (!_presetMinutes.contains(rule.weekendLimitMinutes)) {
            _weekendCustom = true;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _weekdayController.dispose();
    _weekendController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('设置「${widget.summary.appName}」时间限制'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 工作日限额
            _buildLimitSection(
              label: '工作日限额',
              controller: _weekdayController,
              isCustom: _weekdayCustom,
              onPresetSelected: (minutes) {
                setState(() {
                  _weekdayController.text = minutes.toString();
                  _weekdayCustom = false;
                });
              },
              onCustomToggled: (isCustom) {
                setState(() {
                  _weekdayCustom = isCustom;
                  if (isCustom && _weekdayController.text.isEmpty) {
                    _weekdayController.text = '30';
                  }
                });
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // 节假日限额
            _buildLimitSection(
              label: '节假日限额',
              controller: _weekendController,
              isCustom: _weekendCustom,
              onPresetSelected: (minutes) {
                setState(() {
                  _weekendController.text = minutes.toString();
                  _weekendCustom = false;
                });
              },
              onCustomToggled: (isCustom) {
                setState(() {
                  _weekendCustom = isCustom;
                  if (isCustom && _weekendController.text.isEmpty) {
                    _weekendController.text = '60';
                  }
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        // 清除限制按钮
        if (widget.summary.hasRule)
          TextButton(
            onPressed: _isLoading ? null : _showClearConfirmDialog,
            child: Text(
              '清除限制',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveRule,
          child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildLimitSection({
    required String label,
    required TextEditingController controller,
    required bool isCustom,
    required Function(int) onPresetSelected,
    required Function(bool) onCustomToggled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body1),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            ..._presetMinutes.map((minutes) => _PresetButton(
              label: minutes < 60 ? '${minutes}分' : '${minutes ~/ 60}小时',
              isSelected: !isCustom && controller.text == minutes.toString(),
              onTap: () => onPresetSelected(minutes),
            )),
            _PresetButton(
              label: '自定义',
              isSelected: isCustom,
              onTap: () => onCustomToggled(true),
            ),
          ],
        ),
        if (isCustom) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    border: OutlineInputBorder(),
                    suffixText: '分',
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _saveRule() async {
    final weekdayLimit = int.tryParse(_weekdayController.text);
    final weekendLimit = int.tryParse(_weekendController.text);

    if (weekdayLimit == null || weekendLimit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的时间')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = AppDatabase.instance;
      final ruleDao = RuleDao(db);

      // 检查是否已有规则
      final existingRule = await ruleDao.getAppRule(widget.summary.packageName);

      final rule = Rule(
        id: existingRule?.id,
        ruleType: RuleType.appSingle,
        target: widget.summary.packageName,
        weekdayLimitMinutes: weekdayLimit,
        weekendLimitMinutes: weekendLimit,
        enabled: true,
      );

      if (existingRule != null) {
        await ruleDao.update(rule);
      } else {
        await ruleDao.insert(rule);
      }

      // 刷新 Provider
      ref.invalidate(appUsageListProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除限制？'),
        content: Text(
          '清除后，该应用将受分类规则限制：\n'
          '• ${widget.summary.category.label}：${widget.summary.limitMinutes ?? 0}分钟/天',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _clearRule();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearRule() async {
    setState(() => _isLoading = true);

    try {
      final db = AppDatabase.instance;
      final ruleDao = RuleDao(db);

      await ruleDao.deleteByTypeAndTarget(
        RuleType.appSingle,
        widget.summary.packageName,
      );

      ref.invalidate(appUsageListProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('限制已清除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// 预设按钮
class _PresetButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.textHint,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd qiaoqiao_companion && flutter analyze lib/features/home/presentation/widgets/`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/widgets/app_limit_dialog.dart
git commit -m "feat: add AppLimitDialog for setting app time limits"
```

---

### Task 3.3: 修改首页使用新的应用列表组件

**Files:**
- Modify: `lib/features/home/presentation/home_page.dart`

- [ ] **Step 1: Update home_page.dart to use AppUsageList**

Replace the `_UsageProgressCard` section in `home_page.dart` with the new `AppUsageList` widget:

Find this section (approximately lines 61-68):
```dart
            // 今日使用情况
            _UsageProgressCard(
              totalUsage: usage.totalDuration,
              totalLimit: usage.totalLimit,
              gameUsage: usage.gameDuration,
              gameLimit: usage.gameLimit,
              videoUsage: usage.videoDuration,
              videoLimit: usage.videoLimit,
            ),
```

Replace with:
```dart
            // 今日使用情况
            _TodayUsageCard(),
            const SizedBox(height: AppSpacing.lg),
            AppUsageList(maxItems: 5),
```

- [ ] **Step 2: Add _TodayUsageCard widget**

Add the new `_TodayUsageCard` widget after the `_QuickActionButton` class:

```dart
/// 今日使用总览卡片
class _TodayUsageCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUsage = ref.watch(todayTotalUsageProvider);
    final asyncLimit = ref.watch(todayTotalLimitProvider);

    return asyncUsage.when(
      data: (totalSeconds) {
        final totalMinutes = totalSeconds ~/ 60;
        final limitMinutes = asyncLimit.valueOrNull ?? 120;
        final progress = (totalSeconds / (limitMinutes * 60)).clamp(0.0, 1.0);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日使用情况',
                  style: AppTextStyles.heading3,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '总计：$totalMinutes分钟 / $limitMinutes分钟',
                      style: AppTextStyles.body2,
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: AppTextStyles.body2.copyWith(
                        color: progress >= 0.9
                          ? AppTheme.warningColor
                          : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 0.9 ? AppTheme.warningColor : AppTheme.primaryColor,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('加载失败: $error'),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Add import for AppUsageList**

Add at the top of `home_page.dart`:
```dart
import 'package:qiaoqiao_companion/features/home/presentation/widgets/app_usage_list.dart';
```

- [ ] **Step 4: Verify compilation**

Run: `cd qiaoqiao_companion && flutter analyze lib/features/home/presentation/`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/home_page.dart
git commit -m "feat: update home page to use new AppUsageList widget"
```

---

## Chunk 4: App List Page

### Task 4.1: AppListPage 完整应用列表页面

**Files:**
- Create: `lib/features/app_list/presentation/app_list_page.dart`
- Modify: `lib/app/router.dart`

- [ ] **Step 1: Create app_list directory and page**

```dart
// lib/features/app_list/presentation/app_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/providers/providers.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/features/home/presentation/widgets/app_limit_dialog.dart';

/// 应用列表筛选模式
enum AppListFilter {
  all('全部'),
  withLimit('已设限制'),
  withoutLimit('未设限制');

  final String label;
  const AppListFilter(this.label);
}

/// 完整应用列表页面
class AppListPage extends ConsumerStatefulWidget {
  const AppListPage({super.key});

  @override
  ConsumerState<AppListPage> createState() => _AppListPageState();
}

class _AppListPageState extends ConsumerState<AppListPage> {
  AppListFilter _filter = AppListFilter.all;

  @override
  Widget build(BuildContext context) {
    final asyncSummaries = ref.watch(appUsageListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('应用使用情况'),
      ),
      body: asyncSummaries.when(
        data: (summaries) => _buildBody(summaries),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('加载失败: $error')),
      ),
    );
  }

  Widget _buildBody(List<AppUsageSummary> summaries) {
    final filteredSummaries = _filterSummaries(summaries);

    return Column(
      children: [
        // 总览卡片
        _buildOverviewCard(summaries),

        // 筛选标签
        _buildFilterTabs(),

        // 应用列表
        Expanded(
          child: filteredSummaries.isEmpty
              ? const Center(child: Text('没有符合条件的应用'))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filteredSummaries.length,
                  itemBuilder: (context, index) {
                    return _AppListItem(
                      summary: filteredSummaries[index],
                      onTap: () => _showLimitDialog(filteredSummaries[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(List<AppUsageSummary> summaries) {
    final totalSeconds = summaries.fold(0, (sum, s) => sum + s.todayDurationSeconds);
    final totalMinutes = totalSeconds ~/ 60;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppTheme.primaryLight.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('今日总计：', style: AppTextStyles.body1),
          Text('$totalMinutes 分钟', style: AppTextStyles.heading3),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: AppListFilter.values.map((filter) {
          final isSelected = _filter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Text(filter.label),
              selected: isSelected,
              onSelected: (_) => setState(() => _filter = filter),
              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryColor,
            ),
          );
        }).toList(),
      ),
    );
  }

  List<AppUsageSummary> _filterSummaries(List<AppUsageSummary> summaries) {
    switch (_filter) {
      case AppListFilter.withLimit:
        return summaries.where((s) => s.hasRule).toList();
      case AppListFilter.withoutLimit:
        return summaries.where((s) => !s.hasRule).toList();
      case AppListFilter.all:
        return summaries;
    }
  }

  void _showLimitDialog(AppUsageSummary summary) {
    showDialog(
      context: context,
      builder: (context) => AppLimitDialog(summary: summary),
    );
  }
}

/// 应用列表项
class _AppListItem extends StatelessWidget {
  final AppUsageSummary summary;
  final VoidCallback onTap;

  const _AppListItem({
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // 应用图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getCategoryColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(_getCategoryEmoji(), style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // 应用信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            summary.appName,
                            style: AppTextStyles.body1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (summary.isNearLimit && !summary.isExceeded)
                          const Icon(Icons.warning, size: 16, color: AppTheme.warningColor),
                        if (summary.isExceeded)
                          const Icon(Icons.block, size: 16, color: AppTheme.errorColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getLimitText(),
                      style: AppTextStyles.caption,
                    ),
                    if (summary.hasRule) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: summary.progress ?? 0,
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            summary.isExceeded
                              ? AppTheme.errorColor
                              : summary.isNearLimit
                                ? AppTheme.warningColor
                                : AppTheme.primaryColor,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 使用时间
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDuration(summary.todayDuration),
                    style: AppTextStyles.body2,
                  ),
                  if (summary.hasRule && summary.remainingMinutes != null)
                    Text(
                      '剩余 ${summary.remainingMinutes} 分钟',
                      style: AppTextStyles.caption.copyWith(
                        color: summary.isNearLimit ? AppTheme.warningColor : AppTheme.textHint,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (summary.category) {
      case AppCategory.game:
        return AppTheme.gameColor;
      case AppCategory.video:
        return AppTheme.videoColor;
      case AppCategory.study:
        return AppTheme.studyColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _getCategoryEmoji() {
    switch (summary.category) {
      case AppCategory.game:
        return '🎮';
      case AppCategory.video:
        return '📺';
      case AppCategory.study:
        return '📚';
      case AppCategory.reading:
        return '📖';
      default:
        return '📱';
    }
  }

  String _getLimitText() {
    if (summary.hasRule) {
      return '限制：${summary.limitMinutes}分钟/天';
    }
    return summary.statusText;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 1) return '< 1分钟';
    if (minutes < 60) return '$minutes分钟';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '$hours小时';
    return '$hours小时$remainingMinutes分';
  }
}
```

- [ ] **Step 2: Add route to router.dart**

Add to `lib/app/router.dart` in the routes list (after the loading route):

```dart
      // 应用列表页面
      GoRoute(
        path: '/app-list',
        name: 'app_list',
        builder: (context, state) => const AppListPage(),
      ),
```

Add import:
```dart
import 'package:qiaoqiao_companion/features/app_list/presentation/app_list_page.dart';
```

- [ ] **Step 3: Add to AppRoutes class**

Add to `lib/app/router.dart` in the `AppRoutes` class:
```dart
  static const String appList = '/app-list';
```

- [ ] **Step 4: Verify compilation**

Run: `cd qiaoqiao_companion && flutter analyze lib/`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/features/app_list/ lib/app/router.dart
git commit -m "feat: add AppListPage for full app usage view"
```

---

## Chunk 5: RuleCheckerService Update

### Task 5.1: 修改 RuleCheckerService 支持单应用规则

**Files:**
- Modify: `lib/core/services/rule_checker_service.dart`

- [ ] **Step 1: Read current RuleCheckerService implementation**

Run: `cd qiaoqiao_companion && cat lib/core/services/rule_checker_service.dart`

- [ ] **Step 2: Add single app rule check method**

Add to `RuleCheckerService`:

```dart
  /// 检查单个应用规则
  Future<AppUsageResult> _checkSingleAppLimit(
    Rule rule,
    String packageName,
    String date,
  ) async {
    final limitMinutes = rule.getLimitForDate(DateTime.now());
    if (limitMinutes == null || limitMinutes <= 0) {
      return AppUsageResult.allowed();
    }

    final usageRecords = await _appUsageDao.getByPackageAndDate(packageName, date);
    final totalSeconds = usageRecords.fold(0, (sum, r) => sum + r.durationSeconds);
    final usedMinutes = totalSeconds ~/ 60;
    final remainingMinutes = limitMinutes - usedMinutes;

    if (remainingMinutes <= 0) {
      return AppUsageResult.locked(
        reason: '「${_getAppName(packageName)}」的时间已用完',
        packageName: packageName,
        limitSource: LimitSource.singleApp,
      );
    } else if (remainingMinutes <= 5) {
      return AppUsageResult.warning(
        remainingMinutes: remainingMinutes,
        reason: '「${_getAppName(packageName)}」还剩 $remainingMinutes 分钟',
        packageName: packageName,
        limitSource: LimitSource.singleApp,
      );
    }

    return AppUsageResult.allowed();
  }

  String _getAppName(String packageName) {
    // 从缓存或数据库获取应用名称
    return packageName.split('.').last;
  }
```

- [ ] **Step 3: Update checkAppUsage to prioritize single app rules**

Modify the `checkAppUsage` method to check single app rules first:

```dart
  /// 检查应用使用是否超限
  Future<AppUsageResult> checkAppUsage(String packageName) async {
    final today = DailyStats.formatDate(DateTime.now());

    // 1. 优先检查单应用规则
    final appRule = await _ruleDao.getAppRule(packageName);
    if (appRule != null && appRule.enabled) {
      return await _checkSingleAppLimit(appRule, packageName, today);
    }

    // 2. 检查分类规则
    final category = await _getAppCategory(packageName);
    if (category != AppCategory.other) {
      final categoryRule = await _getCategoryRule(category);
      if (categoryRule != null && categoryRule.enabled) {
        return await _checkCategoryLimit(categoryRule, packageName, category, today);
      }
    }

    // 3. 检查总时间规则
    final totalRule = await _getTotalTimeRule();
    if (totalRule != null && totalRule.enabled) {
      return await _checkTotalTimeLimit(totalRule, today);
    }

    return AppUsageResult.allowed();
  }
```

- [ ] **Step 4: Verify compilation**

Run: `cd qiaoqiao_companion && flutter analyze lib/core/services/`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/rule_checker_service.dart
git commit -m "feat: add single app rule check to RuleCheckerService"
```

---

## Final Steps

### Task 6.1: Full integration test

- [ ] **Step 1: Run flutter analyze**

Run: `cd qiaoqiao_companion && flutter analyze`
Expected: No errors

- [ ] **Step 2: Run the app**

Run: `cd qiaoqiao_companion && flutter run`
Expected: App launches without errors

- [ ] **Step 3: Manual test checklist**

- [ ] 首页显示今日使用总览和 app 列表
- [ ] 点击 app 弹出设置对话框
- [ ] 预设按钮正常工作
- [ ] 自定义输入正常工作
- [ ] 保存规则成功
- [ ] 清除限制显示确认对话框
- [ ] "查看全部应用"跳转正常
- [ ] 筛选功能正常

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete single app usage display and rule setting feature"
```

---

## Summary

| Phase | Description | Files |
|-------|-------------|-------|
| Chunk 1 | Data Layer - Models and DAOs | 4 new/modified files |
| Chunk 2 | Provider Layer | 1 new file |
| Chunk 3 | UI Components | 2 new + 1 modified files |
| Chunk 4 | App List Page | 1 new + 1 modified files |
| Chunk 5 | RuleCheckerService | 1 modified file |

**Total: 6 new files, 5 modified files**

---

*Plan version: 1.0*
*Created: 2026-03-16*
