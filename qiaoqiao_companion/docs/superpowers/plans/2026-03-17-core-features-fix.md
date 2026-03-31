# 核心功能修复实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复三个核心功能问题：应用使用统计、今日使用总览、禁用时段锁定

**Architecture:**
1. 改进前台应用检测机制，使用 `UsageStatsManager.queryEvents()` 替代 `queryUsageStats()` 获取更精确的前台应用
2. 确保监控服务正确记录使用数据到数据库
3. 在检测到规则违规时调用 OverlayService 显示锁定界面

**Tech Stack:** Flutter, Dart, Kotlin, Android UsageStatsManager, SQLite

---

## 问题根因分析

### 问题1: 应用使用明细显示不正常
**根因:** `getCurrentForegroundApp()` 使用 `queryUsageStats()` 返回 `lastTimeUsed` 最大的应用，这不一定是当前前台应用。应该使用 `queryEvents()` 获取 ACTIVITY_RESUMED 事件。

**文件:** `UsageStatsChannel.kt:174-197`

### 问题2: 今日使用总览数据一直是0
**根因:** 依赖于问题1的修复。如果前台应用检测不准确，数据就不会被正确记录到 `daily_stats` 表。

**相关文件:** `usage_monitor_service.dart`, `daily_stats_dao.dart`

### 问题3: 禁用时段没有生效
**根因:** `_checkTimeBlockRule()` 只打印警告，没有调用 `OverlayService.showOverlay()` 显示锁定界面。

**文件:** `usage_monitor_service.dart:263-297`

---

## Chunk 1: 修复 Android 端前台应用检测

### Task 1.1: 改进 getCurrentForegroundApp 方法

**Files:**
- Modify: `android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/channels/UsageStatsChannel.kt:174-197`

- [ ] **Step 1: 重写 getCurrentForegroundApp 使用 queryEvents**

将以下代码替换原有的 `getCurrentForegroundApp()` 方法：

```kotlin
/**
 * 获取当前前台应用包名
 * 使用 UsageEvents 获取更精确的前台应用信息
 */
private fun getCurrentForegroundApp(): String? {
    if (!hasUsageStatsPermission(context)) {
        return null
    }

    val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE)
            as UsageStatsManager

    val endTime = System.currentTimeMillis()
    val startTime = endTime - 1000 * 60 * 5 // 最近5分钟

    val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
    var lastResumedPackage: String? = null
    var lastResumedTime: Long = 0

    while (usageEvents.hasNextEvent()) {
        val event = UsageEvents.Event()
        usageEvents.getNextEvent(event)

        if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
            if (event.timeStamp > lastResumedTime) {
                lastResumedTime = event.timeStamp
                lastResumedPackage = event.packageName
            }
        }
    }

    // 验证是否是最近的活跃应用（最近30秒内有活动）
    if (lastResumedPackage != null && (endTime - lastResumedTime) < 30000) {
        return lastResumedPackage
    }

    return null
}
```

- [ ] **Step 2: 添加调试日志**

在 `getCurrentForegroundApp()` 方法中添加日志输出：

```kotlin
// 在方法开始处添加
android.util.Log.d("UsageStatsChannel", "getCurrentForegroundApp called")

// 在返回前添加
android.util.Log.d("UsageStatsChannel", "Current foreground app: $lastResumedPackage, time: $lastResumedTime")
```

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/channels/UsageStatsChannel.kt
git commit -m "fix: 改进前台应用检测，使用 queryEvents 替代 queryUsageStats"
```

---

## Chunk 2: 修复监控服务数据记录

### Task 2.1: 改进 UsageMonitorService 轮询逻辑

**Files:**
- Modify: `lib/core/services/usage_monitor_service.dart:59-96`

- [ ] **Step 1: 添加调试日志到 _pollUsageStats**

在 `_pollUsageStats()` 方法中添加详细日志：

```dart
Future<void> _pollUsageStats() async {
  try {
    // 获取当前前台应用
    final currentApp = await UsageStatsService.getCurrentForegroundApp();
    print('[UsageMonitor] Polling - currentApp: $currentApp, lastApp: $_lastForegroundApp');

    if (currentApp != null && currentApp != _lastForegroundApp) {
      // 应用切换，记录上一个应用的使用时间
      if (_lastForegroundApp != null && _lastForegroundTime != null) {
        print('[UsageMonitor] App switch detected: $_lastForegroundApp -> $currentApp');
        await _recordUsage(
          _lastForegroundApp!,
          _lastForegroundTime!,
          DateTime.now(),
        );
      }

      _lastForegroundApp = currentApp;
      _lastForegroundTime = DateTime.now();
    }

    // 定期记录当前应用的使用时间
    if (currentApp != null && _lastForegroundTime != null) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastForegroundTime!);

      // 每隔一定时间记录一次
      if (elapsed.inSeconds >= monitorIntervalSeconds) {
        print('[UsageMonitor] Recording usage: $currentApp, duration: ${elapsed.inSeconds}s');
        await _recordUsage(currentApp, _lastForegroundTime!, now);
        _lastForegroundTime = now;
      }
    }

    // 检查规则
    await _checkRules();

  } catch (e) {
    print('[UsageMonitor] Error in _pollUsageStats: $e');
  }
}
```

- [ ] **Step 2: 添加日志到 _recordUsage**

在 `_recordUsage()` 方法中添加日志：

```dart
Future<void> _recordUsage(
  String packageName,
  DateTime startTime,
  DateTime endTime,
) async {
  final duration = endTime.difference(startTime);
  if (duration.inSeconds <= 0) return;

  print('[UsageMonitor] _recordUsage: $packageName, duration: ${duration.inSeconds}s');

  // 获取应用分类
  final category = await _getAppCategory(packageName);
  final appName = await _getAppName(packageName);
  final date = DailyStats.formatDate(startTime);

  // 创建使用记录
  final record = AppUsageRecord(
    packageName: packageName,
    appName: appName,
    category: category,
    startTime: startTime,
    endTime: endTime,
    durationSeconds: duration.inSeconds,
    date: date,
  );

  // 保存到数据库
  await _appUsageDao.insert(record);
  print('[UsageMonitor] Saved usage record to database');

  // 更新每日统计
  await _updateDailyStats(date, category, duration.inSeconds);
  print('[UsageMonitor] Updated daily stats for $date');
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/usage_monitor_service.dart
git commit -m "fix: 添加调试日志到监控服务"
```

### Task 2.2: 修复今日使用总览数据刷新

**Files:**
- Modify: `lib/shared/providers/today_usage_provider.dart`

- [ ] **Step 1: 添加定时刷新机制**

在 `TodayUsageNotifier` 中添加定时刷新：

```dart
Timer? _refreshTimer;

@override
void dispose() {
  _refreshTimer?.cancel();
  super.dispose();
}

/// 开始定时刷新（每30秒）
void startAutoRefresh() {
  _refreshTimer?.cancel();
  _refreshTimer = Timer.periodic(
    const Duration(seconds: 30),
    (_) => refresh(),
  );
}

/// 停止定时刷新
void stopAutoRefresh() {
  _refreshTimer?.cancel();
  _refreshTimer = null;
}
```

- [ ] **Step 2: 在初始化时启动自动刷新**

修改 `todayUsageProvider` 定义：

```dart
final todayUsageProvider =
    StateNotifierProvider<TodayUsageNotifier, TodayUsage>((ref) {
  final db = AppDatabase.instance;
  final notifier = TodayUsageNotifier(
    DailyStatsDao(db),
    AppUsageDao(db),
    RuleDao(db),
  );
  // 启动自动刷新
  notifier.startAutoRefresh();
  // 初始加载
  notifier.loadToday();
  return notifier;
});
```

- [ ] **Step 3: Commit**

```bash
git add lib/shared/providers/today_usage_provider.dart
git commit -m "fix: 添加今日使用数据定时刷新机制"
```

---

## Chunk 3: 实现禁用时段锁定功能

### Task 3.1: 创建 ReminderService

**Files:**
- Create: `lib/core/services/reminder_service.dart`

- [ ] **Step 1: 创建 ReminderService**

```dart
import 'package:qiaoqiao_companion/core/platform/overlay_service.dart';
import 'package:qiaoqiao_companion/core/services/rule_checker_service.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

/// 提醒服务
/// 负责在规则违规时显示提醒和锁定界面
class ReminderService {
  final RuleCheckerService _ruleChecker;

  ReminderService(this._ruleChecker);

  /// 检查应用使用并显示相应提醒
  Future<void> checkAndRemind(String packageName) async {
    final result = await _ruleChecker.checkAppUsage(packageName);

    if (!result.allowed) {
      await _showBlockOverlay(result.reason ?? '当前不能使用');
    } else if (result.remainingSeconds != null && result.remainingSeconds! <= 300) {
      // 5分钟内提醒
      final remainingMinutes = result.remainingSeconds! ~/ 60;
      await OverlayService.showOverlay(
        title: '快到时间啦~',
        message: '还有 $remainingMinutes 分钟，记得休息哦！',
        type: ReminderType.reminder,
      );
    }
  }

  /// 显示锁定界面
  Future<void> _showBlockOverlay(String reason) async {
    await OverlayService.showOverlay(
      title: '休息时间到',
      message: reason,
      type: ReminderType.lock,
    );
  }

  /// 显示禁止时段提醒
  Future<void> showForbiddenTimeReminder(String timeRange) async {
    await OverlayService.showOverlay(
      title: '现在是休息时间',
      message: '$timeRange 不能使用哦，巧巧在守护你~',
      type: ReminderType.lock,
    );
  }

  /// 隐藏提醒
  Future<void> hideReminder() async {
    await OverlayService.hideOverlay();
  }
}
```

- [ ] **Step 2: 添加 Provider**

```dart
/// 提醒服务 Provider
final reminderServiceProvider = Provider<ReminderService>((ref) {
  final ruleChecker = ref.watch(ruleCheckerServiceProvider);
  return ReminderService(ruleChecker);
});
```

- [ ] **Step 3: Commit**

```bash
git add lib/core/services/reminder_service.dart
git commit -m "feat: 创建提醒服务用于显示锁定界面"
```

### Task 3.2: 集成 ReminderService 到监控服务

**Files:**
- Modify: `lib/core/services/usage_monitor_service.dart`

- [ ] **Step 1: 添加 ReminderService 依赖**

修改 `UsageMonitorService` 构造函数：

```dart
import 'package:qiaoqiao_companion/core/services/reminder_service.dart';

class UsageMonitorService {
  final AppDatabase _database;
  final AppUsageDao _appUsageDao;
  final DailyStatsDao _dailyStatsDao;
  final RuleDao _ruleDao;
  final PointsDao _pointsDao;
  final ReminderService _reminderService;

  // ... 其他代码

  UsageMonitorService(this._database, this._reminderService)
      : _appUsageDao = AppUsageDao(_database),
        _dailyStatsDao = DailyStatsDao(_database),
        _ruleDao = RuleDao(_database),
        _pointsDao = PointsDao(_database);
```

- [ ] **Step 2: 修改 _checkTimeBlockRule 调用锁定**

```dart
/// 检查禁止时段规则
Future<void> _checkTimeBlockRule(Rule rule) async {
  if (rule.timeStart == null || rule.timeEnd == null) return;

  final now = DateTime.now();
  final currentTime =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  final start = rule.timeStart!;
  final end = rule.timeEnd!;

  bool isBlocked = false;

  // 处理跨天情况
  if (start.compareTo(end) > 0) {
    // 跨天（如 21:00-07:00）
    isBlocked = currentTime.compareTo(start) >= 0 || currentTime.compareTo(end) < 0;
  } else {
    // 同一天
    isBlocked = currentTime.compareTo(start) >= 0 && currentTime.compareTo(end) < 0;
  }

  // 检查是否只针对工作日
  if (isBlocked && rule.target == 'weekday') {
    final weekday = now.weekday;
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      isBlocked = false;
    }
  }

  if (isBlocked && _lastForegroundApp != null) {
    print('[UsageMonitor] Forbidden time detected! Blocking app: $_lastForegroundApp');
    // 显示锁定界面
    await _reminderService.showForbiddenTimeReminder('$start - $end');
  } else {
    // 如果不在禁用时段，隐藏锁定界面
    await _reminderService.hideReminder();
  }
}
```

- [ ] **Step 3: 修改 _checkTotalTimeRule 调用锁定**

```dart
/// 检查总时间规则
Future<void> _checkTotalTimeRule(Rule rule, DailyStats stats) async {
  final limitMinutes = rule.getLimitForDate(DateTime.now());
  if (limitMinutes == null) return;

  final limitSeconds = limitMinutes * 60;
  final remainingSeconds = limitSeconds - stats.totalDurationSeconds;

  // 提前5分钟提醒
  if (remainingSeconds <= 300 && remainingSeconds > 0) {
    final remainingMinutes = remainingSeconds ~/ 60;
    await OverlayService.showOverlay(
      title: '快到时间啦~',
      message: '还有 $remainingMinutes 分钟，记得休息哦！',
      type: ReminderType.reminder,
    );
  }

  // 时间到
  if (remainingSeconds <= 0) {
    await OverlayService.showOverlay(
      title: '今天的时间用完啦',
      message: '明天再来吧！巧巧会一直陪着你~',
      type: ReminderType.lock,
    );
  }
}
```

- [ ] **Step 4: 修改 _checkCategoryRule 调用锁定**

```dart
/// 检查分类规则
Future<void> _checkCategoryRule(Rule rule, DailyStats stats) async {
  final limitMinutes = rule.getLimitForDate(DateTime.now());
  if (limitMinutes == null) return;

  final category = rule.target ?? '';
  int usedSeconds;

  switch (category) {
    case 'game':
      usedSeconds = stats.gameDurationSeconds;
      break;
    case 'video':
      usedSeconds = stats.videoDurationSeconds;
      break;
    default:
      return;
  }

  final limitSeconds = limitMinutes * 60;
  final remainingSeconds = limitSeconds - usedSeconds;

  if (remainingSeconds <= 0) {
    final categoryLabel = category == 'game' ? '游戏' : '视频';
    await OverlayService.showOverlay(
      title: '今天的$categoryLabel时间用完啦',
      message: '明天再来吧！',
      type: ReminderType.lock,
    );
  }
}
```

- [ ] **Step 5: 更新 Provider**

```dart
/// 使用监控服务 Provider
final usageMonitorServiceProvider = Provider<UsageMonitorService>((ref) {
  final db = AppDatabase.instance;
  final reminderService = ref.watch(reminderServiceProvider);
  return UsageMonitorService(db, reminderService);
});
```

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/usage_monitor_service.dart lib/core/services/services.dart
git commit -m "feat: 集成提醒服务到监控服务，实现禁用时段锁定"
```

---

## Chunk 4: 验证和测试

### Task 4.1: 手动测试清单

- [ ] **Step 1: 测试前台应用检测**

1. 启动应用
2. 查看 logcat 中 `UsageStatsChannel` 的日志
3. 打开抖音精选，观察是否能检测到包名
4. 切换到其他应用，观察日志变化

- [ ] **Step 2: 测试使用统计记录**

1. 使用抖音精选约1分钟
2. 查看应用使用明细是否显示抖音精选
3. 查看今日使用总览是否有数据

- [ ] **Step 3: 测试禁用时段锁定**

1. 在家长模式中设置禁用时段（如当前时间前后5分钟）
2. 返回应用，尝试使用娱乐应用
3. 观察是否显示锁定界面

- [ ] **Step 4: 最终验证**

运行完整测试：

```bash
cd qiaoqiao_companion
flutter run --debug
```

---

## 预期结果

1. **应用使用明细**: 正确显示所有使用过的应用及其使用时间
2. **今日使用总览**: 实时更新总使用时间和剩余时间
3. **禁用时段**: 在禁用时段内显示锁定界面，阻止继续使用

---

## 风险和注意事项

1. **MIUI 权限问题**: MIUI 需要额外的自启动权限，确保用户已授予
2. **后台限制**: Android 后台限制可能影响监控服务运行，建议开启前台服务通知
3. **电池优化**: 提示用户将应用加入电池优化白名单
