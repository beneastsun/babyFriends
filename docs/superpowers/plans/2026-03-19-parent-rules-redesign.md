# 家长管理规则界面功能修改 实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构家长管理规则界面，支持多时间段设置、单独 app 管理、连续使用限制功能。

**Architecture:** 采用分层架构，新增 `monitored_apps`、`time_periods`、`continuous_usage_sessions` 三个数据库表，重构 `EditRulesPage` 为三 Tab 布局，通过 `RuleCheckerService` 实现统一的规则检查逻辑。

**Tech Stack:** Flutter + Dart + Riverpod + SQLite (sqflite)

**工作目录:** `qiaoqiao_companion/` - 所有文件路径相对于此目录

---

## 前置准备

- [ ] **Step 1: 进入工作目录并验证结构**

```bash
cd qiaoqiao_companion
mkdir -p lib/features/parent_mode/presentation/widgets
ls lib/core/theme/app_theme.dart  # 确认主题文件存在
```

---

## 文件结构

### 数据层
| 文件 | 操作 | 职责 |
|------|------|------|
| `lib/shared/models/monitored_app.dart` | 新建 | 被监控 app 数据模型 |
| `lib/shared/models/time_period.dart` | 新建 | 时间段数据模型 |
| `lib/shared/models/continuous_session.dart` | 新建 | 连续使用会话数据模型 |
| `lib/core/database/daos/monitored_app_dao.dart` | 新建 | 被监控 app 数据访问 |
| `lib/core/database/daos/time_period_dao.dart` | 新建 | 时间段数据访问 |
| `lib/core/database/daos/continuous_session_dao.dart` | 新建 | 会话数据访问 |
| `lib/core/database/app_database.dart` | 修改 | 添加新表和 v2→v3 迁移 |
| `lib/shared/providers/monitored_apps_provider.dart` | 新建 | 被监控 app 状态管理 |
| `lib/shared/providers/time_periods_provider.dart` | 新建 | 时间段状态管理 |
| `lib/shared/providers/continuous_usage_provider.dart` | 新建 | 连续使用状态管理 |

### 服务层
| 文件 | 操作 | 职责 |
|------|------|------|
| `lib/core/services/continuous_usage_service.dart` | 新建 | 连续使用监控服务 |
| `lib/core/services/rule_checker_service.dart` | 修改 | 重构规则检查逻辑 |
| `lib/core/services/app_discovery_service.dart` | 新建 | 发现已安装应用 |

### UI 层
| 文件 | 操作 | 职责 |
|------|------|------|
| `lib/features/parent_mode/presentation/edit_rules_page.dart` | 重构 | Tab 布局主页面 |
| `lib/features/parent_mode/presentation/time_periods_tab.dart` | 新建 | 时间段设置 Tab |
| `lib/features/parent_mode/presentation/app_management_tab.dart` | 新建 | 应用管理 Tab |
| `lib/features/parent_mode/presentation/continuous_usage_tab.dart` | 新建 | 连续使用 Tab |
| `lib/features/parent_mode/presentation/app_selection_page.dart` | 新建 | 应用选择页面 |
| `lib/features/parent_mode/presentation/widgets/time_period_card.dart` | 新建 | 时间段卡片组件 |
| `lib/features/parent_mode/presentation/widgets/monitored_app_card.dart` | 新建 | 被监控 app 卡片组件 |
| `lib/features/parent_mode/presentation/widgets/continuous_usage_reminder.dart` | 新建 | 连续使用提醒弹窗 |

---

## Phase 1: 数据层

### Task 1: 创建 MonitoredApp 数据模型

**Files:**
- Create: `lib/shared/models/monitored_app.dart`
- Modify: `lib/shared/models/models.dart`

- [ ] **Step 1: 创建 MonitoredApp 模型类**

```dart
// lib/shared/models/monitored_app.dart

/// 被监控的应用
class MonitoredApp {
  final String packageName;
  final String? appName;
  final int? dailyLimitMinutes;  // NULL 表示无限制
  final String? category;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MonitoredApp({
    required this.packageName,
    this.appName,
    this.dailyLimitMinutes,
    this.category,
    this.enabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MonitoredApp.fromMap(Map<String, dynamic> map) {
    return MonitoredApp(
      packageName: map['package_name'] as String,
      appName: map['app_name'] as String?,
      dailyLimitMinutes: map['daily_limit_minutes'] as int?,
      category: map['category'] as String?,
      enabled: (map['enabled'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'package_name': packageName,
      'app_name': appName,
      'daily_limit_minutes': dailyLimitMinutes,
      'category': category,
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  MonitoredApp copyWith({
    String? packageName,
    String? appName,
    int? dailyLimitMinutes,
    bool? clearDailyLimit,
    String? category,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonitoredApp(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      dailyLimitMinutes: clearDailyLimit == true ? null : (dailyLimitMinutes ?? this.dailyLimitMinutes),
      category: category ?? this.category,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'MonitoredApp($packageName, limit: $dailyLimitMinutes min)';
}
```

- [ ] **Step 2: 在 models.dart 中导出**

```dart
// 在 lib/shared/models/models.dart 中添加
export 'monitored_app.dart';
```

- [ ] **Step 3: 提交**

```bash
git add lib/shared/models/monitored_app.dart lib/shared/models/models.dart
git commit -m "feat(data): add MonitoredApp model"
```

---

### Task 2: 创建 TimePeriod 数据模型

**Files:**
- Create: `lib/shared/models/time_period.dart`

- [ ] **Step 1: 创建 TimePeriod 模型类**

```dart
// lib/shared/models/time_period.dart

/// 时间段模式
enum TimePeriodMode {
  blocked('blocked', '禁用时段'),
  allowed('allowed', '开放时段');

  final String code;
  final String label;
  const TimePeriodMode(this.code, this.label);

  static TimePeriodMode fromCode(String code) {
    return TimePeriodMode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => TimePeriodMode.blocked,
    );
  }
}

/// 时间段
class TimePeriod {
  final int? id;
  final TimePeriodMode mode;
  final String timeStart;  // "HH:mm"
  final String timeEnd;    // "HH:mm"
  final List<int> days;    // 1=周一, 7=周日
  final bool enabled;
  final DateTime createdAt;

  const TimePeriod({
    this.id,
    required this.mode,
    required this.timeStart,
    required this.timeEnd,
    required this.days,
    this.enabled = true,
    required this.createdAt,
  });

  factory TimePeriod.fromMap(Map<String, dynamic> map) {
    final daysStr = map['days'] as String? ?? '1,2,3,4,5,6,7';
    final daysList = daysStr.split(',').map(int.parse).toList();

    return TimePeriod(
      id: map['id'] as int?,
      mode: TimePeriodMode.fromCode(map['mode'] as String? ?? 'blocked'),
      timeStart: map['time_start'] as String,
      timeEnd: map['time_end'] as String,
      days: daysList,
      enabled: (map['enabled'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'mode': mode.code,
      'time_start': timeStart,
      'time_end': timeEnd,
      'days': days.join(','),
      'enabled': enabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// 检查是否跨天
  bool get isCrossDay => timeStart.compareTo(timeEnd) > 0;

  /// 检查指定时间是否在时间段内
  bool containsTime(String currentTime) {
    if (isCrossDay) {
      // 跨天：当前时间 >= start 或 < end
      return currentTime.compareTo(timeStart) >= 0 ||
             currentTime.compareTo(timeEnd) < 0;
    } else {
      // 同一天：当前时间 >= start 且 < end
      return currentTime.compareTo(timeStart) >= 0 &&
             currentTime.compareTo(timeEnd) < 0;
    }
  }

  /// 检查指定日期是否适用
  bool appliesToWeekday(int weekday) {
    return days.contains(weekday);
  }

  TimePeriod copyWith({
    int? id,
    TimePeriodMode? mode,
    String? timeStart,
    String? timeEnd,
    List<int>? days,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return TimePeriod(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      timeStart: timeStart ?? this.timeStart,
      timeEnd: timeEnd ?? this.timeEnd,
      days: days ?? this.days,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'TimePeriod($timeStart-$timeEnd, mode: $mode, days: $days)';
}
```

- [ ] **Step 2: 在 models.dart 中导出**

```dart
// 在 lib/shared/models/models.dart 中添加
export 'time_period.dart';
```

- [ ] **Step 3: 提交**

```bash
git add lib/shared/models/time_period.dart lib/shared/models/models.dart
git commit -m "feat(data): add TimePeriod model"
```

---

### Task 3: 创建 ContinuousSession 数据模型

**Files:**
- Create: `lib/shared/models/continuous_session.dart`

- [ ] **Step 1: 创建 ContinuousSession 模型类**

```dart
// lib/shared/models/continuous_session.dart
import 'dart:convert';

/// 连续使用会话
class ContinuousSession {
  final int? id;
  final String sessionDate;           // "YYYY-MM-DD"
  final DateTime startTime;
  final int totalDurationSeconds;
  final DateTime? lastActivityTime;
  final DateTime? restEndTime;        // 强制休息结束时间
  final Set<String> alertsShown;      // 已显示的提醒级别
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContinuousSession({
    this.id,
    required this.sessionDate,
    required this.startTime,
    this.totalDurationSeconds = 0,
    this.lastActivityTime,
    this.restEndTime,
    this.alertsShown = const {},
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContinuousSession.fromMap(Map<String, dynamic> map) {
    final alertsStr = map['alerts_shown'] as String?;
    Set<String> alerts = {};
    if (alertsStr != null && alertsStr.isNotEmpty) {
      final list = jsonDecode(alertsStr) as List;
      alerts = list.map((e) => e.toString()).toSet();
    }

    return ContinuousSession(
      id: map['id'] as int?,
      sessionDate: map['session_date'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      totalDurationSeconds: map['total_duration_seconds'] as int? ?? 0,
      lastActivityTime: map['last_activity_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_activity_time'] as int)
          : null,
      restEndTime: map['rest_end_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['rest_end_time'] as int)
          : null,
      alertsShown: alerts,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_date': sessionDate,
      'start_time': startTime.millisecondsSinceEpoch,
      'total_duration_seconds': totalDurationSeconds,
      'last_activity_time': lastActivityTime?.millisecondsSinceEpoch,
      'rest_end_time': restEndTime?.millisecondsSinceEpoch,
      'alerts_shown': alertsShown.isEmpty ? null : jsonEncode(alertsShown.toList()),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// 是否处于强制休息中
  bool get isInRest {
    if (restEndTime == null) return false;
    return restEndTime!.isAfter(DateTime.now());
  }

  /// 剩余休息时间（秒）
  int? get remainingRestSeconds {
    if (restEndTime == null) return null;
    final remaining = restEndTime!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  ContinuousSession copyWith({
    int? id,
    String? sessionDate,
    DateTime? startTime,
    int? totalDurationSeconds,
    DateTime? lastActivityTime,
    DateTime? restEndTime,
    bool? clearRestEndTime,
    Set<String>? alertsShown,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContinuousSession(
      id: id ?? this.id,
      sessionDate: sessionDate ?? this.sessionDate,
      startTime: startTime ?? this.startTime,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      lastActivityTime: lastActivityTime ?? this.lastActivityTime,
      restEndTime: clearRestEndTime == true ? null : (restEndTime ?? this.restEndTime),
      alertsShown: alertsShown ?? this.alertsShown,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ContinuousSession(date: $sessionDate, duration: ${totalDurationSeconds}s)';
}
```

- [ ] **Step 2: 在 models.dart 中导出**

```dart
// 在 lib/shared/models/models.dart 中添加
export 'continuous_session.dart';
```

- [ ] **Step 3: 提交**

```bash
git add lib/shared/models/continuous_session.dart lib/shared/models/models.dart
git commit -m "feat(data): add ContinuousSession model"
```

---

### Task 4: 创建 MonitoredAppDao

**Files:**
- Create: `lib/core/database/daos/monitored_app_dao.dart`

- [ ] **Step 1: 创建 MonitoredAppDao**

```dart
// lib/core/database/daos/monitored_app_dao.dart
import 'package:sqflite/sqflite.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

class MonitoredAppDao {
  final Database _db;
  static const String _table = 'monitored_apps';

  MonitoredAppDao(this._db);

  /// 获取所有被监控的 app
  Future<List<MonitoredApp>> getAll() async {
    final maps = await _db.query(_table, orderBy: 'app_name');
    return maps.map(MonitoredApp.fromMap).toList();
  }

  /// 获取所有启用的被监控 app
  Future<List<MonitoredApp>> getEnabled() async {
    final maps = await _db.query(
      _table,
      where: 'enabled = ?',
      whereArgs: [1],
      orderBy: 'app_name',
    );
    return maps.map(MonitoredApp.fromMap).toList();
  }

  /// 根据 package name 获取
  Future<MonitoredApp?> getByPackageName(String packageName) async {
    final maps = await _db.query(
      _table,
      where: 'package_name = ?',
      whereArgs: [packageName],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return MonitoredApp.fromMap(maps.first);
  }

  /// 检查 package name 是否被监控
  Future<bool> isMonitored(String packageName) async {
    final maps = await _db.query(
      _table,
      where: 'package_name = ? AND enabled = ?',
      whereArgs: [packageName, 1],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// 插入
  Future<void> insert(MonitoredApp app) async {
    await _db.insert(_table, app.toMap());
  }

  /// 批量插入
  Future<void> insertAll(List<MonitoredApp> apps) async {
    final batch = _db.batch();
    for (final app in apps) {
      batch.insert(_table, app.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// 更新
  Future<void> update(MonitoredApp app) async {
    await _db.update(
      _table,
      app.toMap(),
      where: 'package_name = ?',
      whereArgs: [app.packageName],
    );
  }

  /// 删除
  Future<void> delete(String packageName) async {
    await _db.delete(
      _table,
      where: 'package_name = ?',
      whereArgs: [packageName],
    );
  }

  /// 清空所有
  Future<void> deleteAll() async {
    await _db.delete(_table);
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/core/database/daos/monitored_app_dao.dart
git commit -m "feat(data): add MonitoredAppDao"
```

---

### Task 5: 创建 TimePeriodDao

**Files:**
- Create: `lib/core/database/daos/time_period_dao.dart`

- [ ] **Step 1: 创建 TimePeriodDao**

```dart
// lib/core/database/daos/time_period_dao.dart
import 'package:sqflite/sqflite.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

class TimePeriodDao {
  final Database _db;
  static const String _table = 'time_periods';

  TimePeriodDao(this._db);

  /// 获取所有时间段
  Future<List<TimePeriod>> getAll() async {
    final maps = await _db.query(_table, orderBy: 'time_start');
    return maps.map(TimePeriod.fromMap).toList();
  }

  /// 获取所有启用的时间段
  Future<List<TimePeriod>> getEnabled() async {
    final maps = await _db.query(
      _table,
      where: 'enabled = ?',
      whereArgs: [1],
      orderBy: 'time_start',
    );
    return maps.map(TimePeriod.fromMap).toList();
  }

  /// 获取指定模式的时间段
  Future<List<TimePeriod>> getByMode(TimePeriodMode mode) async {
    final maps = await _db.query(
      _table,
      where: 'mode = ? AND enabled = ?',
      whereArgs: [mode.code, 1],
      orderBy: 'time_start',
    );
    return maps.map(TimePeriod.fromMap).toList();
  }

  /// 根据 ID 获取
  Future<TimePeriod?> getById(int id) async {
    final maps = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TimePeriod.fromMap(maps.first);
  }

  /// 插入
  Future<int> insert(TimePeriod period) async {
    return await _db.insert(_table, period.toMap());
  }

  /// 更新
  Future<void> update(TimePeriod period) async {
    await _db.update(
      _table,
      period.toMap(),
      where: 'id = ?',
      whereArgs: [period.id],
    );
  }

  /// 删除
  Future<void> delete(int id) async {
    await _db.delete(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清空所有
  Future<void> deleteAll() async {
    await _db.delete(_table);
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/core/database/daos/time_period_dao.dart
git commit -m "feat(data): add TimePeriodDao"
```

---

### Task 6: 创建 ContinuousSessionDao

**Files:**
- Create: `lib/core/database/daos/continuous_session_dao.dart`

- [ ] **Step 1: 创建 ContinuousSessionDao**

```dart
// lib/core/database/daos/continuous_session_dao.dart
import 'package:sqflite/sqflite.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

class ContinuousSessionDao {
  final Database _db;
  static const String _table = 'continuous_usage_sessions';

  ContinuousSessionDao(this._db);

  /// 获取指定日期的活跃会话
  Future<ContinuousSession?> getActiveSession(String date) async {
    final maps = await _db.query(
      _table,
      where: 'session_date = ? AND is_active = ?',
      whereArgs: [date, 1],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ContinuousSession.fromMap(maps.first);
  }

  /// 获取当前正在休息的会话
  Future<ContinuousSession?> getRestingSession(String date) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maps = await _db.query(
      _table,
      where: 'session_date = ? AND rest_end_time > ?',
      whereArgs: [date, now],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ContinuousSession.fromMap(maps.first);
  }

  /// 插入新会话
  Future<int> insert(ContinuousSession session) async {
    return await _db.insert(_table, session.toMap());
  }

  /// 更新会话
  Future<void> update(ContinuousSession session) async {
    await _db.update(
      _table,
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// 停用会话
  Future<void> deactivate(int id) async {
    await _db.update(
      _table,
      {'is_active': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清除指定日期之前的旧会话
  Future<void> cleanupOldSessions(String beforeDate) async {
    await _db.delete(
      _table,
      where: 'session_date < ?',
      whereArgs: [beforeDate],
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/core/database/daos/continuous_session_dao.dart
git commit -m "feat(data): add ContinuousSessionDao"
```

---

### Task 7: 更新数据库迁移

**Files:**
- Modify: `lib/core/database/app_database.dart`
- Modify: `lib/core/constants/database_constants.dart`

- [ ] **Step 1: 更新数据库版本号**

```dart
// 在 lib/core/constants/database_constants.dart 中修改
static const int databaseVersion = 3;  // 从 2 改为 3
```

- [ ] **Step 2: 在 app_database.dart 中添加 v3 迁移**

在 `_onCreate` 方法中添加新表的创建语句（确保新安装也能创建所有表），在 `_onUpgrade` 中添加迁移逻辑。参考规格文档第 6.2 节的完整迁移代码。

- [ ] **Step 3: 验证迁移**

```bash
# 运行应用，检查数据库是否正确创建
flutter run
# 检查日志确认迁移成功
```

- [ ] **Step 4: 提交**

```bash
git add lib/core/database/app_database.dart lib/core/constants/database_constants.dart
git commit -m "feat(data): add v3 migration for monitored_apps, time_periods, continuous_sessions tables"
```

---

### Task 8: 创建 MonitoredAppsProvider

**Files:**
- Create: `lib/shared/providers/monitored_apps_provider.dart`

- [ ] **Step 1: 创建 MonitoredAppsProvider**

```dart
// lib/shared/providers/monitored_apps_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/monitored_app_dao.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

class MonitoredAppsState {
  final List<MonitoredApp> allApps;
  final List<MonitoredApp> enabledApps;
  final Set<String> monitoredPackageNames;

  const MonitoredAppsState({
    this.allApps = const [],
    this.enabledApps = const [],
    this.monitoredPackageNames = const {},
  });

  MonitoredAppsState copyWith({
    List<MonitoredApp>? allApps,
    List<MonitoredApp>? enabledApps,
  }) {
    final all = allApps ?? this.allApps;
    final enabled = enabledApps ?? all.where((a) => a.enabled).toList();
    return MonitoredAppsState(
      allApps: all,
      enabledApps: enabled,
      monitoredPackageNames: enabled.map((a) => a.packageName).toSet(),
    );
  }

  bool isMonitored(String packageName) => monitoredPackageNames.contains(packageName);
}

class MonitoredAppsNotifier extends StateNotifier<MonitoredAppsState> {
  final MonitoredAppDao _dao;

  MonitoredAppsNotifier(this._dao) : super(const MonitoredAppsState());

  Future<void> load() async {
    final allApps = await _dao.getAll();
    state = state.copyWith(allApps: allApps);
  }

  Future<void> addApp(MonitoredApp app) async {
    await _dao.insert(app);
    await load();
  }

  Future<void> addApps(List<MonitoredApp> apps) async {
    await _dao.insertAll(apps);
    await load();
  }

  Future<void> updateApp(MonitoredApp app) async {
    await _dao.update(app);
    await load();
  }

  Future<void> removeApp(String packageName) async {
    await _dao.delete(packageName);
    await load();
  }

  Future<void> toggleEnabled(String packageName) async {
    final app = await _dao.getByPackageName(packageName);
    if (app != null) {
      await _dao.update(app.copyWith(enabled: !app.enabled));
      await load();
    }
  }

  Future<void> refresh() async {
    await load();
  }
}

final monitoredAppsProvider =
    StateNotifierProvider<MonitoredAppsNotifier, MonitoredAppsState>((ref) {
  final db = AppDatabase.instance;
  return MonitoredAppsNotifier(MonitoredAppDao(db));
});
```

- [ ] **Step 2: 提交**

```bash
git add lib/shared/providers/monitored_apps_provider.dart
git commit -m "feat(data): add MonitoredAppsProvider"
```

---

### Task 9: 创建 TimePeriodsProvider

**Files:**
- Create: `lib/shared/providers/time_periods_provider.dart`

- [ ] **Step 1: 创建 TimePeriodsProvider**

```dart
// lib/shared/providers/time_periods_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/time_period_dao.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';

class TimePeriodsState {
  final List<TimePeriod> allPeriods;
  final List<TimePeriod> enabledPeriods;
  final TimePeriodMode currentMode;

  const TimePeriodsState({
    this.allPeriods = const [],
    this.enabledPeriods = const [],
    this.currentMode = TimePeriodMode.blocked,
  });

  TimePeriodsState copyWith({
    List<TimePeriod>? allPeriods,
    List<TimePeriod>? enabledPeriods,
    TimePeriodMode? currentMode,
  }) {
    final all = allPeriods ?? this.allPeriods;
    final enabled = enabledPeriods ?? all.where((p) => p.enabled).toList();
    return TimePeriodsState(
      allPeriods: all,
      enabledPeriods: enabled,
      currentMode: currentMode ?? this.currentMode,
    );
  }

  List<TimePeriod> get periodsForCurrentMode =>
      enabledPeriods.where((p) => p.mode == currentMode).toList();
}

class TimePeriodsNotifier extends StateNotifier<TimePeriodsState> {
  final TimePeriodDao _dao;

  TimePeriodsNotifier(this._dao) : super(const TimePeriodsState());

  Future<void> load() async {
    final allPeriods = await _dao.getAll();
    state = state.copyWith(allPeriods: allPeriods);
  }

  Future<void> setMode(TimePeriodMode mode) async {
    state = state.copyWith(currentMode: mode);
  }

  Future<void> addPeriod(TimePeriod period) async {
    await _dao.insert(period);
    await load();
  }

  Future<void> updatePeriod(TimePeriod period) async {
    await _dao.update(period);
    await load();
  }

  Future<void> removePeriod(int id) async {
    await _dao.delete(id);
    await load();
  }

  Future<void> toggleEnabled(int id) async {
    final period = await _dao.getById(id);
    if (period != null) {
      await _dao.update(period.copyWith(enabled: !period.enabled));
      await load();
    }
  }

  Future<void> refresh() async {
    await load();
  }
}

final timePeriodsProvider =
    StateNotifierProvider<TimePeriodsNotifier, TimePeriodsState>((ref) {
  final db = AppDatabase.instance;
  return TimePeriodsNotifier(TimePeriodDao(db));
});
```

- [ ] **Step 2: 提交**

```bash
git add lib/shared/providers/time_periods_provider.dart
git commit -m "feat(data): add TimePeriodsProvider"
```

---

### Task 10: 创建 ContinuousUsageProvider

**Files:**
- Create: `lib/shared/providers/continuous_usage_provider.dart`

- [ ] **Step 1: 创建 ContinuousUsageProvider**

```dart
// lib/shared/providers/continuous_usage_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ContinuousUsageSettings {
  final bool enabled;
  final int limitMinutes;
  final int restMinutes;

  const ContinuousUsageSettings({
    this.enabled = false,
    this.limitMinutes = 30,
    this.restMinutes = 10,
  });

  ContinuousUsageSettings copyWith({
    bool? enabled,
    int? limitMinutes,
    int? restMinutes,
  }) {
    return ContinuousUsageSettings(
      enabled: enabled ?? this.enabled,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      restMinutes: restMinutes ?? this.restMinutes,
    );
  }
}

class ContinuousUsageSettingsNotifier extends StateNotifier<ContinuousUsageSettings> {
  static const _keyEnabled = 'continuous_usage_limit_enabled';
  static const _keyLimitMinutes = 'continuous_usage_limit_minutes';
  static const _keyRestMinutes = 'continuous_rest_minutes';

  ContinuousUsageSettingsNotifier() : super(const ContinuousUsageSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ContinuousUsageSettings(
      enabled: prefs.getBool(_keyEnabled) ?? false,
      limitMinutes: prefs.getInt(_keyLimitMinutes) ?? 30,
      restMinutes: prefs.getInt(_keyRestMinutes) ?? 10,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    state = state.copyWith(enabled: enabled);
  }

  Future<void> setLimitMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLimitMinutes, minutes);
    state = state.copyWith(limitMinutes: minutes);
  }

  Future<void> setRestMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRestMinutes, minutes);
    state = state.copyWith(restMinutes: minutes);
  }
}

final continuousUsageSettingsProvider =
    StateNotifierProvider<ContinuousUsageSettingsNotifier, ContinuousUsageSettings>((ref) {
  return ContinuousUsageSettingsNotifier();
});
```

- [ ] **Step 2: 提交**

```bash
git add lib/shared/providers/continuous_usage_provider.dart
git commit -m "feat(data): add ContinuousUsageProvider for settings"
```

---

## Phase 2: 服务层

### Task 11: 创建 AppDiscoveryService

**Files:**
- Create: `lib/core/services/app_discovery_service.dart`

- [ ] **Step 1: 创建 AppDiscoveryService**

```dart
// lib/core/services/app_discovery_service.dart
import 'package:flutter/services.dart';

/// 已安装应用信息
class InstalledApp {
  final String packageName;
  final String appName;
  final String? category;

  const InstalledApp({
    required this.packageName,
    required this.appName,
    this.category,
  });
}

/// 应用发现服务 - 获取设备上已安装的应用列表
class AppDiscoveryService {
  static const _channel = MethodChannel('com.qiaoqiao.companion/app_discovery');

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
      final List<dynamic>? apps = await _channel.invokeMethod('getInstalledApps');
      if (apps == null) return [];

      return apps.map((app) {
        final map = app as Map<dynamic, dynamic>;
        return InstalledApp(
          packageName: map['packageName'] as String,
          appName: map['appName'] as String? ?? map['packageName'] as String,
          category: map['category'] as String?,
        );
      }).where(_shouldInclude).toList();
    } on PlatformException catch (e) {
      print('Failed to get installed apps: ${e.message}');
      return [];
    }
  }

  /// 判断是否应该包含该应用
  bool _shouldInclude(InstalledApp app) {
    // 排除本应用
    if (app.packageName == _selfPackage) return false;

    // 排除系统应用
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

final appDiscoveryServiceProvider = Provider<AppDiscoveryService>((ref) {
  return AppDiscoveryService();
});
```

- [ ] **Step 2: 添加 Android 原生通道实现**

在 `android/app/src/main/kotlin/.../MainActivity.kt` 中添加方法通道处理。

- [ ] **Step 3: 提交**

```bash
git add lib/core/services/app_discovery_service.dart
git commit -m "feat(service): add AppDiscoveryService for listing installed apps"
```

---

### Task 12: 创建 ContinuousUsageService

**Files:**
- Create: `lib/core/services/continuous_usage_service.dart`

- [ ] **Step 1: 创建 ContinuousUsageService**

```dart
// lib/core/services/continuous_usage_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/continuous_session_dao.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/providers/continuous_usage_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/monitored_apps_provider.dart';
import 'package:intl/intl.dart';

/// 连续使用状态
enum ContinuousUsageStatus {
  normal,       // 正常使用
  warning5min,  // 5分钟警告
  warning2min,  // 2分钟警告
  atLimit,      // 到达限制
  inRest,       // 强制休息中
}

/// 连续使用监控服务
class ContinuousUsageService {
  final ContinuousSessionDao _sessionDao;
  final Ref _ref;

  static const _sessionBreakThresholdMinutes = 2;  // 切换非监控app中断阈值
  static const _screenOffThresholdMinutes = 5;     // 屏幕关闭中断阈值
  static const _restoreThresholdMinutes = 30;      // 恢复阈值

  ContinuousUsageService(this._sessionDao, this._ref);

  /// 获取当前日期字符串
  String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// 获取当前状态
  Future<ContinuousUsageStatus> getStatus() async {
    final session = await _sessionDao.getActiveSession(_today());
    if (session == null) return ContinuousUsageStatus.normal;

    // 检查是否在休息中
    if (session.isInRest) return ContinuousUsageStatus.inRest;

    final settings = _ref.read(continuousUsageSettingsProvider);
    if (!settings.enabled) return ContinuousUsageStatus.normal;

    final limitSeconds = settings.limitMinutes * 60;
    final remainingSeconds = limitSeconds - session.totalDurationSeconds;

    if (remainingSeconds <= 0) return ContinuousUsageStatus.atLimit;
    if (remainingSeconds <= 2 * 60) return ContinuousUsageStatus.warning2min;
    if (remainingSeconds <= 5 * 60) return ContinuousUsageStatus.warning5min;

    return ContinuousUsageStatus.normal;
  }

  /// 记录 app 使用开始
  Future<void> onAppStarted(String packageName) async {
    final monitoredApps = _ref.read(monitoredAppsProvider);
    if (!monitoredApps.isMonitored(packageName)) return;

    var session = await _sessionDao.getActiveSession(_today());

    if (session == null) {
      // 创建新会话
      final now = DateTime.now();
      session = ContinuousSession(
        sessionDate: _today(),
        startTime: now,
        lastActivityTime: now,
        createdAt: now,
        updatedAt: now,
      );
      final id = await _sessionDao.insert(session);
      session = session.copyWith(id: id);
    } else {
      // 更新活动时间
      session = session.copyWith(
        lastActivityTime: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _sessionDao.update(session);
    }
  }

  /// 记录 app 使用结束
  Future<void> onAppStopped(String packageName, int durationSeconds) async {
    final monitoredApps = _ref.read(monitoredAppsProvider);
    if (!monitoredApps.isMonitored(packageName)) return;

    final session = await _sessionDao.getActiveSession(_today());
    if (session == null) return;

    // 累加使用时间
    session = session.copyWith(
      totalDurationSeconds: session.totalDurationSeconds + durationSeconds,
      lastActivityTime: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _sessionDao.update(session);
  }

  /// 检查是否需要触发强制休息
  Future<bool> shouldTriggerRest() async {
    final status = await getStatus();
    if (status == ContinuousUsageStatus.atLimit) {
      await _triggerRest();
      return true;
    }
    return false;
  }

  /// 触发强制休息
  Future<void> _triggerRest() async {
    final session = await _sessionDao.getActiveSession(_today());
    if (session == null) return;

    final settings = _ref.read(continuousUsageSettingsProvider);
    final restEndTime = DateTime.now().add(Duration(minutes: settings.restMinutes));

    session = session.copyWith(
      restEndTime: restEndTime,
      updatedAt: DateTime.now(),
    );
    await _sessionDao.update(session);
  }

  /// 检查是否需要显示提醒
  Future<String?> getAlertToShow() async {
    final session = await _sessionDao.getActiveSession(_today());
    if (session == null) return null;

    final settings = _ref.read(continuousUsageSettingsProvider);
    if (!settings.enabled) return null;

    final limitSeconds = settings.limitMinutes * 60;
    final remainingSeconds = limitSeconds - session.totalDurationSeconds;

    // 2分钟警告
    if (remainingSeconds <= 2 * 60 && !session.alertsShown.contains('2min')) {
      return '2min';
    }

    // 5分钟警告
    if (remainingSeconds <= 5 * 60 && !session.alertsShown.contains('5min')) {
      return '5min';
    }

    return null;
  }

  /// 标记提醒已显示
  Future<void> markAlertShown(String alertLevel) async {
    final session = await _sessionDao.getActiveSession(_today());
    if (session == null) return;

    final newAlerts = {...session.alertsShown, alertLevel};
    session = session.copyWith(
      alertsShown: newAlerts,
      updatedAt: DateTime.now(),
    );
    await _sessionDao.update(session);
  }

  /// 恢复会话状态
  Future<void> restoreSession() async {
    final session = await _sessionDao.getActiveSession(_today());
    if (session == null) return;

    final lastActivity = session.lastActivityTime;
    if (lastActivity == null) return;

    final now = DateTime.now();
    final threshold = Duration(minutes: _restoreThresholdMinutes);

    // 超过阈值，停用会话
    if (now.difference(lastActivity) > threshold) {
      await _sessionDao.deactivate(session.id!);
    }
  }

  /// 获取剩余休息时间（秒）
  Future<int?> getRemainingRestSeconds() async {
    final session = await _sessionDao.getRestingSession(_today());
    return session?.remainingRestSeconds;
  }
}

final continuousUsageServiceProvider = Provider<ContinuousUsageService>((ref) {
  final db = AppDatabase.instance;
  return ContinuousUsageService(ContinuousSessionDao(db), ref);
});
```

- [ ] **Step 2: 提交**

```bash
git add lib/core/services/continuous_usage_service.dart
git commit -m "feat(service): add ContinuousUsageService for monitoring usage sessions"
```

---

### Task 13: 重构 RuleCheckerService

**Files:**
- Modify: `lib/core/services/rule_checker_service.dart`

- [ ] **Step 1: 更新 RuleCheckerService**

按照规格文档第 4 节的规则检查逻辑重构服务，添加新的检查流程：
1. 检查是否在 monitored_apps 中
2. 检查强制休息状态
3. 检查时间段规则
4. 检查连续使用限制
5. 检查单个 app 每日时间限制

- [ ] **Step 2: 提交**

```bash
git add lib/core/services/rule_checker_service.dart
git commit -m "refactor(service): rewrite RuleCheckerService with new rule hierarchy"
```

---

## Phase 3: UI 层

### Task 14: 创建 TimePeriodCard 组件

**Files:**
- Create: `lib/features/parent_mode/presentation/widgets/time_period_card.dart`

- [ ] **Step 1: 创建 TimePeriodCard**

```dart
// lib/features/parent_mode/presentation/widgets/time_period_card.dart
import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/core/theme/app_theme.dart';
import 'package:qiaoqiao_companion/shared/models/time_period.dart';

class TimePeriodCard extends StatelessWidget {
  final TimePeriod period;
  final Function(TimePeriod) onUpdate;
  final VoidCallback onDelete;

  const TimePeriodCard({
    super.key,
    required this.period,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间显示
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${period.timeStart} - ${period.timeEnd}',
                  style: AppTextStyles.heading3,
                ),
                Row(
                  children: [
                    Switch(
                      value: period.enabled,
                      onChanged: (value) => onUpdate(period.copyWith(enabled: value)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 适用日期
            Wrap(
              spacing: 4,
              children: _buildDayChips(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDayChips() {
    const dayNames = ['一', '二', '三', '四', '五', '六', '日'];
    return List.generate(7, (index) {
      final day = index + 1;
      final isSelected = period.days.contains(day);
      return FilterChip(
        label: Text(dayNames[index]),
        selected: isSelected,
        onSelected: (_) {
          final newDays = List<int>.from(period.days);
          if (isSelected) {
            newDays.remove(day);
          } else {
            newDays.add(day);
          }
          newDays.sort();
          onUpdate(period.copyWith(days: newDays));
        },
      );
    });
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/features/parent_mode/presentation/widgets/time_period_card.dart
git commit -m "feat(ui): add TimePeriodCard widget"
```

---

### Task 15: 创建 MonitoredAppCard 组件

**Files:**
- Create: `lib/features/parent_mode/presentation/widgets/monitored_app_card.dart`

- [ ] **Step 1: 创建 MonitoredAppCard**

- [ ] **Step 2: 提交**

```bash
git add lib/features/parent_mode/presentation/widgets/monitored_app_card.dart
git commit -m "feat(ui): add MonitoredAppCard widget"
```

---

### Task 16: 创建 TimePeriodsTab

**Files:**
- Create: `lib/features/parent_mode/presentation/time_periods_tab.dart`

- [ ] **Step 1: 创建 TimePeriodsTab**

包含模式切换开关、时段列表、添加时段按钮。

- [ ] **Step 2: 提交**

```bash
git add lib/features/parent_mode/presentation/time_periods_tab.dart
git commit -m "feat(ui): add TimePeriodsTab"
```

---

### Task 17: 创建 AppSelectionPage

**Files:**
- Create: `lib/features/parent_mode/presentation/app_selection_page.dart`

- [ ] **Step 1: 创建 AppSelectionPage**

显示已安装应用列表，支持搜索过滤，批量选择。

- [ ] **Step 2: 提交**

```bash
git add lib/features/parent_mode/presentation/app_selection_page.dart
git commit -m "feat(ui): add AppSelectionPage"
```

---

### Task 18: 创建 AppManagementTab

**Files:**
- Create: `lib/features/parent_mode/presentation/app_management_tab.dart`

- [ ] **Step 1: 创建 AppManagementTab**

显示已监控应用列表，添加应用按钮跳转到 AppSelectionPage。

- [ ] **Step 2: 提交**

```bash
git add lib/features/parent_mode/presentation/app_management_tab.dart
git commit -m "feat(ui): add AppManagementTab"
```

---

### Task 19: 创建 ContinuousUsageTab

**Files:**
- Create: `lib/features/parent_mode/presentation/continuous_usage_tab.dart`

- [ ] **Step 1: 创建 ContinuousUsageTab**

包含启用开关、时长设置、休息时长设置。

- [ ] **Step 2: 提交**

```bash
git add lib/features/parent_mode/presentation/continuous_usage_tab.dart
git commit -m "feat(ui): add ContinuousUsageTab"
```

---

### Task 20: 创建 ContinuousUsageReminder 弹窗

**Files:**
- Create: `lib/features/parent_mode/presentation/widgets/continuous_usage_reminder.dart`

- [ ] **Step 1: 创建 ContinuousUsageReminder**

可拖动的半透明提醒弹窗，显示倒计时和休息建议。

- [ ] **Step 2: 提交**

```bash
git add lib/features/parent_mode/presentation/widgets/continuous_usage_reminder.dart
git commit -m "feat(ui): add ContinuousUsageReminder draggable overlay"
```

---

### Task 21: 重构 EditRulesPage

**Files:**
- Modify: `lib/features/parent_mode/presentation/edit_rules_page.dart`

- [ ] **Step 1: 重构为 Tab 布局**

使用 TabBar + TabBarView 组合三个 Tab 页面。

- [ ] **Step 2: 提交**

```bash
git add lib/features/parent_mode/presentation/edit_rules_page.dart
git commit -m "refactor(ui): restructure EditRulesPage as Tab layout"
```

---

## Phase 4: 集成测试

### Task 22: 端到端测试

**Files:**
- Modify: `test/widget_test.dart` 或新建测试文件

- [ ] **Step 1: 编写时间段设置测试**

- [ ] **Step 2: 编写应用管理测试**

- [ ] **Step 3: 编写连续使用限制测试**

- [ ] **Step 4: 提交**

```bash
git add test/
git commit -m "test: add integration tests for rules redesign"
```

---

### Task 23: 最终验收

- [ ] **Step 1: 运行完整测试套**

```bash
flutter test
```

- [ ] **Step 2: 手动测试关键流程**

按照规格文档第 8 节验收标准逐项验证。

- [ ] **Step 3: 修复发现的问题**

- [ ] **Step 4: 最终提交**

```bash
git add -A
git commit -m "feat: complete parent rules redesign feature"
```

---

## 验收清单

### 功能验收
- [ ] 未设置的 app 不受任何限制，不计入时间统计
- [ ] 可以添加/编辑/删除时间段规则
- [ ] 时间段支持跨天（如 22:00-06:00）
- [ ] 可以添加/编辑/删除被监控的 app
- [ ] 可以设置单个 app 的每日时间限制
- [ ] 连续使用限制开关和时长设置正常工作
- [ ] 连续使用提醒弹窗可拖动
- [ ] 强制休息机制正常工作
- [ ] 强制休息优先级高于时间段规则

### 数据迁移验收
- [ ] 现有 timeBlock 规则正确迁移到 time_periods
- [ ] 现有 appSingle 规则正确迁移到 monitored_apps
- [ ] 现有 appCategory 规则正确迁移
- [ ] 无效数据被正确跳过
- [ ] 迁移后数据完整性

### UI 验收
- [ ] 三个 Tab 切换流畅
- [ ] 时间段设置界面直观易用
- [ ] 应用选择界面正确过滤系统应用
- [ ] 应用选择界面搜索功能正常
- [ ] 连续使用设置界面简洁明了
- [ ] 提醒弹窗显示正确的时间倒计时
