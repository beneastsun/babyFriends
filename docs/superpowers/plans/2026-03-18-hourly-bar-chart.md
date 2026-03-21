# 每日时段柱状图 实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将首页"每日时段使用情况"从网格方块改为横向柱状图，并修复自动刷新时的界面跳动问题

**Architecture:** 重写 `_TimelineGrid` 组件为横向24柱布局，修改 `HourlyTimelineNotifier.load()` 为静默刷新模式

**Tech Stack:** Flutter, Dart, Riverpod, Tooltip

**Spec:** `docs/superpowers/specs/2026-03-18-hourly-bar-chart-design.md`

---

## 文件结构

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/shared/providers/hourly_usage_provider.dart` | 修改 | 静默刷新逻辑 |
| `lib/features/home/presentation/widgets/daily_timeline_widget.dart` | 修改 | 重写柱状图组件 |

---

### Task 1: 修复自动刷新跳动问题

**Files:**
- Modify: `lib/shared/providers/hourly_usage_provider.dart:58-66`

- [ ] **Step 1: 修改 load() 方法为静默刷新**

将 `HourlyTimelineNotifier.load()` 改为不触发 loading 状态：

```dart
/// 加载数据（静默刷新）
Future<void> load() async {
  try {
    final timeline = await _hourlyDao.getTimelineByDate(_date);
    state = AsyncValue.data(timeline);
  } catch (e, stack) {
    // 只有在无数据时才显示错误，刷新失败保持旧数据
    if (state.isLoading || !state.hasValue) {
      state = AsyncValue.error(e, stack);
    }
    // 否则保持现有数据，不显示错误
  }
}
```

- [ ] **Step 2: 验证修改**

运行: `flutter analyze lib/shared/providers/hourly_usage_provider.dart`
预期: 无错误

---

### Task 2: 重写柱状图组件

**Files:**
- Modify: `lib/features/home/presentation/widgets/daily_timeline_widget.dart`

- [ ] **Step 1: 确认 getStatusForHour 方法存在**

运行: 检查 `lib/shared/models/hourly_usage_stats.dart:102-108`
确认 `HourlyTimeline.getStatusForHour(int hour)` 方法已存在：
```dart
HourUsageStatus getStatusForHour(int hour) {
  final seconds = hourlyTotals[hour] ?? 0;
  if (seconds <= 0) return HourUsageStatus.none;
  if (seconds < 300) return HourUsageStatus.light;      // <5分钟
  if (seconds < 900) return HourUsageStatus.moderate;   // <15分钟
  return HourUsageStatus.heavy;
}
```
预期: 方法已存在，无需修改

- [ ] **Step 2: 替换 _TimelineGrid 组件**

将 `_TimelineGrid` 从4行网格改为横向24柱布局：

```dart
/// 时间线柱状图
class _TimelineGrid extends StatelessWidget {
  final HourlyTimeline timeline;

  const _TimelineGrid({required this.timeline});

  @override
  Widget build(BuildContext context) {
    // 计算最大高度（像素）
    const maxBarHeight = 80.0;
    // 每小时3600秒 = 60分钟为100%
    const maxSeconds = 3600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 柱状图区域
        SizedBox(
          height: maxBarHeight + 8, // 额外空间给顶部数值
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              // 计算每个柱子的宽度：(总宽度 - 间距) / 24
              // 23个间距 × 2像素 = 46像素总间距
              const gapWidth = 2.0;
              final barWidth = (availableWidth - 23 * gapWidth) / 24;

              // 使用显式间距，避免 spaceBetween 造成的计算冲突
              final bars = List.generate(24, (hour) {
                final seconds = timeline.hourlyTotals[hour] ?? 0;
                final status = timeline.getStatusForHour(hour);

                // 计算柱子高度：最小4像素，最大80像素
                final barHeight = seconds > 0
                    ? ((seconds / maxSeconds).clamp(0.0, 1.0) * maxBarHeight)
                        .clamp(4.0, maxBarHeight)
                    : 4.0;

                return _HourBar(
                  hour: hour,
                  height: barHeight,
                  width: barWidth,
                  status: status,
                  seconds: seconds,
                );
              });

              // 使用 SizedBox 显式设置每个柱子之间的间距
              final children = <Widget>[];
              for (var i = 0; i < bars.length; i++) {
                children.add(bars[i]);
                if (i < bars.length - 1) {
                  children.add(const SizedBox(width: gapWidth));
                }
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: children,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // 时间轴标签（只显示0, 6, 12, 18, 23）
        const _TimeAxisLabels(),
      ],
    );
  }
}
```

- [ ] **Step 2: 创建 _HourBar 柱子组件**

删除旧的 `_HourRow` 和 `_HourBlock`，添加新的柱子组件：

```dart
/// 单个小时柱子
class _HourBar extends StatelessWidget {
  final int hour;
  final double height;
  final double width;
  final HourUsageStatus status;
  final int seconds;

  const _HourBar({
    required this.hour,
    required this.height,
    required this.width,
    required this.status,
    required this.seconds,
  });

  Color _getColor() {
    switch (status) {
      case HourUsageStatus.none:
        return AppTheme.textHint.withOpacity(0.15);
      case HourUsageStatus.light:
        return AppTheme.primaryColor.withOpacity(0.3);
      case HourUsageStatus.moderate:
        return AppTheme.warningColor.withOpacity(0.6);
      case HourUsageStatus.heavy:
        return AppTheme.errorColor.withOpacity(0.8);
    }
  }

  String _getTooltip() {
    final minutes = seconds ~/ 60;
    if (minutes <= 0) {
      return '$hour:00 - 未使用';
    } else {
      return '$hour:00 - $minutes分钟';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _getTooltip(),
      preferBelow: false,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _getColor(),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 创建时间轴标签组件**

```dart
/// 时间轴标签
class _TimeAxisLabels extends StatelessWidget {
  const _TimeAxisLabels();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 与柱状图同步：每个柱子宽度 + 间距
        final availableWidth = constraints.maxWidth;
        const gapWidth = 2.0;
        final barWidth = (availableWidth - 23 * gapWidth) / 24;

        return Row(
          children: _buildLabels(barWidth, gapWidth),
        );
      },
    );
  }

  List<Widget> _buildLabels(double barWidth, double gapWidth) {
    final labels = [0, 6, 12, 18, 23];
    final children = <Widget>[];

    for (var i = 0; i < 24; i++) {
      if (labels.contains(i)) {
        children.add(SizedBox(
          width: barWidth,
          child: Text(
            '$i',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppTheme.textHint,
            ),
          ),
        ));
      } else {
        children.add(SizedBox(width: barWidth));
      }
      if (i < 23) {
        children.add(SizedBox(width: gapWidth));
      }
    }

    return children;
  }
}
```

- [ ] **Step 4: 删除旧的不再使用的组件**

删除 `daily_timeline_widget.dart` 中第 115-219 行的以下组件：
- `_HourRow` 类（第 115-153 行）
- `_HourBlock` 类（第 156-219 行）

这些组件将被新的 `_HourBar` 替代。

- [ ] **Step 5: 验证修改**

运行: `flutter analyze lib/features/home/presentation/widgets/daily_timeline_widget.dart`
预期: 无错误

---

### Task 3: 集成测试

**Files:**
- 无新增文件

- [ ] **Step 1: 运行完整分析**

运行: `flutter analyze`
预期: 无错误

- [ ] **Step 2: 运行应用验证**

运行: `flutter run`
验证内容：
1. 首页"每日时段使用情况"显示为横向24柱布局
2. 柱子高度正确反映使用时长（60分钟为满格）
3. 点击刷新按钮后界面不跳动（不显示 loading spinner）
4. 等待30秒自动刷新，确认界面不跳动
5. **长按**柱子显示正确的 Tooltip（Android 平板使用长按触发）

- [ ] **Step 3: 提交更改**

```bash
git add lib/shared/providers/hourly_usage_provider.dart lib/features/home/presentation/widgets/daily_timeline_widget.dart docs/superpowers/specs/2026-03-18-hourly-bar-chart-design.md docs/superpowers/plans/2026-03-18-hourly-bar-chart.md
git commit -m "feat(home): 将每日时段使用情况改为横向柱状图布局，修复自动刷新跳动问题"
```

---

## 完成标准

- [ ] 横向24柱布局正确显示
- [ ] 柱子高度按60分钟为100%计算
- [ ] 长按柱子显示具体时长 Tooltip（移动端交互）
- [ ] 自动刷新时界面不跳动
- [ ] `flutter analyze` 无错误
