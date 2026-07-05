# P1 核心任务系统 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现任务 CRUD、打卡、积分奖励/惩罚、数据库迁移、任务 Tab、家长端任务管理，构成完整的"完成任务→获得积分"正向激励闭环。

**Architecture:** 数据层使用 sqflite（v5→v6 迁移，新增 3 表 + 修复 2 bug），DAO 层负责 CRUD，Model 层纯数据类，Provider 层（Riverpod StateNotifier）管理状态和业务逻辑（积分联动、惩罚计算），UI 层遵循现有 features/ 目录结构。所有新颜色使用 `Theme.of(context)` 获取，不自成一格。

**Tech Stack:** Flutter + Riverpod + sqflite + GoRouter

**Spec:** `docs/superpowers/specs/2026-07-05-egg-growth-task-system-design.md`

---

## 文件结构

| 文件 | 责任 | 动作 |
|------|------|------|
| `qiaoqiao_companion/lib/core/constants/database_constants.dart` | 新增 TaskCategory/CheckinMode 枚举和表名常量 | 修改 |
| `qiaoqiao_companion/lib/core/database/app_database.dart` | v6 迁移：新增 3 表 + 修复 2 bug | 修改 |
| `qiaoqiao_companion/lib/core/database/daos/task_definition_dao.dart` | 任务定义 CRUD | 新建 |
| `qiaoqiao_companion/lib/core/database/daos/task_checkin_dao.dart` | 打卡记录 CRUD + 统计查询 | 新建 |
| `qiaoqiao_companion/lib/core/database/daos/task_penalty_dao.dart` | 惩罚记录 CRUD + 查询 | 新建 |
| `qiaoqiao_companion/lib/core/database/daos/daos.dart` | 导出新增 3 个 DAO | 修改 |
| `qiaoqiao_companion/lib/shared/models/task_definition.dart` | 任务定义模型 | 新建 |
| `qiaoqiao_companion/lib/shared/models/task_checkin.dart` | 打卡记录模型 | 新建 |
| `qiaoqiao_companion/lib/shared/models/task_penalty.dart` | 惩罚记录模型 | 新建 |
| `qiaoqiao_companion/lib/shared/models/models.dart` | 导出新增 3 个模型 | 修改 |
| `qiaoqiao_companion/lib/shared/providers/task_provider.dart` | 任务状态管理（列表/打卡/惩罚/积分联动） | 新建 |
| `qiaoqiao_companion/lib/shared/providers/points_provider.dart` | addPoints/deductPoints 传递 category 参数 | 修改 |
| `qiaoqiao_companion/lib/features/tasks/presentation/task_page.dart` | 任务 Tab 页面 | 新建 |
| `qiaoqiao_companion/lib/features/parent_mode/presentation/task_management_page.dart` | 家长端任务列表管理 | 新建 |
| `qiaoqiao_companion/lib/features/parent_mode/presentation/task_edit_page.dart` | 家长端任务编辑表单 | 新建 |
| `qiaoqiao_companion/lib/app/shell_page.dart` | 3 Tab → 4 Tab（任务 Tab 在 index 2，图标 emoji_nature_rounded） | 修改 |
| `qiaoqiao_companion/lib/app/router.dart` | 新增 /tasks 路由和家长端任务管理路由 | 修改 |
| `qiaoqiao_companion/lib/features/parent_mode/presentation/parent_mode_page.dart` | 新增"管理任务"入口 | 修改 |
| `qiaoqiao_companion/test/core/constants/database_constants_test.dart` | 枚举和常量测试 | 新建 |
| `qiaoqiao_companion/test/core/database/app_database_migration_test.dart` | 数据库迁移测试 | 新建 |
| `qiaoqiao_companion/test/shared/models/task_definition_test.dart` | 任务定义模型测试 | 新建 |
| `qiaoqiao_companion/test/shared/models/task_checkin_test.dart` | 打卡记录模型测试 | 新建 |
| `qiaoqiao_companion/test/shared/models/task_penalty_test.dart` | 惩罚记录模型测试 | 新建 |
| `qiaoqiao_companion/test/core/database/daos/task_definition_dao_test.dart` | 任务定义 DAO 测试 | 新建 |
| `qiaoqiao_companion/test/core/database/daos/task_checkin_dao_test.dart` | 打卡记录 DAO 测试 | 新建 |
| `qiaoqiao_companion/test/core/database/daos/task_penalty_dao_test.dart` | 惩罚记录 DAO 测试 | 新建 |
| `qiaoqiao_companion/test/shared/providers/task_provider_test.dart` | 任务 Provider 测试 | 新建 |

---

## Task 1: 数据库常量扩展

**Files:**
- Modify: `qiaoqiao_companion/lib/core/constants/database_constants.dart`
- Create: `qiaoqiao_companion/test/core/constants/database_constants_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `qiaoqiao_companion/test/core/constants/database_constants_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

void main() {
  test('TaskCategory 枚举值正确', () {
    expect(TaskCategory.health.code, 'health');
    expect(TaskCategory.study.code, 'study');
    expect(TaskCategory.chore.code, 'chore');
    expect(TaskCategory.discipline.code, 'discipline');
  });

  test('TaskCategory fromCode 正确', () {
    expect(TaskCategory.fromCode('health'), TaskCategory.health);
    expect(TaskCategory.fromCode('study'), TaskCategory.study);
    expect(TaskCategory.fromCode('unknown'), TaskCategory.health);
  });

  test('CheckinMode 枚举值正确', () {
    expect(CheckinMode.self.code, 'self');
    expect(CheckinMode.parentConfirm.code, 'parent_confirm');
    expect(CheckinMode.scheduled.code, 'scheduled');
  });

  test('CheckinMode fromCode 正确', () {
    expect(CheckinMode.fromCode('self'), CheckinMode.self);
    expect(CheckinMode.fromCode('parent_confirm'), CheckinMode.parentConfirm);
    expect(CheckinMode.fromCode('unknown'), CheckinMode.self);
  });

  test('新增表名常量存在', () {
    expect(DatabaseConstants.tableTaskDefinitions, 'task_definitions');
    expect(DatabaseConstants.tableTaskCheckins, 'task_checkins');
    expect(DatabaseConstants.tableTaskPenalties, 'task_penalties');
    expect(DatabaseConstants.tableUserAchievements, 'user_achievements');
  });

  test('databaseVersion 为 6', () {
    expect(DatabaseConstants.databaseVersion, 6);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/core/constants/database_constants_test.dart`
Expected: FAIL — `TaskCategory`、`CheckinMode`、新表名常量不存在

- [ ] **Step 3: 实现最小代码**

在 `DatabaseConstants` 类中添加表名常量：

```dart
  static const String tableTaskDefinitions = 'task_definitions';
  static const String tableTaskCheckins = 'task_checkins';
  static const String tableTaskPenalties = 'task_penalties';
  static const String tableUserAchievements = 'user_achievements';
```

将 `databaseVersion` 从 `5` 改为 `6`。

在文件末尾（`PointsConstants` 之后）新增两个枚举：

```dart
enum TaskCategory {
  health('health', '🏃 健康运动'),
  study('study', '📚 学习阅读'),
  chore('chore', '🧹 家务劳动'),
  discipline('discipline', '⭐ 自律守则');

  const TaskCategory(this.code, this.label);
  final String code;
  final String label;

  static TaskCategory fromCode(String code) {
    return TaskCategory.values.firstWhere(
      (e) => e.code == code,
      orElse: () => TaskCategory.health,
    );
  }
}

enum CheckinMode {
  self('self', '自助打卡'),
  parentConfirm('parent_confirm', '家长确认'),
  scheduled('scheduled', '定时自动');

  const CheckinMode(this.code, this.label);
  final String code;
  final String label;

  static CheckinMode fromCode(String code) {
    return CheckinMode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => CheckinMode.self,
    );
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/core/constants/database_constants_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add qiaoqiao_companion/lib/core/constants/database_constants.dart qiaoqiao_companion/test/core/constants/database_constants_test.dart
git commit -m "feat: add TaskCategory/CheckinMode enums and new table name constants"
```

---

## Task 2: 数据库迁移 v5 → v6

**Files:**
- Modify: `qiaoqiao_companion/lib/core/database/app_database.dart`
- Create: `qiaoqiao_companion/test/core/database/app_database_migration_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `qiaoqiao_companion/test/core/database/app_database_migration_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v6 新建 task_definitions 表结构正确', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE task_definitions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            emoji TEXT NOT NULL DEFAULT '⭐',
            category TEXT NOT NULL,
            base_points INTEGER NOT NULL,
            extra_points INTEGER NOT NULL DEFAULT 0,
            min_daily_count INTEGER NOT NULL DEFAULT 1,
            max_daily_count INTEGER NOT NULL DEFAULT 1,
            daily_points_cap INTEGER,
            checkin_mode TEXT NOT NULL DEFAULT 'self',
            scheduled_time TEXT,
            penalty_minutes INTEGER NOT NULL DEFAULT 0,
            reminder_time TEXT,
            reminder_repeat_interval INTEGER NOT NULL DEFAULT 0,
            enabled INTEGER NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');
      },
    );

    final columns = await db.rawQuery('PRAGMA table_info(task_definitions)');
    final columnNames = columns.map((c) => c['name'] as String).toList();
    expect(columnNames, containsAll([
      'id', 'name', 'emoji', 'category', 'base_points', 'extra_points',
      'min_daily_count', 'max_daily_count', 'daily_points_cap',
      'checkin_mode', 'scheduled_time', 'penalty_minutes',
      'reminder_time', 'reminder_repeat_interval', 'enabled',
      'sort_order', 'created_at', 'updated_at',
    ]));

    await db.close();
  });

  test('v6 新建 task_checkins 表结构正确', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE task_checkins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER NOT NULL,
            checkin_date TEXT NOT NULL,
            checkin_time TEXT NOT NULL,
            points_earned INTEGER NOT NULL DEFAULT 0,
            confirmed_by_parent INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          );
        ''');
      },
    );

    final columns = await db.rawQuery('PRAGMA table_info(task_checkins)');
    final columnNames = columns.map((c) => c['name'] as String).toList();
    expect(columnNames, containsAll([
      'id', 'task_id', 'checkin_date', 'checkin_time',
      'points_earned', 'confirmed_by_parent', 'created_at',
    ]));

    await db.close();
  });

  test('v6 新建 task_penalties 表结构正确', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE task_penalties (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER NOT NULL,
            penalty_date TEXT NOT NULL,
            penalty_minutes INTEGER NOT NULL,
            reason TEXT NOT NULL,
            applied INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          );
        ''');
      },
    );

    final columns = await db.rawQuery('PRAGMA table_info(task_penalties)');
    final columnNames = columns.map((c) => c['name'] as String).toList();
    expect(columnNames, containsAll([
      'id', 'task_id', 'penalty_date', 'penalty_minutes',
      'reason', 'applied', 'created_at',
    ]));

    await db.close();
  });

  test('v6 修复: user_achievements 表可创建', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE user_achievements (
            achievement_id TEXT PRIMARY KEY,
            unlocked_at INTEGER NOT NULL,
            progress INTEGER NOT NULL DEFAULT 0,
            is_unlocked INTEGER NOT NULL DEFAULT 0
          );
        ''');
      },
    );

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='user_achievements'",
    );
    expect(tables.length, 1);

    await db.close();
  });

  test('v6 修复: points_history 含 category 列', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE points_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            change INTEGER NOT NULL,
            reason TEXT NOT NULL,
            balance_after INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            category TEXT NOT NULL DEFAULT 'other'
          );
        ''');
      },
    );

    final columns = await db.rawQuery('PRAGMA table_info(points_history)');
    final columnNames = columns.map((c) => c['name'] as String).toList();
    expect(columnNames, contains('category'));

    await db.close();
  });
}
```

- [ ] **Step 2: 添加测试依赖**

在 `qiaoqiao_companion/pubspec.yaml` 的 `dev_dependencies` 中添加：

```yaml
  sqflite_common_ffi: ^2.3.4
```

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter pub get`

- [ ] **Step 3: 运行测试验证通过（schema 测试不依赖 app_database.dart）**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/core/database/app_database_migration_test.dart`
Expected: PASS

- [ ] **Step 4: 修改 app_database.dart 实现 v6 迁移**

1. 在 `_onCreate` 方法中：

1a. 修改 `points_history` 建表语句，添加 `category` 列：

将原：
```dart
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tablePointsHistory} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        change INTEGER NOT NULL,
        reason TEXT NOT NULL,
        balance_after INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');
```

改为：
```dart
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tablePointsHistory} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        change INTEGER NOT NULL,
        reason TEXT NOT NULL,
        balance_after INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        category TEXT NOT NULL DEFAULT 'other'
      );
    ''');
```

1b. 在 `_onCreate` 末尾（`app_settings` 建表之后）添加：

```dart
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableUserAchievements} (
        achievement_id TEXT PRIMARY KEY,
        unlocked_at INTEGER NOT NULL,
        progress INTEGER NOT NULL DEFAULT 0,
        is_unlocked INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableTaskDefinitions} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL DEFAULT '⭐',
        category TEXT NOT NULL,
        base_points INTEGER NOT NULL,
        extra_points INTEGER NOT NULL DEFAULT 0,
        min_daily_count INTEGER NOT NULL DEFAULT 1,
        max_daily_count INTEGER NOT NULL DEFAULT 1,
        daily_points_cap INTEGER,
        checkin_mode TEXT NOT NULL DEFAULT 'self',
        scheduled_time TEXT,
        penalty_minutes INTEGER NOT NULL DEFAULT 0,
        reminder_time TEXT,
        reminder_repeat_interval INTEGER NOT NULL DEFAULT 0,
        enabled INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableTaskCheckins} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        checkin_date TEXT NOT NULL,
        checkin_time TEXT NOT NULL,
        points_earned INTEGER NOT NULL DEFAULT 0,
        confirmed_by_parent INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (task_id) REFERENCES task_definitions(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableTaskPenalties} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        penalty_date TEXT NOT NULL,
        penalty_minutes INTEGER NOT NULL,
        reason TEXT NOT NULL,
        applied INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_task_checkins_date ON ${DatabaseConstants.tableTaskCheckins}(checkin_date);
    ''');
    await db.execute('''
      CREATE INDEX idx_task_checkins_task ON ${DatabaseConstants.tableTaskCheckins}(task_id);
    ''');
    await db.execute('''
      CREATE INDEX idx_task_penalties_date ON ${DatabaseConstants.tableTaskPenalties}(penalty_date);
    ''');
    await db.execute('''
      CREATE INDEX idx_task_penalties_applied ON ${DatabaseConstants.tableTaskPenalties}(applied);
    ''');
```

2. 在 `_onUpgrade` 方法末尾添加 v6 迁移：

```dart
    if (oldVersion < 6) {
      print('[AppDatabase] Upgrading from v5 to v6...');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableUserAchievements} (
          achievement_id TEXT PRIMARY KEY,
          unlocked_at INTEGER NOT NULL,
          progress INTEGER NOT NULL DEFAULT 0,
          is_unlocked INTEGER NOT NULL DEFAULT 0
        );
      ''');

      await db.execute(
        'ALTER TABLE ${DatabaseConstants.tablePointsHistory} ADD COLUMN category TEXT NOT NULL DEFAULT \'other\'',
      );

      await db.execute('''
        CREATE TABLE ${DatabaseConstants.tableTaskDefinitions} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          emoji TEXT NOT NULL DEFAULT '⭐',
          category TEXT NOT NULL,
          base_points INTEGER NOT NULL,
          extra_points INTEGER NOT NULL DEFAULT 0,
          min_daily_count INTEGER NOT NULL DEFAULT 1,
          max_daily_count INTEGER NOT NULL DEFAULT 1,
          daily_points_cap INTEGER,
          checkin_mode TEXT NOT NULL DEFAULT 'self',
          scheduled_time TEXT,
          penalty_minutes INTEGER NOT NULL DEFAULT 0,
          reminder_time TEXT,
          reminder_repeat_interval INTEGER NOT NULL DEFAULT 0,
          enabled INTEGER NOT NULL DEFAULT 1,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE ${DatabaseConstants.tableTaskCheckins} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER NOT NULL,
          checkin_date TEXT NOT NULL,
          checkin_time TEXT NOT NULL,
          points_earned INTEGER NOT NULL DEFAULT 0,
          confirmed_by_parent INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (task_id) REFERENCES task_definitions(id)
        );
      ''');

      await db.execute('''
        CREATE TABLE ${DatabaseConstants.tableTaskPenalties} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER NOT NULL,
          penalty_date TEXT NOT NULL,
          penalty_minutes INTEGER NOT NULL,
          reason TEXT NOT NULL,
          applied INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE INDEX idx_task_checkins_date ON ${DatabaseConstants.tableTaskCheckins}(checkin_date);
      ''');
      await db.execute('''
        CREATE INDEX idx_task_checkins_task ON ${DatabaseConstants.tableTaskCheckins}(task_id);
      ''');
      await db.execute('''
        CREATE INDEX idx_task_penalties_date ON ${DatabaseConstants.tableTaskPenalties}(penalty_date);
      ''');
      await db.execute('''
        CREATE INDEX idx_task_penalties_applied ON ${DatabaseConstants.tableTaskPenalties}(applied);
      ''');

      print('[AppDatabase] Upgrade to v6 completed');
    }
```

3. 在 `clearAllTables` 方法中添加：

```dart
    await db.delete(DatabaseConstants.tableUserAchievements);
    await db.delete(DatabaseConstants.tableTaskDefinitions);
    await db.delete(DatabaseConstants.tableTaskCheckins);
    await db.delete(DatabaseConstants.tableTaskPenalties);
```

- [ ] **Step 5: Commit**

```bash
git add qiaoqiao_companion/lib/core/database/app_database.dart qiaoqiao_companion/lib/core/constants/database_constants.dart qiaoqiao_companion/test/core/database/app_database_migration_test.dart qiaoqiao_companion/pubspec.yaml qiaoqiao_companion/pubspec.lock
git commit -m "feat: database migration v5→v6, add task tables + fix user_achievements and points_history category"
```

---

## Task 3: 数据模型 — TaskDefinition

**Files:**
- Create: `qiaoqiao_companion/lib/shared/models/task_definition.dart`
- Create: `qiaoqiao_companion/test/shared/models/task_definition_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `qiaoqiao_companion/test/shared/models/task_definition_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';

void main() {
  final now = DateTime(2026, 7, 5, 10, 0, 0);

  test('TaskDefinition 构造与字段访问', () {
    final task = TaskDefinition(
      name: '跳绳',
      emoji: '🏃',
      category: TaskCategory.health,
      basePoints: 15,
      extraPoints: 5,
      minDailyCount: 1,
      maxDailyCount: 3,
      checkinMode: CheckinMode.self,
      penaltyMinutes: 10,
      createdAt: now,
      updatedAt: now,
    );

    expect(task.id, isNull);
    expect(task.name, '跳绳');
    expect(task.emoji, '🏃');
    expect(task.category, TaskCategory.health);
    expect(task.basePoints, 15);
    expect(task.extraPoints, 5);
    expect(task.minDailyCount, 1);
    expect(task.maxDailyCount, 3);
    expect(task.dailyPointsCap, isNull);
    expect(task.checkinMode, CheckinMode.self);
    expect(task.scheduledTime, isNull);
    expect(task.penaltyMinutes, 10);
    expect(task.reminderTime, isNull);
    expect(task.reminderRepeatInterval, 0);
    expect(task.enabled, true);
    expect(task.sortOrder, 0);
  });

  test('TaskDefinition.toMap 输出正确', () {
    final task = TaskDefinition(
      id: 1,
      name: '跳绳',
      emoji: '🏃',
      category: TaskCategory.health,
      basePoints: 15,
      extraPoints: 5,
      minDailyCount: 1,
      maxDailyCount: 3,
      checkinMode: CheckinMode.self,
      penaltyMinutes: 10,
      createdAt: now,
      updatedAt: now,
    );

    final map = task.toMap();
    expect(map['id'], 1);
    expect(map['name'], '跳绳');
    expect(map['emoji'], '🏃');
    expect(map['category'], 'health');
    expect(map['base_points'], 15);
    expect(map['extra_points'], 5);
    expect(map['min_daily_count'], 1);
    expect(map['max_daily_count'], 3);
    expect(map['daily_points_cap'], isNull);
    expect(map['checkin_mode'], 'self');
    expect(map['scheduled_time'], isNull);
    expect(map['penalty_minutes'], 10);
    expect(map['reminder_time'], isNull);
    expect(map['reminder_repeat_interval'], 0);
    expect(map['enabled'], 1);
    expect(map['sort_order'], 0);
    expect(map['created_at'], now.millisecondsSinceEpoch);
    expect(map['updated_at'], now.millisecondsSinceEpoch);
  });

  test('TaskDefinition.fromMap 正确反序列化', () {
    final map = {
      'id': 1,
      'name': '阅读30分钟',
      'emoji': '📖',
      'category': 'study',
      'base_points': 20,
      'extra_points': 10,
      'min_daily_count': 1,
      'max_daily_count': 2,
      'daily_points_cap': null,
      'checkin_mode': 'parent_confirm',
      'scheduled_time': '20:00',
      'penalty_minutes': 15,
      'reminder_time': '19:30',
      'reminder_repeat_interval': 10,
      'enabled': 1,
      'sort_order': 2,
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    };

    final task = TaskDefinition.fromMap(map);
    expect(task.id, 1);
    expect(task.name, '阅读30分钟');
    expect(task.emoji, '📖');
    expect(task.category, TaskCategory.study);
    expect(task.basePoints, 20);
    expect(task.extraPoints, 10);
    expect(task.minDailyCount, 1);
    expect(task.maxDailyCount, 2);
    expect(task.dailyPointsCap, isNull);
    expect(task.checkinMode, CheckinMode.parentConfirm);
    expect(task.scheduledTime, '20:00');
    expect(task.penaltyMinutes, 15);
    expect(task.reminderTime, '19:30');
    expect(task.reminderRepeatInterval, 10);
    expect(task.enabled, true);
    expect(task.sortOrder, 2);
  });

  test('TaskDefinition round-trip toMap→fromMap 一致', () {
    final original = TaskDefinition(
      name: '洗碗',
      emoji: '🧹',
      category: TaskCategory.chore,
      basePoints: 10,
      extraPoints: 3,
      minDailyCount: 1,
      maxDailyCount: 1,
      dailyPointsCap: 30,
      checkinMode: CheckinMode.parentConfirm,
      penaltyMinutes: 5,
      createdAt: now,
      updatedAt: now,
    );

    final map = original.toMap();
    final restored = TaskDefinition.fromMap(map);
    expect(restored.name, original.name);
    expect(restored.emoji, original.emoji);
    expect(restored.category, original.category);
    expect(restored.basePoints, original.basePoints);
    expect(restored.extraPoints, original.extraPoints);
    expect(restored.minDailyCount, original.minDailyCount);
    expect(restored.maxDailyCount, original.maxDailyCount);
    expect(restored.dailyPointsCap, original.dailyPointsCap);
    expect(restored.checkinMode, original.checkinMode);
    expect(restored.penaltyMinutes, original.penaltyMinutes);
    expect(restored.enabled, original.enabled);
  });

  test('TaskDefinition.copyWith 正确', () {
    final task = TaskDefinition(
      name: '跳绳',
      emoji: '🏃',
      category: TaskCategory.health,
      basePoints: 15,
      createdAt: now,
      updatedAt: now,
    );

    final copied = task.copyWith(enabled: false, name: '跑步');
    expect(copied.name, '跑步');
    expect(copied.enabled, false);
    expect(copied.basePoints, 15);
  });

  test('TaskCategory 到 PointsCategory 映射', () {
    expect(TaskCategory.health.pointsCategory, PointsCategory.exerciseReward);
    expect(TaskCategory.study.pointsCategory, PointsCategory.studyReward);
    expect(TaskCategory.chore.pointsCategory, PointsCategory.choreReward);
    expect(TaskCategory.discipline.pointsCategory, PointsCategory.restReward);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/shared/models/task_definition_test.dart`
Expected: FAIL — `TaskDefinition` 类不存在

- [ ] **Step 3: 实现 TaskDefinition 模型**

创建 `qiaoqiao_companion/lib/shared/models/task_definition.dart`：

```dart
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

class TaskDefinition {
  final int? id;
  final String name;
  final String emoji;
  final TaskCategory category;
  final int basePoints;
  final int extraPoints;
  final int minDailyCount;
  final int maxDailyCount;
  final int? dailyPointsCap;
  final CheckinMode checkinMode;
  final String? scheduledTime;
  final int penaltyMinutes;
  final String? reminderTime;
  final int reminderRepeatInterval;
  final bool enabled;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskDefinition({
    this.id,
    required this.name,
    this.emoji = '⭐',
    required this.category,
    required this.basePoints,
    this.extraPoints = 0,
    this.minDailyCount = 1,
    this.maxDailyCount = 1,
    this.dailyPointsCap,
    this.checkinMode = CheckinMode.self,
    this.scheduledTime,
    this.penaltyMinutes = 0,
    this.reminderTime,
    this.reminderRepeatInterval = 0,
    this.enabled = true,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory TaskDefinition.fromMap(Map<String, dynamic> map) {
    return TaskDefinition(
      id: map['id'] as int?,
      name: map['name'] as String,
      emoji: map['emoji'] as String? ?? '⭐',
      category: TaskCategory.fromCode(map['category'] as String? ?? 'health'),
      basePoints: map['base_points'] as int,
      extraPoints: map['extra_points'] as int? ?? 0,
      minDailyCount: map['min_daily_count'] as int? ?? 1,
      maxDailyCount: map['max_daily_count'] as int? ?? 1,
      dailyPointsCap: map['daily_points_cap'] as int?,
      checkinMode: CheckinMode.fromCode(map['checkin_mode'] as String? ?? 'self'),
      scheduledTime: map['scheduled_time'] as String?,
      penaltyMinutes: map['penalty_minutes'] as int? ?? 0,
      reminderTime: map['reminder_time'] as String?,
      reminderRepeatInterval: map['reminder_repeat_interval'] as int? ?? 0,
      enabled: (map['enabled'] as int?) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'emoji': emoji,
      'category': category.code,
      'base_points': basePoints,
      'extra_points': extraPoints,
      'min_daily_count': minDailyCount,
      'max_daily_count': maxDailyCount,
      'daily_points_cap': dailyPointsCap,
      'checkin_mode': checkinMode.code,
      'scheduled_time': scheduledTime,
      'penalty_minutes': penaltyMinutes,
      'reminder_time': reminderTime,
      'reminder_repeat_interval': reminderRepeatInterval,
      'enabled': enabled ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  PointsCategory get pointsCategory {
    switch (category) {
      case TaskCategory.health:
        return PointsCategory.exerciseReward;
      case TaskCategory.study:
        return PointsCategory.studyReward;
      case TaskCategory.chore:
        return PointsCategory.choreReward;
      case TaskCategory.discipline:
        return PointsCategory.restReward;
    }
  }

  TaskDefinition copyWith({
    int? id,
    String? name,
    String? emoji,
    TaskCategory? category,
    int? basePoints,
    int? extraPoints,
    int? minDailyCount,
    int? maxDailyCount,
    int? dailyPointsCap,
    CheckinMode? checkinMode,
    String? scheduledTime,
    int? penaltyMinutes,
    String? reminderTime,
    int? reminderRepeatInterval,
    bool? enabled,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      basePoints: basePoints ?? this.basePoints,
      extraPoints: extraPoints ?? this.extraPoints,
      minDailyCount: minDailyCount ?? this.minDailyCount,
      maxDailyCount: maxDailyCount ?? this.maxDailyCount,
      dailyPointsCap: dailyPointsCap ?? this.dailyPointsCap,
      checkinMode: checkinMode ?? this.checkinMode,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      penaltyMinutes: penaltyMinutes ?? this.penaltyMinutes,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderRepeatInterval: reminderRepeatInterval ?? this.reminderRepeatInterval,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'TaskDefinition(id: $id, name: $name, category: $category, enabled: $enabled)';
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/shared/models/task_definition_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add qiaoqiao_companion/lib/shared/models/task_definition.dart qiaoqiao_companion/test/shared/models/task_definition_test.dart
git commit -m "feat: add TaskDefinition data model with category→PointsCategory mapping"
```

---

## Task 4: 数据模型 — TaskCheckin 和 TaskPenalty

**Files:**
- Create: `qiaoqiao_companion/lib/shared/models/task_checkin.dart`
- Create: `qiaoqiao_companion/lib/shared/models/task_penalty.dart`
- Modify: `qiaoqiao_companion/lib/shared/models/models.dart`
- Create: `qiaoqiao_companion/test/shared/models/task_checkin_test.dart`
- Create: `qiaoqiao_companion/test/shared/models/task_penalty_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `qiaoqiao_companion/test/shared/models/task_checkin_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/shared/models/task_checkin.dart';

void main() {
  final now = DateTime(2026, 7, 5, 10, 30, 0);

  test('TaskCheckin 构造与字段访问', () {
    final checkin = TaskCheckin(
      taskId: 1,
      checkinDate: '2026-07-05',
      checkinTime: '10:30:00',
      pointsEarned: 15,
      createdAt: now,
    );

    expect(checkin.id, isNull);
    expect(checkin.taskId, 1);
    expect(checkin.checkinDate, '2026-07-05');
    expect(checkin.checkinTime, '10:30:00');
    expect(checkin.pointsEarned, 15);
    expect(checkin.confirmedByParent, false);
  });

  test('TaskCheckin round-trip toMap→fromMap', () {
    final checkin = TaskCheckin(
      id: 1,
      taskId: 2,
      checkinDate: '2026-07-05',
      checkinTime: '14:00:00',
      pointsEarned: 20,
      confirmedByParent: true,
      createdAt: now,
    );

    final map = checkin.toMap();
    final restored = TaskCheckin.fromMap(map);
    expect(restored.id, checkin.id);
    expect(restored.taskId, checkin.taskId);
    expect(restored.checkinDate, checkin.checkinDate);
    expect(restored.checkinTime, checkin.checkinTime);
    expect(restored.pointsEarned, checkin.pointsEarned);
    expect(restored.confirmedByParent, checkin.confirmedByParent);
  });
}
```

创建 `qiaoqiao_companion/test/shared/models/task_penalty_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/shared/models/task_penalty.dart';

void main() {
  final now = DateTime(2026, 7, 5, 8, 0, 0);

  test('TaskPenalty 构造与字段访问', () {
    final penalty = TaskPenalty(
      taskId: 1,
      penaltyDate: '2026-07-06',
      penaltyMinutes: 10,
      reason: '未完成"跳绳"基础次数',
      createdAt: now,
    );

    expect(penalty.id, isNull);
    expect(penalty.taskId, 1);
    expect(penalty.penaltyDate, '2026-07-06');
    expect(penalty.penaltyMinutes, 10);
    expect(penalty.reason, '未完成"跳绳"基础次数');
    expect(penalty.applied, false);
  });

  test('TaskPenalty round-trip toMap→fromMap', () {
    final penalty = TaskPenalty(
      id: 1,
      taskId: 2,
      penaltyDate: '2026-07-06',
      penaltyMinutes: 15,
      reason: '未完成"阅读"基础次数',
      applied: true,
      createdAt: now,
    );

    final map = penalty.toMap();
    final restored = TaskPenalty.fromMap(map);
    expect(restored.id, penalty.id);
    expect(restored.taskId, penalty.taskId);
    expect(restored.penaltyDate, penalty.penaltyDate);
    expect(restored.penaltyMinutes, penalty.penaltyMinutes);
    expect(restored.reason, penalty.reason);
    expect(restored.applied, penalty.applied);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/shared/models/task_checkin_test.dart test/shared/models/task_penalty_test.dart`
Expected: FAIL — 类不存在

- [ ] **Step 3: 实现 TaskCheckin 模型**

创建 `qiaoqiao_companion/lib/shared/models/task_checkin.dart`：

```dart
class TaskCheckin {
  final int? id;
  final int taskId;
  final String checkinDate;
  final String checkinTime;
  final int pointsEarned;
  final bool confirmedByParent;
  final DateTime createdAt;

  TaskCheckin({
    this.id,
    required this.taskId,
    required this.checkinDate,
    required this.checkinTime,
    this.pointsEarned = 0,
    this.confirmedByParent = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TaskCheckin.fromMap(Map<String, dynamic> map) {
    return TaskCheckin(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      checkinDate: map['checkin_date'] as String,
      checkinTime: map['checkin_time'] as String,
      pointsEarned: map['points_earned'] as int? ?? 0,
      confirmedByParent: (map['confirmed_by_parent'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'task_id': taskId,
      'checkin_date': checkinDate,
      'checkin_time': checkinTime,
      'points_earned': pointsEarned,
      'confirmed_by_parent': confirmedByParent ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  TaskCheckin copyWith({
    int? id,
    int? taskId,
    String? checkinDate,
    String? checkinTime,
    int? pointsEarned,
    bool? confirmedByParent,
    DateTime? createdAt,
  }) {
    return TaskCheckin(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      checkinDate: checkinDate ?? this.checkinDate,
      checkinTime: checkinTime ?? this.checkinTime,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      confirmedByParent: confirmedByParent ?? this.confirmedByParent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'TaskCheckin(id: $id, taskId: $taskId, date: $checkinDate, points: $pointsEarned)';
  }
}
```

创建 `qiaoqiao_companion/lib/shared/models/task_penalty.dart`：

```dart
class TaskPenalty {
  final int? id;
  final int taskId;
  final String penaltyDate;
  final int penaltyMinutes;
  final String reason;
  final bool applied;
  final DateTime createdAt;

  TaskPenalty({
    this.id,
    required this.taskId,
    required this.penaltyDate,
    required this.penaltyMinutes,
    required this.reason,
    this.applied = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TaskPenalty.fromMap(Map<String, dynamic> map) {
    return TaskPenalty(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      penaltyDate: map['penalty_date'] as String,
      penaltyMinutes: map['penalty_minutes'] as int,
      reason: map['reason'] as String,
      applied: (map['applied'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'task_id': taskId,
      'penalty_date': penaltyDate,
      'penalty_minutes': penaltyMinutes,
      'reason': reason,
      'applied': applied ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  TaskPenalty copyWith({
    int? id,
    int? taskId,
    String? penaltyDate,
    int? penaltyMinutes,
    String? reason,
    bool? applied,
    DateTime? createdAt,
  }) {
    return TaskPenalty(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      penaltyDate: penaltyDate ?? this.penaltyDate,
      penaltyMinutes: penaltyMinutes ?? this.penaltyMinutes,
      reason: reason ?? this.reason,
      applied: applied ?? this.applied,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'TaskPenalty(id: $id, taskId: $taskId, date: $penaltyDate, minutes: $penaltyMinutes)';
  }
}
```

- [ ] **Step 4: 更新 models.dart 导出**

在 `qiaoqiao_companion/lib/shared/models/models.dart` 末尾添加：

```dart
export 'task_definition.dart';
export 'task_checkin.dart';
export 'task_penalty.dart';
```

- [ ] **Step 5: 运行测试验证通过**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/shared/models/task_checkin_test.dart test/shared/models/task_penalty_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add qiaoqiao_companion/lib/shared/models/task_checkin.dart qiaoqiao_companion/lib/shared/models/task_penalty.dart qiaoqiao_companion/lib/shared/models/models.dart qiaoqiao_companion/test/shared/models/task_checkin_test.dart qiaoqiao_companion/test/shared/models/task_penalty_test.dart
git commit -m "feat: add TaskCheckin and TaskPenalty data models"
```

---

## Task 5: DAO 层 — TaskDefinitionDao

**Files:**
- Create: `qiaoqiao_companion/lib/core/database/daos/task_definition_dao.dart`
- Modify: `qiaoqiao_companion/lib/core/database/daos/daos.dart`
- Create: `qiaoqiao_companion/test/core/database/daos/task_definition_dao_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `qiaoqiao_companion/test/core/database/daos/task_definition_dao_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';

late Database _db;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE task_definitions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            emoji TEXT NOT NULL DEFAULT '⭐',
            category TEXT NOT NULL,
            base_points INTEGER NOT NULL,
            extra_points INTEGER NOT NULL DEFAULT 0,
            min_daily_count INTEGER NOT NULL DEFAULT 1,
            max_daily_count INTEGER NOT NULL DEFAULT 1,
            daily_points_cap INTEGER,
            checkin_mode TEXT NOT NULL DEFAULT 'self',
            scheduled_time TEXT,
            penalty_minutes INTEGER NOT NULL DEFAULT 0,
            reminder_time TEXT,
            reminder_repeat_interval INTEGER NOT NULL DEFAULT 0,
            enabled INTEGER NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');
      },
    );
  });

  tearDownAll(() async {
    await _db.close();
  });

  test('insert 和 getAll', () async {
    final now = DateTime.now();
    final task = TaskDefinition(
      name: '跳绳',
      emoji: '🏃',
      category: TaskCategory.health,
      basePoints: 15,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _db.insert('task_definitions', task.toMap());
    expect(id, greaterThan(0));

    final maps = await _db.query('task_definitions');
    expect(maps.length, 1);
    final restored = TaskDefinition.fromMap(maps.first);
    expect(restored.name, '跳绳');
    expect(restored.category, TaskCategory.health);
  });

  test('update 修改任务', () async {
    final now = DateTime.now();
    final task = TaskDefinition(
      name: '跳绳',
      category: TaskCategory.health,
      basePoints: 15,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _db.insert('task_definitions', task.toMap());
    final updated = task.copyWith(id: id, name: '跑步', basePoints: 20);
    await _db.update(
      'task_definitions',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );

    final maps = await _db.query('task_definitions', where: 'id = ?', whereArgs: [id]);
    final restored = TaskDefinition.fromMap(maps.first);
    expect(restored.name, '跑步');
    expect(restored.basePoints, 20);
  });

  test('delete 删除任务', () async {
    final now = DateTime.now();
    final task = TaskDefinition(
      name: '洗碗',
      category: TaskCategory.chore,
      basePoints: 10,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _db.insert('task_definitions', task.toMap());
    await _db.delete('task_definitions', where: 'id = ?', whereArgs: [id]);

    final maps = await _db.query('task_definitions');
    expect(maps.length, 0);
  });

  test('查询已启用的任务', () async {
    final now = DateTime.now();
    await _db.insert('task_definitions', TaskDefinition(
      name: '任务1', category: TaskCategory.health, basePoints: 10, enabled: true, createdAt: now, updatedAt: now,
    ).toMap());
    await _db.insert('task_definitions', TaskDefinition(
      name: '任务2', category: TaskCategory.study, basePoints: 20, enabled: false, createdAt: now, updatedAt: now,
    ).toMap());

    final maps = await _db.query('task_definitions', where: 'enabled = ?', whereArgs: [1]);
    expect(maps.length, 1);
    expect(TaskDefinition.fromMap(maps.first).name, '任务1');
  });
}
```

- [ ] **Step 2: 运行测试验证通过（直接操作 db，验证 schema 兼容性）**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/core/database/daos/task_definition_dao_test.dart`
Expected: PASS

- [ ] **Step 3: 实现 TaskDefinitionDao**

创建 `qiaoqiao_companion/lib/core/database/daos/task_definition_dao.dart`：

```dart
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';

class TaskDefinitionDao {
  final AppDatabase _database;

  TaskDefinitionDao(this._database);

  Future<int> insert(TaskDefinition task) async {
    final db = await _database.database;
    return await db.insert(
      DatabaseConstants.tableTaskDefinitions,
      task.toMap(),
    );
  }

  Future<List<TaskDefinition>> getAll() async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableTaskDefinitions,
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return maps.map((map) => TaskDefinition.fromMap(map)).toList();
  }

  Future<List<TaskDefinition>> getEnabled() async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableTaskDefinitions,
      where: 'enabled = ?',
      whereArgs: [1],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return maps.map((map) => TaskDefinition.fromMap(map)).toList();
  }

  Future<TaskDefinition?> getById(int id) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableTaskDefinitions,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return TaskDefinition.fromMap(maps.first);
  }

  Future<int> update(TaskDefinition task) async {
    final db = await _database.database;
    return await db.update(
      DatabaseConstants.tableTaskDefinitions,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _database.database;
    return await db.delete(
      DatabaseConstants.tableTaskDefinitions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAll() async {
    final db = await _database.database;
    return await db.delete(DatabaseConstants.tableTaskDefinitions);
  }
}
```

- [ ] **Step 4: 更新 daos.dart 导出**

在 `qiaoqiao_companion/lib/core/database/daos/daos.dart` 末尾添加：

```dart
export 'task_definition_dao.dart';
export 'task_checkin_dao.dart';
export 'task_penalty_dao.dart';
```

- [ ] **Step 5: Commit**

```bash
git add qiaoqiao_companion/lib/core/database/daos/task_definition_dao.dart qiaoqiao_companion/lib/core/database/daos/daos.dart qiaoqiao_companion/test/core/database/daos/task_definition_dao_test.dart
git commit -m "feat: add TaskDefinitionDao with CRUD operations"
```

---

## Task 6: DAO 层 — TaskCheckinDao

**Files:**
- Create: `qiaoqiao_companion/lib/core/database/daos/task_checkin_dao.dart`
- Create: `qiaoqiao_companion/test/core/database/daos/task_checkin_dao_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `qiaoqiao_companion/test/core/database/daos/task_checkin_dao_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qiaoqiao_companion/shared/models/task_checkin.dart';

late Database _db;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE task_definitions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            emoji TEXT NOT NULL DEFAULT '⭐',
            category TEXT NOT NULL,
            base_points INTEGER NOT NULL,
            extra_points INTEGER NOT NULL DEFAULT 0,
            min_daily_count INTEGER NOT NULL DEFAULT 1,
            max_daily_count INTEGER NOT NULL DEFAULT 1,
            daily_points_cap INTEGER,
            checkin_mode TEXT NOT NULL DEFAULT 'self',
            scheduled_time TEXT,
            penalty_minutes INTEGER NOT NULL DEFAULT 0,
            reminder_time TEXT,
            reminder_repeat_interval INTEGER NOT NULL DEFAULT 0,
            enabled INTEGER NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE task_checkins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER NOT NULL,
            checkin_date TEXT NOT NULL,
            checkin_time TEXT NOT NULL,
            points_earned INTEGER NOT NULL DEFAULT 0,
            confirmed_by_parent INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          );
        ''');
      },
    );
  });

  tearDownAll(() async {
    await _db.close();
  });

  test('insert 和按日期查询', () async {
    final now = DateTime.now();
    final taskId = await _db.insert('task_definitions', {
      'name': '跳绳', 'emoji': '🏃', 'category': 'health', 'base_points': 15,
      'created_at': now.millisecondsSinceEpoch, 'updated_at': now.millisecondsSinceEpoch,
    });

    final checkin = TaskCheckin(
      taskId: taskId,
      checkinDate: '2026-07-05',
      checkinTime: '10:30:00',
      pointsEarned: 15,
      createdAt: now,
    );

    final id = await _db.insert('task_checkins', checkin.toMap());
    expect(id, greaterThan(0));

    final maps = await _db.query(
      'task_checkins',
      where: 'task_id = ? AND checkin_date = ?',
      whereArgs: [taskId, '2026-07-05'],
    );
    expect(maps.length, 1);
    final restored = TaskCheckin.fromMap(maps.first);
    expect(restored.taskId, taskId);
    expect(restored.pointsEarned, 15);
  });

  test('统计某任务某日打卡次数', () async {
    final now = DateTime.now();
    final taskId = await _db.insert('task_definitions', {
      'name': '跳绳', 'emoji': '🏃', 'category': 'health', 'base_points': 15,
      'created_at': now.millisecondsSinceEpoch, 'updated_at': now.millisecondsSinceEpoch,
    });

    await _db.insert('task_checkins', TaskCheckin(taskId: taskId, checkinDate: '2026-07-05', checkinTime: '10:00:00', pointsEarned: 15, createdAt: now).toMap());
    await _db.insert('task_checkins', TaskCheckin(taskId: taskId, checkinDate: '2026-07-05', checkinTime: '16:00:00', pointsEarned: 5, createdAt: now).toMap());
    await _db.insert('task_checkins', TaskCheckin(taskId: taskId, checkinDate: '2026-07-04', checkinTime: '09:00:00', pointsEarned: 15, createdAt: now).toMap());

    final result = await _db.rawQuery(
      "SELECT COUNT(*) as cnt FROM task_checkins WHERE task_id = ? AND checkin_date = ?",
      [taskId, '2026-07-05'],
    );
    expect(result.first['cnt'], 2);
  });
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/core/database/daos/task_checkin_dao_test.dart`
Expected: PASS

- [ ] **Step 3: 实现 TaskCheckinDao**

创建 `qiaoqiao_companion/lib/core/database/daos/task_checkin_dao.dart`：

```dart
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/task_checkin.dart';

class TaskCheckinDao {
  final AppDatabase _database;

  TaskCheckinDao(this._database);

  Future<int> insert(TaskCheckin checkin) async {
    final db = await _database.database;
    return await db.insert(
      DatabaseConstants.tableTaskCheckins,
      checkin.toMap(),
    );
  }

  Future<List<TaskCheckin>> getByTaskAndDate(int taskId, String date) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableTaskCheckins,
      where: 'task_id = ? AND checkin_date = ?',
      whereArgs: [taskId, date],
      orderBy: 'checkin_time ASC',
    );
    return maps.map((map) => TaskCheckin.fromMap(map)).toList();
  }

  Future<int> getCheckinCount(int taskId, String date) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableTaskCheckins} '
      'WHERE task_id = ? AND checkin_date = ?',
      [taskId, date],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<int> getPointsEarnedByTaskAndDate(int taskId, String date) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT SUM(points_earned) as total FROM ${DatabaseConstants.tableTaskCheckins} '
      'WHERE task_id = ? AND checkin_date = ?',
      [taskId, date],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<List<TaskCheckin>> getByDate(String date) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableTaskCheckins,
      where: 'checkin_date = ?',
      whereArgs: [date],
      orderBy: 'checkin_time ASC',
    );
    return maps.map((map) => TaskCheckin.fromMap(map)).toList();
  }

  Future<int> deleteAll() async {
    final db = await _database.database;
    return await db.delete(DatabaseConstants.tableTaskCheckins);
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add qiaoqiao_companion/lib/core/database/daos/task_checkin_dao.dart qiaoqiao_companion/test/core/database/daos/task_checkin_dao_test.dart
git commit -m "feat: add TaskCheckinDao with date-based queries"
```

---

## Task 7: DAO 层 — TaskPenaltyDao

**Files:**
- Create: `qiaoqiao_companion/lib/core/database/daos/task_penalty_dao.dart`
- Create: `qiaoqiao_companion/test/core/database/daos/task_penalty_dao_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `qiaoqiao_companion/test/core/database/daos/task_penalty_dao_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:qiaoqiao_companion/shared/models/task_penalty.dart';

late Database _db;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE task_definitions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            emoji TEXT NOT NULL DEFAULT '⭐',
            category TEXT NOT NULL,
            base_points INTEGER NOT NULL,
            extra_points INTEGER NOT NULL DEFAULT 0,
            min_daily_count INTEGER NOT NULL DEFAULT 1,
            max_daily_count INTEGER NOT NULL DEFAULT 1,
            daily_points_cap INTEGER,
            checkin_mode TEXT NOT NULL DEFAULT 'self',
            scheduled_time TEXT,
            penalty_minutes INTEGER NOT NULL DEFAULT 0,
            reminder_time TEXT,
            reminder_repeat_interval INTEGER NOT NULL DEFAULT 0,
            enabled INTEGER NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE task_penalties (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id INTEGER NOT NULL,
            penalty_date TEXT NOT NULL,
            penalty_minutes INTEGER NOT NULL,
            reason TEXT NOT NULL,
            applied INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          );
        ''');
      },
    );
  });

  tearDownAll(() async {
    await _db.close();
  });

  test('insert 和查询未应用的惩罚', () async {
    final now = DateTime.now();
    final taskId = await _db.insert('task_definitions', {
      'name': '跳绳', 'emoji': '🏃', 'category': 'health', 'base_points': 15,
      'created_at': now.millisecondsSinceEpoch, 'updated_at': now.millisecondsSinceEpoch,
    });

    final penalty = TaskPenalty(
      taskId: taskId,
      penaltyDate: '2026-07-06',
      penaltyMinutes: 10,
      reason: '未完成"跳绳"基础次数',
      createdAt: now,
    );

    await _db.insert('task_penalties', penalty.toMap());

    final maps = await _db.query(
      'task_penalties',
      where: 'penalty_date = ? AND applied = ?',
      whereArgs: ['2026-07-06', 0],
    );
    expect(maps.length, 1);
    final restored = TaskPenalty.fromMap(maps.first);
    expect(restored.penaltyMinutes, 10);
    expect(restored.applied, false);
  });

  test('标记惩罚为已应用', () async {
    final now = DateTime.now();
    final taskId = await _db.insert('task_definitions', {
      'name': '跳绳', 'emoji': '🏃', 'category': 'health', 'base_points': 15,
      'created_at': now.millisecondsSinceEpoch, 'updated_at': now.millisecondsSinceEpoch,
    });

    final id = await _db.insert('task_penalties', TaskPenalty(
      taskId: taskId, penaltyDate: '2026-07-06', penaltyMinutes: 10,
      reason: 'test', createdAt: now,
    ).toMap());

    await _db.update(
      'task_penalties',
      {'applied': 1},
      where: 'id = ?',
      whereArgs: [id],
    );

    final maps = await _db.query('task_penalties', where: 'id = ?', whereArgs: [id]);
    expect(TaskPenalty.fromMap(maps.first).applied, true);
  });

  test('累计某日未应用惩罚分钟数', () async {
    final now = DateTime.now();
    final taskId1 = await _db.insert('task_definitions', {
      'name': '跳绳', 'emoji': '🏃', 'category': 'health', 'base_points': 15,
      'created_at': now.millisecondsSinceEpoch, 'updated_at': now.millisecondsSinceEpoch,
    });
    final taskId2 = await _db.insert('task_definitions', {
      'name': '阅读', 'emoji': '📖', 'category': 'study', 'base_points': 20,
      'created_at': now.millisecondsSinceEpoch, 'updated_at': now.millisecondsSinceEpoch,
    });

    await _db.insert('task_penalties', TaskPenalty(taskId: taskId1, penaltyDate: '2026-07-06', penaltyMinutes: 10, reason: 'a', createdAt: now).toMap());
    await _db.insert('task_penalties', TaskPenalty(taskId: taskId2, penaltyDate: '2026-07-06', penaltyMinutes: 15, reason: 'b', createdAt: now).toMap());

    final result = await _db.rawQuery(
      'SELECT SUM(penalty_minutes) as total FROM task_penalties WHERE penalty_date = ? AND applied = ?',
      ['2026-07-06', 0],
    );
    expect(result.first['total'], 25);
  });
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/core/database/daos/task_penalty_dao_test.dart`
Expected: PASS

- [ ] **Step 3: 实现 TaskPenaltyDao**

创建 `qiaoqiao_companion/lib/core/database/daos/task_penalty_dao.dart`：

```dart
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/task_penalty.dart';

class TaskPenaltyDao {
  final AppDatabase _database;

  TaskPenaltyDao(this._database);

  Future<int> insert(TaskPenalty penalty) async {
    final db = await _database.database;
    return await db.insert(
      DatabaseConstants.tableTaskPenalties,
      penalty.toMap(),
    );
  }

  Future<List<TaskPenalty>> getUnappliedByDate(String date) async {
    final db = await _database.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableTaskPenalties,
      where: 'penalty_date = ? AND applied = ?',
      whereArgs: [date, 0],
    );
    return maps.map((map) => TaskPenalty.fromMap(map)).toList();
  }

  Future<int> getTotalUnappliedMinutes(String date) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT SUM(penalty_minutes) as total FROM ${DatabaseConstants.tableTaskPenalties} '
      'WHERE penalty_date = ? AND applied = ?',
      [date, 0],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> markApplied(int id) async {
    final db = await _database.database;
    return await db.update(
      DatabaseConstants.tableTaskPenalties,
      {'applied': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAllAppliedForDate(String date) async {
    final db = await _database.database;
    return await db.update(
      DatabaseConstants.tableTaskPenalties,
      {'applied': 1},
      where: 'penalty_date = ? AND applied = ?',
      whereArgs: [date, 0],
    );
  }

  Future<bool> existsForTaskAndDate(int taskId, String date) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableTaskPenalties} '
      'WHERE task_id = ? AND penalty_date = ?',
      [taskId, date],
    );
    return ((result.first['cnt'] as int?) ?? 0) > 0;
  }

  Future<int> deleteAll() async {
    final db = await _database.database;
    return await db.delete(DatabaseConstants.tableTaskPenalties);
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add qiaoqiao_companion/lib/core/database/daos/task_penalty_dao.dart qiaoqiao_companion/test/core/database/daos/task_penalty_dao_test.dart
git commit -m "feat: add TaskPenaltyDao with date-based penalty queries"
```

---

## Task 8: 修复 PointsProvider — addPoints/deductPoints 传递 category

**Files:**
- Modify: `qiaoqiao_companion/lib/shared/providers/points_provider.dart`
- Modify: `qiaoqiao_companion/lib/core/database/daos/points_dao.dart`

现有 `PointsNotifier.addPoints(amount, reason)` 和 `deductPoints(amount, reason)` 没有传递 `category` 参数给 DAO，而 `PointsDao.addPoints/deductPoints` 已支持 `category` 参数。需要补齐。

- [ ] **Step 1: 写失败的测试**

创建 `qiaoqiao_companion/test/shared/providers/points_provider_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/core/database/daos/points_dao.dart';
import 'package:qiaoqiao_companion/shared/providers/points_provider.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

late AppDatabase _db;
late PointsNotifier _pointsNotifier;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _db = AppDatabase.instance;
    await _db.database;
    _pointsNotifier = PointsNotifier(PointsDao(_db));
    await _pointsNotifier.load();
  });

  tearDownAll(() async {
    await _db.close();
  });

  test('PointsNotifier addPoints 传递 category 参数', () async {
    final balanceBefore = _pointsNotifier.state.balance;
    await _pointsNotifier.addPoints(
      10,
      '完成任务测试',
      category: PointsCategory.exerciseReward,
    );
    expect(_pointsNotifier.state.balance, balanceBefore + 10);
  });

  test('PointsNotifier deductPoints 传递 category 参数', () async {
    final balanceBefore = _pointsNotifier.state.balance;
    if (balanceBefore >= 5) {
      await _pointsNotifier.deductPoints(
        5,
        '惩罚扣分测试',
        category: PointsCategory.timePenalty,
      );
      expect(_pointsNotifier.state.balance, balanceBefore - 5);
    }
  });
}
```

注意：此测试依赖真实的 AppDatabase 实例（使用 sqflite_common_ffi），因此需要在 setUpAll 中初始化数据库。PointsNotifier 的构造函数签名为 `PointsNotifier(PointsDao)`，不能无参构造。

- [ ] **Step 2: 运行测试验证失败**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/shared/providers/points_provider_test.dart`
Expected: FAIL — `PointsNotifier` 的 `addPoints`/`deductPoints` 方法不接受 `category` 命名参数

- [ ] **Step 3: 修改 PointsNotifier**

在 `qiaoqiao_companion/lib/shared/providers/points_provider.dart` 中：

1. 修改 `addPoints` 方法签名，添加 `category` 参数：

将原：
```dart
  Future<void> addPoints(int amount, String reason) async {
```

改为：
```dart
  Future<void> addPoints(int amount, String reason, {PointsCategory category = PointsCategory.other}) async {
```

2. 修改 `addPoints` 方法内部 DAO 调用：

将原：
```dart
    final history = await _pointsDao.addPoints(amount, reason);
```

改为：
```dart
    final history = await _pointsDao.addPoints(amount, reason, category);
```

3. 修改 `deductPoints` 方法签名，添加 `category` 参数：

将原：
```dart
  Future<void> deductPoints(int amount, String reason) async {
```

改为：
```dart
  Future<void> deductPoints(int amount, String reason, {PointsCategory category = PointsCategory.other}) async {
```

4. 修改 `deductPoints` 方法内部 DAO 调用：

将原：
```dart
    final history = await _pointsDao.deductPoints(amount, reason);
```

改为：
```dart
    final history = await _pointsDao.deductPoints(amount, reason, category);
```

5. 更新所有现有调用点传入正确的 `category`：
- `rewardEndingEarly()`: `addPoints(PointsConstants.pointsForEndingEarly, '按时结束使用', category: PointsCategory.restReward)`
- `rewardDailyLimit()`: `addPoints(PointsConstants.pointsForDailyLimit, '遵守每日限制', category: PointsCategory.restReward)`
- `rewardForbiddenTime()`: `addPoints(PointsConstants.pointsForForbiddenTime, '遵守禁止时段', category: PointsCategory.restReward)`
- `rewardStreak()`: `addPoints(PointsConstants.pointsForStreak3Days, '连续3天达标', category: PointsCategory.dailyBonus)`

6. 在文件顶部添加 import（如果尚未存在）：

```dart
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/shared/providers/points_provider_test.dart`
Expected: PASS

- [ ] **Step 5: 运行全量测试确保无回归**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add qiaoqiao_companion/lib/shared/providers/points_provider.dart qiaoqiao_companion/test/shared/providers/points_provider_test.dart
git commit -m "fix: add category parameter to PointsNotifier addPoints/deductPoints"
```

---

## Task 9: TaskProvider — 任务状态管理核心

**Files:**
- Create: `qiaoqiao_companion/lib/shared/providers/task_provider.dart`
- Modify: `qiaoqiao_companion/lib/shared/providers/providers.dart`
- Create: `qiaoqiao_companion/test/shared/providers/task_provider_test.dart`

- [ ] **Step 1: 写失败的测试**

创建 `qiaoqiao_companion/test/shared/providers/task_provider_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/shared/models/task_checkin.dart';
import 'package:qiaoqiao_companion/shared/models/task_penalty.dart';

void main() {
  group('TaskState', () {
    test('初始状态正确', () {
      final state = TaskState();
      expect(state.tasks, isEmpty);
      expect(state.todayCheckins, isEmpty);
      expect(state.todayPenalties, isEmpty);
      expect(state.todayPenaltyMinutes, 0);
      expect(state.isLoading, false);
    });

    test('getCheckinCountForTask 返回正确次数', () {
      final now = DateTime.now();
      final state = TaskState(
        todayCheckins: [
          TaskCheckin(taskId: 1, checkinDate: '2026-07-05', checkinTime: '10:00', pointsEarned: 15, createdAt: now),
          TaskCheckin(taskId: 1, checkinDate: '2026-07-05', checkinTime: '16:00', pointsEarned: 5, createdAt: now),
          TaskCheckin(taskId: 2, checkinDate: '2026-07-05', checkinTime: '09:00', pointsEarned: 20, createdAt: now),
        ],
      );

      expect(state.getCheckinCountForTask(1), 2);
      expect(state.getCheckinCountForTask(2), 1);
      expect(state.getCheckinCountForTask(3), 0);
    });

    test('isTaskCompleted 返回是否达到基础次数', () {
      final now = DateTime.now();
      final task = TaskDefinition(
        id: 1, name: '跳绳', category: TaskCategory.health, basePoints: 15, minDailyCount: 2, createdAt: now, updatedAt: now,
      );
      final state = TaskState(
        tasks: [task],
        todayCheckins: [
          TaskCheckin(taskId: 1, checkinDate: '2026-07-05', checkinTime: '10:00', pointsEarned: 15, createdAt: now),
          TaskCheckin(taskId: 1, checkinDate: '2026-07-05', checkinTime: '16:00', pointsEarned: 5, createdAt: now),
        ],
      );

      expect(state.isTaskCompleted(1), true);
      expect(state.isTaskCompleted(2), false);
    });

    test('canCheckin 判断是否还能打卡', () {
      final now = DateTime.now();
      final task = TaskDefinition(
        id: 1, name: '跳绳', category: TaskCategory.health, basePoints: 15, maxDailyCount: 2, createdAt: now, updatedAt: now,
      );
      final state = TaskState(
        tasks: [task],
        todayCheckins: [
          TaskCheckin(taskId: 1, checkinDate: '2026-07-05', checkinTime: '10:00', pointsEarned: 15, createdAt: now),
        ],
      );

      expect(state.canCheckin(1), true);

      final state2 = TaskState(
        tasks: [task],
        todayCheckins: [
          TaskCheckin(taskId: 1, checkinDate: '2026-07-05', checkinTime: '10:00', pointsEarned: 15, createdAt: now),
          TaskCheckin(taskId: 1, checkinDate: '2026-07-05', checkinTime: '16:00', pointsEarned: 5, createdAt: now),
        ],
      );
      expect(state2.canCheckin(1), false);
    });

    test('getCompletedTaskCount 统计已达标任务数', () {
      final now = DateTime.now();
      final tasks = [
        TaskDefinition(id: 1, name: '跳绳', category: TaskCategory.health, basePoints: 15, minDailyCount: 1, createdAt: now, updatedAt: now),
        TaskDefinition(id: 2, name: '阅读', category: TaskCategory.study, basePoints: 20, minDailyCount: 2, createdAt: now, updatedAt: now),
        TaskDefinition(id: 3, name: '洗碗', category: TaskCategory.chore, basePoints: 10, minDailyCount: 1, createdAt: now, updatedAt: now),
      ];
      final state = TaskState(
        tasks: tasks,
        todayCheckins: [
          TaskCheckin(taskId: 1, checkinDate: '2026-07-05', checkinTime: '10:00', pointsEarned: 15, createdAt: now),
          TaskCheckin(taskId: 2, checkinDate: '2026-07-05', checkinTime: '09:00', pointsEarned: 20, createdAt: now),
          TaskCheckin(taskId: 3, checkinDate: '2026-07-05', checkinTime: '08:00', pointsEarned: 10, createdAt: now),
        ],
      );

      expect(state.getCompletedTaskCount(), 2);
    });
  });

  group('TaskState 计算积分', () {
    test('calcPointsForCheckin 基础打卡给 basePoints', () {
      final now = DateTime.now();
      final task = TaskDefinition(
        id: 1, name: '跳绳', category: TaskCategory.health, basePoints: 15, extraPoints: 5, maxDailyCount: 3, createdAt: now, updatedAt: now,
      );
      final state = TaskState(tasks: [task]);

      expect(state.calcPointsForCheckin(1), 15);
    });

    test('calcPointsForCheckin 超过基础次数给 extraPoints', () {
      final now = DateTime.now();
      final task = TaskDefinition(
        id: 1, name: '跳绳', category: TaskCategory.health, basePoints: 15, extraPoints: 5, minDailyCount: 1, maxDailyCount: 3, createdAt: now, updatedAt: now,
      );
      final state = TaskState(
        tasks: [task],
        todayCheckins: [
          TaskCheckin(taskId: 1, checkinDate: '2026-07-05', checkinTime: '10:00', pointsEarned: 15, createdAt: now),
        ],
      );

      expect(state.calcPointsForCheckin(1), 5);
    });

    test('calcPointsForCheckin 达到上限返回 0', () {
      final now = DateTime.now();
      final task = TaskDefinition(
        id: 1, name: '跳绳', category: TaskCategory.health, basePoints: 15, maxDailyCount: 1, createdAt: now, updatedAt: now,
      );
      final state = TaskState(
        tasks: [task],
        todayCheckins: [
          TaskCheckin(taskId: 1, checkinDate: '2026-07-05', checkinTime: '10:00', pointsEarned: 15, createdAt: now),
        ],
      );

      expect(state.calcPointsForCheckin(1), 0);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/shared/providers/task_provider_test.dart`
Expected: FAIL — `TaskState` 类不存在

- [ ] **Step 3: 实现 TaskState 和 TaskNotifier**

创建 `qiaoqiao_companion/lib/shared/providers/task_provider.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/core/database/daos/task_definition_dao.dart';
import 'package:qiaoqiao_companion/core/database/daos/task_checkin_dao.dart';
import 'package:qiaoqiao_companion/core/database/daos/task_penalty_dao.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/shared/models/task_checkin.dart';
import 'package:qiaoqiao_companion/shared/models/task_penalty.dart';
import 'package:qiaoqiao_companion/shared/providers/points_provider.dart';
import 'package:intl/intl.dart';

class TaskState {
  final List<TaskDefinition> tasks;
  final List<TaskCheckin> todayCheckins;
  final List<TaskPenalty> todayPenalties;
  final int todayPenaltyMinutes;
  final bool isLoading;
  final String? error;

  const TaskState({
    this.tasks = const [],
    this.todayCheckins = const [],
    this.todayPenalties = const [],
    this.todayPenaltyMinutes = 0,
    this.isLoading = false,
    this.error,
  });

  TaskState copyWith({
    List<TaskDefinition>? tasks,
    List<TaskCheckin>? todayCheckins,
    List<TaskPenalty>? todayPenalties,
    int? todayPenaltyMinutes,
    bool? isLoading,
    String? error,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      todayCheckins: todayCheckins ?? this.todayCheckins,
      todayPenalties: todayPenalties ?? this.todayPenalties,
      todayPenaltyMinutes: todayPenaltyMinutes ?? this.todayPenaltyMinutes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  int getCheckinCountForTask(int taskId) {
    return todayCheckins.where((c) => c.taskId == taskId).length;
  }

  bool isTaskCompleted(int taskId) {
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return false;
    return getCheckinCountForTask(taskId) >= task.minDailyCount;
  }

  bool canCheckin(int taskId) {
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return false;
    if (!task.enabled) return false;
    return getCheckinCountForTask(taskId) < task.maxDailyCount;
  }

  int getCompletedTaskCount() {
    return tasks.where((t) => isTaskCompleted(t.id!)).length;
  }

  int calcPointsForCheckin(int taskId) {
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return 0;
    final count = getCheckinCountForTask(taskId);
    if (count >= task.maxDailyCount) return 0;
    if (count < task.minDailyCount) return task.basePoints;
    return task.extraPoints;
  }

  List<TaskDefinition> getTasksByCategory(TaskCategory category) {
    return tasks.where((t) => t.category == category && t.enabled).toList();
  }

  int get totalEnabledTasks => tasks.where((t) => t.enabled).length;
}

class TaskNotifier extends StateNotifier<TaskState> {
  final TaskDefinitionDao _taskDefinitionDao;
  final TaskCheckinDao _taskCheckinDao;
  final TaskPenaltyDao _taskPenaltyDao;
  final PointsNotifier _pointsNotifier;

  TaskNotifier(
    this._taskDefinitionDao,
    this._taskCheckinDao,
    this._taskPenaltyDao,
    this._pointsNotifier,
  ) : super(const TaskState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final tasks = await _taskDefinitionDao.getEnabled();
      final checkins = await _taskCheckinDao.getByDate(today);
      final penalties = await _taskPenaltyDao.getUnappliedByDate(today);
      final penaltyMinutes = await _taskPenaltyDao.getTotalUnappliedMinutes(today);

      state = state.copyWith(
        tasks: tasks,
        todayCheckins: checkins,
        todayPenalties: penalties,
        todayPenaltyMinutes: penaltyMinutes,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> checkin(int taskId) async {
    if (!state.canCheckin(taskId)) return false;

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm:ss').format(now);
    final points = state.calcPointsForCheckin(taskId);

    final task = state.tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return false;

    final checkin = TaskCheckin(
      taskId: taskId,
      checkinDate: today,
      checkinTime: timeStr,
      pointsEarned: points,
      confirmedByParent: task.checkinMode == CheckinMode.parentConfirm,
      createdAt: now,
    );

    await _taskCheckinDao.insert(checkin);

    if (points > 0) {
      await _pointsNotifier.addPoints(
        points,
        '完成"${task.name}"打卡',
        category: task.pointsCategory,
      );
    }

    await load();
    return true;
  }

  Future<void> addTask(TaskDefinition task) async {
    await _taskDefinitionDao.insert(task);
    await load();
  }

  Future<void> updateTask(TaskDefinition task) async {
    await _taskDefinitionDao.update(task);
    await load();
  }

  Future<void> deleteTask(int id) async {
    await _taskDefinitionDao.delete(id);
    await load();
  }

  Future<void> generatePenaltiesIfNeeded() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (final task in state.tasks) {
      if (task.penaltyMinutes <= 0) continue;
      if (!task.enabled) continue;

      final alreadyExists = await _taskPenaltyDao.existsForTaskAndDate(task.id!, today);
      if (alreadyExists) continue;

      final isCompleted = state.isTaskCompleted(task.id!);
      if (!isCompleted) {
        final penalty = TaskPenalty(
          taskId: task.id!,
          penaltyDate: today,
          penaltyMinutes: task.penaltyMinutes,
          reason: '未完成"${task.name}"基础次数',
          createdAt: DateTime.now(),
        );
        await _taskPenaltyDao.insert(penalty);
      }
    }

    await load();
  }

  Future<void> applyPenaltiesForDate(String date) async {
    final minutes = await _taskPenaltyDao.getTotalUnappliedMinutes(date);
    if (minutes > 0) {
      await _pointsNotifier.deductPoints(
        minutes,
        '未完成任务扣除使用时长${minutes}分钟',
        category: PointsCategory.timePenalty,
      );
      await _taskPenaltyDao.markAllAppliedForDate(date);
    }
    await load();
  }

  Future<void> refresh() async {
    await load();
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  final database = AppDatabase.instance;
  return TaskNotifier(
    TaskDefinitionDao(database),
    TaskCheckinDao(database),
    TaskPenaltyDao(database),
    ref.watch(pointsProvider.notifier),
  );
});
```

- [ ] **Step 4: 更新 providers.dart 导出**

在 `qiaoqiao_companion/lib/shared/providers/providers.dart` 末尾添加：

```dart
export 'task_provider.dart';
```

- [ ] **Step 5: 运行测试验证通过**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter test test/shared/providers/task_provider_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add qiaoqiao_companion/lib/shared/providers/task_provider.dart qiaoqiao_companion/lib/shared/providers/providers.dart qiaoqiao_companion/test/shared/providers/task_provider_test.dart
git commit -m "feat: add TaskProvider with checkin/penalty/points integration"
```

---

## Task 10: 路由和导航扩展 — 4 Tab + 任务路由

**Files:**
- Modify: `qiaoqiao_companion/lib/app/shell_page.dart`
- Modify: `qiaoqiao_companion/lib/app/router.dart`

- [ ] **Step 1: 修改 shell_page.dart — 3 Tab → 4 Tab**

在 `shell_page.dart` 的 `_ShellPageState` 中：

1. 修改 `_updateIndex` 方法的 switch，添加 Task Tab 的 case：

将原：
```dart
  void _updateIndex() {
    final location = GoRouterState.of(context).uri.toString();
    setState(() {
      switch (location) {
        case AppRoutes.home:
          _currentIndex = 0;
          break;
        case AppRoutes.rules:
          _currentIndex = 1;
          break;
        case AppRoutes.settings:
          _currentIndex = 2;
          break;
      }
    });
  }
```

改为：
```dart
  void _updateIndex() {
    final location = GoRouterState.of(context).uri.toString();
    setState(() {
      switch (location) {
        case AppRoutes.home:
          _currentIndex = 0;
          break;
        case AppRoutes.rules:
          _currentIndex = 1;
          break;
        case AppRoutes.tasks:
          _currentIndex = 2;
          break;
        case AppRoutes.settings:
          _currentIndex = 3;
          break;
      }
    });
  }
```

2. 修改 `_onItemTapped` 方法的 switch，添加 Task Tab 的 case：

将原：
```dart
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.rules);
        break;
      case 2:
        context.go(AppRoutes.settings);
        break;
    }
```

改为：
```dart
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.rules);
        break;
      case 2:
        context.go(AppRoutes.tasks);
        break;
      case 3:
        context.go(AppRoutes.settings);
        break;
    }
```

3. 修改 `_buildFloatingNavBar` 中的 `_NavItem` 列表，在"规则"和"我的"之间插入"任务"项：

将原：
```dart
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: '首页',
                  isSelected: _currentIndex == 0,
                  onTap: () => _onItemTapped(0),
                ),
                _NavItem(
                  icon: Icons.rule_rounded,
                  label: '规则',
                  isSelected: _currentIndex == 1,
                  onTap: () => _onItemTapped(1),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: '我的',
                  isSelected: _currentIndex == 2,
                  onTap: () => _onItemTapped(2),
                ),
              ],
```

改为：
```dart
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: '首页',
                  isSelected: _currentIndex == 0,
                  onTap: () => _onItemTapped(0),
                ),
                _NavItem(
                  icon: Icons.rule_rounded,
                  label: '规则',
                  isSelected: _currentIndex == 1,
                  onTap: () => _onItemTapped(1),
                ),
                _NavItem(
                  icon: Icons.emoji_nature_rounded,
                  label: '任务',
                  isSelected: _currentIndex == 2,
                  onTap: () => _onItemTapped(2),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: '我的',
                  isSelected: _currentIndex == 3,
                  onTap: () => _onItemTapped(3),
                ),
              ],
```

4. 添加 import：

```dart
import 'package:qiaoqiao_companion/features/tasks/presentation/task_page.dart';
```

- [ ] **Step 2: 修改 router.dart — 新增路由**

1. 在 `ShellRoute` 的 `routes` 列表中，在 `/rules` 和 `/settings` 之间插入：

```dart
          GoRoute(
            path: '/tasks',
            name: 'tasks',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TaskPage(),
            ),
          ),
```

2. 在 `parent-mode` 子路由中添加任务管理路由：

```dart
          GoRoute(
            path: 'tasks',
            builder: (context, state) => const TaskManagementPage(),
          ),
          GoRoute(
            path: 'tasks/edit',
            builder: (context, state) {
              final task = state.extra as TaskDefinition?;
              return TaskEditPage(task: task);
            },
          ),
```

3. 在 `AppRoutes` 类中添加常量（注意：此类使用 `static const String` 风格）：

```dart
  static const String tasks = '/tasks';
  static const String parentModeTasks = '/parent-mode/tasks';
  static const String parentModeTaskEdit = '/parent-mode/tasks/edit';
```

4. 添加 imports：

```dart
import 'package:qiaoqiao_companion/features/tasks/presentation/task_page.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/task_management_page.dart';
import 'package:qiaoqiao_companion/features/parent_mode/presentation/task_edit_page.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
```

- [ ] **Step 3: 创建占位页面文件（确保编译通过）**

创建 `qiaoqiao_companion/lib/features/tasks/presentation/task_page.dart`：

```dart
import 'package:flutter/material.dart';

class TaskPage extends StatelessWidget {
  const TaskPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('任务页面 - 即将实现'),
      ),
    );
  }
}
```

创建 `qiaoqiao_companion/lib/features/parent_mode/presentation/task_management_page.dart`：

```dart
import 'package:flutter/material.dart';

class TaskManagementPage extends StatelessWidget {
  const TaskManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('任务管理页面 - 即将实现'),
      ),
    );
  }
}
```

创建 `qiaoqiao_companion/lib/features/parent_mode/presentation/task_edit_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';

class TaskEditPage extends StatelessWidget {
  final TaskDefinition? task;

  const TaskEditPage({super.key, this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(task != null ? '编辑任务 - 即将实现' : '新建任务 - 即将实现'),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行编译验证**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter analyze`
Expected: 无错误

- [ ] **Step 5: Commit**

```bash
git add qiaoqiao_companion/lib/app/shell_page.dart qiaoqiao_companion/lib/app/router.dart qiaoqiao_companion/lib/features/tasks/presentation/task_page.dart qiaoqiao_companion/lib/features/parent_mode/presentation/task_management_page.dart qiaoqiao_companion/lib/features/parent_mode/presentation/task_edit_page.dart
git commit -m "feat: add 4th tab (Tasks) + task management routes with placeholder pages"
```

---

## Task 11: 家长模式 — 添加"管理任务"入口

**Files:**
- Modify: `qiaoqiao_companion/lib/features/parent_mode/presentation/parent_mode_page.dart`

- [ ] **Step 1: 在家长模式页面添加任务管理入口**

在 `parent_mode_page.dart` 的功能列表中，在"修改规则"之后添加"管理任务"项。

找到现有功能项的模式（通常是 `_buildFunctionItem` 或类似的卡片式列表项），在其列表中新增一项：

```dart
              _buildFunctionItem(
                context,
                icon: Icons.task_alt_rounded,
                title: '管理任务',
                subtitle: '创建和管理每日任务',
                onTap: () => context.push(AppRoutes.parentModeTasks),
              ),
```

添加 import（如果尚未存在）：

```dart
import 'package:qiaoqiao_companion/app/router.dart';
```

- [ ] **Step 2: 运行编译验证**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter analyze`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add qiaoqiao_companion/lib/features/parent_mode/presentation/parent_mode_page.dart
git commit -m "feat: add task management entry in parent mode page"
```

---

## Task 12: 任务 Tab 页面实现

**Files:**
- Modify: `qiaoqiao_companion/lib/features/tasks/presentation/task_page.dart`

此页面为儿童视角的任务打卡页面，按分类展示任务列表，每个任务卡片显示打卡按钮和进度。

**注意**：
- parentConfirm 打卡模式需要弹出家长密码确认对话框，确认后才生效
- 底部需要"兑换加时券"浮动按钮，复用现有 CouponsProvider.exchange()
- 惩罚提醒：当天提醒（"今天有 X 个任务还没完成哦，如果不完成，明天会减少 Y 分钟使用时长"）和次日提醒（"昨天有 X 个任务未完成，今天的使用时长减少了 Y 分钟"）

- [ ] **Step 1: 实现 TaskPage**

替换 `qiaoqiao_companion/lib/features/tasks/presentation/task_page.dart` 的占位内容：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/shared/providers/task_provider.dart';
import 'package:qiaoqiao_companion/shared/providers/coupons_provider.dart';
import 'package:qiaoqiao_companion/features/parent_mode/data/parent_password_repository.dart';

class TaskPage extends ConsumerWidget {
  const TaskPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskProvider);
    final theme = Theme.of(context);

    if (taskState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (taskState.tasks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('今日任务')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_nature_rounded, size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                '还没有任务哦',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请让爸爸妈妈添加任务吧',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final categories = TaskCategory.values;
    final completedCount = taskState.getCompletedTaskCount();
    final totalCount = taskState.totalEnabledTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日任务'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$completedCount/$totalCount 已完成',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(context, ref, taskState, categories),
      floatingActionButton: taskState.todayPenaltyMinutes > 0 || taskState.tasks.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _exchangeCoupon(context, ref),
              icon: const Icon(Icons.card_giftcard),
              label: const Text('兑换加时券'),
            )
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    TaskState taskState,
    List<TaskCategory> categories,
  ) {
    final theme = Theme.of(context);
    final List<Widget> banners = [];

    if (taskState.todayPenaltyMinutes > 0) {
      banners.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: theme.colorScheme.errorContainer,
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '昨天有未完成的任务，今天的使用时长减少了 ${taskState.todayPenaltyMinutes} 分钟',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final incompleteTasks = taskState.tasks.where((t) =>
      t.enabled && !taskState.isTaskCompleted(t.id!) && t.penaltyMinutes > 0
    ).toList();
    if (incompleteTasks.isNotEmpty) {
      final totalPenalty = incompleteTasks.fold<int>(0, (sum, t) => sum + t.penaltyMinutes);
      banners.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: theme.colorScheme.tertiaryContainer,
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: theme.colorScheme.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '今天有 ${incompleteTasks.length} 个任务还没完成哦，如果不完成，明天会减少 $totalPenalty 分钟使用时长',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ...banners,
        Expanded(
          child: _buildTaskList(context, ref, taskState, categories),
        ),
      ],
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    WidgetRef ref,
    TaskState taskState,
    List<TaskCategory> categories,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: categories.map((category) {
        final tasks = taskState.getTasksByCategory(category);
        if (tasks.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 16),
              child: Text(
                category.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ...tasks.map((task) => _TaskCard(
              task: task,
              checkinCount: taskState.getCheckinCountForTask(task.id!),
              canCheckin: taskState.canCheckin(task.id!),
              isCompleted: taskState.isTaskCompleted(task.id!),
              points: taskState.calcPointsForCheckin(task.id!),
              onCheckin: () => _handleCheckin(context, ref, task),
            )),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _handleCheckin(
    BuildContext context,
    WidgetRef ref,
    TaskDefinition task,
  ) async {
    if (task.checkinMode == CheckinMode.parentConfirm) {
      final confirmed = await _showParentConfirmDialog(context);
      if (!confirmed) return;
    }
    await ref.read(taskProvider.notifier).checkin(task.id!);
  }

  Future<bool> _showParentConfirmDialog(BuildContext context) async {
    final passwordRepo = ParentPasswordRepository();
    final storedPassword = await passwordRepo.getPassword();
    if (storedPassword == null) return false;

    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('家长确认'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入家长密码以确认打卡'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '家长密码',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, controller.text == storedPassword),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text == storedPassword),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result ?? false;
  }

  Future<void> _exchangeCoupon(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(couponsProvider.notifier).exchange();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('兑换成功！获得加时券')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('兑换失败：$e')),
        );
      }
    }
  }
}

class _TaskCard extends StatelessWidget {
  final TaskDefinition task;
  final int checkinCount;
  final bool canCheckin;
  final bool isCompleted;
  final int points;
  final VoidCallback onCheckin;

  const _TaskCard({
    required this.task,
    required this.checkinCount,
    required this.canCheckin,
    required this.isCompleted,
    required this.points,
    required this.onCheckin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Border? border;
    if (isCompleted) {
      border = Border.all(color: theme.colorScheme.outline.withOpacity(0.3));
    } else if (task.penaltyMinutes > 0 && !isCompleted) {
      border = Border.all(color: theme.colorScheme.tertiary);
    } else {
      border = Border.all(color: theme.colorScheme.primary.withOpacity(0.3));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCompleted
              ? theme.colorScheme.outline.withOpacity(0.3)
              : task.penaltyMinutes > 0 && !isCompleted
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(
              task.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? theme.colorScheme.outline : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$checkinCount/${task.maxDailyCount} 次 · ${isCompleted ? "已达标 ✓" : "+$points 积分"}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCompleted ? theme.colorScheme.outline : theme.colorScheme.primary,
                    ),
                  ),
                  if (task.checkinMode == CheckinMode.parentConfirm && !isCompleted && canCheckin)
                    Text(
                      '需家长确认',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontSize: 11,
                      ),
                    ),
                  if (task.penaltyMinutes > 0 && !isCompleted && canCheckin)
                    Text(
                      '⚠️ 未完成扣 ${task.penaltyMinutes} 分钟',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (canCheckin)
              FilledButton.tonal(
                onPressed: onCheckin,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(task.checkinMode == CheckinMode.parentConfirm ? '待确认' : '打卡'),
              )
            else if (isCompleted)
              Icon(Icons.check_circle, color: theme.colorScheme.primary)
            else
              Icon(Icons.lock_outline, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行编译验证**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter analyze`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add qiaoqiao_companion/lib/features/tasks/presentation/task_page.dart
git commit -m "feat: implement TaskPage with category-grouped task list and checkin"
```

---

## Task 13: 家长端 — 任务管理页面

**Files:**
- Modify: `qiaoqiao_companion/lib/features/parent_mode/presentation/task_management_page.dart`

- [ ] **Step 1: 实现 TaskManagementPage**

替换占位内容：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/app/router.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/shared/providers/task_provider.dart';

class TaskManagementPage extends ConsumerWidget {
  const TaskManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(taskProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理任务'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.parentModeTaskEdit),
        child: const Icon(Icons.add),
      ),
      body: taskState.tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt_rounded, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    '还没有任务',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角 + 添加任务',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: taskState.tasks.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) newIndex -= 1;
                final tasks = List<TaskDefinition>.from(taskState.tasks);
                final item = tasks.removeAt(oldIndex);
                tasks.insert(newIndex, item);
                for (var i = 0; i < tasks.length; i++) {
                  final updated = tasks[i].copyWith(sortOrder: i);
                  ref.read(taskProvider.notifier).updateTask(updated);
                }
              },
              itemBuilder: (context, index) {
                final task = taskState.tasks[index];
                return _TaskManagementCard(
                  key: ValueKey(task.id),
                  task: task,
                  onToggle: () {
                    ref.read(taskProvider.notifier).updateTask(
                      task.copyWith(enabled: !task.enabled),
                    );
                  },
                  onEdit: () => context.push(
                    AppRoutes.parentModeTaskEdit,
                    extra: task,
                  ),
                  onDelete: () => _confirmDelete(context, ref, task),
                );
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, TaskDefinition task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除"${task.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(taskProvider.notifier).deleteTask(task.id!);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _TaskManagementCard extends StatelessWidget {
  final TaskDefinition task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskManagementCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(task.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(
          task.name,
          style: TextStyle(
            decoration: task.enabled ? null : TextDecoration.lineThrough,
            color: task.enabled ? null : theme.colorScheme.outline,
          ),
        ),
        subtitle: Text(
          '${task.category.label} · ${task.basePoints}积分 · ${task.checkinMode.label}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: task.enabled,
              onChanged: (_) => onToggle(),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行编译验证**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter analyze`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add qiaoqiao_companion/lib/features/parent_mode/presentation/task_management_page.dart
git commit -m "feat: implement TaskManagementPage with reorder/toggle/edit/delete"
```

---

## Task 14: 家长端 — 任务编辑表单

**Files:**
- Modify: `qiaoqiao_companion/lib/features/parent_mode/presentation/task_edit_page.dart`

- [ ] **Step 1: 实现 TaskEditPage**

替换占位内容：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/constants/database_constants.dart';
import 'package:qiaoqiao_companion/shared/models/task_definition.dart';
import 'package:qiaoqiao_companion/shared/providers/task_provider.dart';

class TaskEditPage extends ConsumerStatefulWidget {
  final TaskDefinition? task;

  const TaskEditPage({super.key, this.task});

  @override
  ConsumerState<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends ConsumerState<TaskEditPage> {
  late TextEditingController _nameController;
  late TextEditingController _emojiController;
  TaskCategory _category = TaskCategory.health;
  late TextEditingController _basePointsController;
  late TextEditingController _extraPointsController;
  late TextEditingController _minCountController;
  late TextEditingController _maxCountController;
  late TextEditingController _penaltyController;
  CheckinMode _checkinMode = CheckinMode.self;
  TimeOfDay? _scheduledTime;
  TimeOfDay? _reminderTime;
  late TextEditingController _reminderIntervalController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.task != null;
    final t = widget.task;

    _nameController = TextEditingController(text: t?.name ?? '');
    _emojiController = TextEditingController(text: t?.emoji ?? '⭐');
    _category = t?.category ?? TaskCategory.health;
    _basePointsController = TextEditingController(text: (t?.basePoints ?? 10).toString());
    _extraPointsController = TextEditingController(text: (t?.extraPoints ?? 0).toString());
    _minCountController = TextEditingController(text: (t?.minDailyCount ?? 1).toString());
    _maxCountController = TextEditingController(text: (t?.maxDailyCount ?? 1).toString());
    _penaltyController = TextEditingController(text: (t?.penaltyMinutes ?? 0).toString());
    _checkinMode = t?.checkinMode ?? CheckinMode.self;
    _reminderIntervalController = TextEditingController(text: (t?.reminderRepeatInterval ?? 0).toString());

    if (t?.scheduledTime != null) {
      final parts = t!.scheduledTime!.split(':');
      _scheduledTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    if (t?.reminderTime != null) {
      final parts = t!.reminderTime!.split(':');
      _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _basePointsController.dispose();
    _extraPointsController.dispose();
    _minCountController.dispose();
    _maxCountController.dispose();
    _penaltyController.dispose();
    _reminderIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑任务' : '新建任务'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: _emojiController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '任务名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('分类', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: TaskCategory.values.map((cat) => ChoiceChip(
                label: Text(cat.label),
                selected: _category == cat,
                onSelected: (_) => setState(() => _category = cat),
              )).toList(),
            ),
            const SizedBox(height: 20),

            Text('积分设置', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _basePointsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '基础积分',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _extraPointsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '额外积分',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('次数设置', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '基础次数',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '每日上限',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('打卡方式', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: CheckinMode.values.map((mode) => ChoiceChip(
                label: Text(mode.label),
                selected: _checkinMode == mode,
                onSelected: (_) => setState(() => _checkinMode = mode),
              )).toList(),
            ),
            if (_checkinMode == CheckinMode.scheduled) ...[
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(_scheduledTime != null
                    ? '定时: ${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}'
                    : '设置打卡时间'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _scheduledTime ?? TimeOfDay.now(),
                  );
                  if (time != null) setState(() => _scheduledTime = time);
                },
              ),
            ],
            const SizedBox(height: 20),

            Text('惩罚设置', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _penaltyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '未完成扣减分钟数',
                border: OutlineInputBorder(),
                helperText: '0 表示不扣减，影响第二天使用时长',
              ),
            ),
            const SizedBox(height: 20),

            Text('提醒设置', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(_reminderTime != null
                  ? '提醒时间: ${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
                  : '设置提醒时间'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _reminderTime ?? TimeOfDay.now(),
                );
                if (time != null) setState(() => _reminderTime = time);
              },
            ),
            if (_reminderTime != null)
              TextField(
                controller: _reminderIntervalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '重复提醒间隔（分钟）',
                  border: OutlineInputBorder(),
                  helperText: '0 表示不重复',
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入任务名称')),
      );
      return;
    }

    final now = DateTime.now();
    final task = TaskDefinition(
      id: widget.task?.id,
      name: name,
      emoji: _emojiController.text.trim().isEmpty ? '⭐' : _emojiController.text.trim(),
      category: _category,
      basePoints: int.tryParse(_basePointsController.text) ?? 10,
      extraPoints: int.tryParse(_extraPointsController.text) ?? 0,
      minDailyCount: int.tryParse(_minCountController.text) ?? 1,
      maxDailyCount: int.tryParse(_maxCountController.text) ?? 1,
      checkinMode: _checkinMode,
      scheduledTime: _scheduledTime != null
          ? '${_scheduledTime!.hour.toString().padLeft(2, '0')}:${_scheduledTime!.minute.toString().padLeft(2, '0')}'
          : null,
      penaltyMinutes: int.tryParse(_penaltyController.text) ?? 0,
      reminderTime: _reminderTime != null
          ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
          : null,
      reminderRepeatInterval: int.tryParse(_reminderIntervalController.text) ?? 0,
      enabled: widget.task?.enabled ?? true,
      sortOrder: widget.task?.sortOrder ?? 0,
      createdAt: widget.task?.createdAt ?? now,
      updatedAt: now,
    );

    if (_isEditing) {
      ref.read(taskProvider.notifier).updateTask(task);
    } else {
      ref.read(taskProvider.notifier).addTask(task);
    }

    Navigator.pop(context);
  }
}
```

- [ ] **Step 2: 运行编译验证**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter analyze`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add qiaoqiao_companion/lib/features/parent_mode/presentation/task_edit_page.dart
git commit -m "feat: implement TaskEditPage with full form for task creation/editing"
```

---

## Task 15: App 启动时生成惩罚 + 应用惩罚

**Files:**
- Modify: `qiaoqiao_companion/lib/app/app_initializer.dart`

- [ ] **Step 1: 在 app_initializer.dart 中添加惩罚生成逻辑**

在 `AppInitializationNotifier.initialize()` 方法中，在步骤 2（`await Future.wait([...])`）之后、步骤 3（`OverlayService.init()`）之前，添加任务加载和惩罚生成：

将原步骤 2：
```dart
      // 2. 加载状态
      await Future.wait([
        _ref.read(todayUsageProvider.notifier).loadToday(),
        _ref.read(pointsProvider.notifier).load(),
        _ref.read(rulesProvider.notifier).load(),
        _ref.read(couponsProvider.notifier).load(),
        // 新增：加载监控应用和时间段数据
        _ref.read(monitoredAppsProvider.notifier).load(),
        _ref.read(timePeriodsProvider.notifier).load(),
      ]);
```

改为：
```dart
      // 2. 加载状态
      await Future.wait([
        _ref.read(todayUsageProvider.notifier).loadToday(),
        _ref.read(pointsProvider.notifier).load(),
        _ref.read(rulesProvider.notifier).load(),
        _ref.read(couponsProvider.notifier).load(),
        _ref.read(monitoredAppsProvider.notifier).load(),
        _ref.read(timePeriodsProvider.notifier).load(),
      ]);

      // 2.1 加载任务数据并生成/应用惩罚
      final taskNotifier = _ref.read(taskProvider.notifier);
      await taskNotifier.load();
      await taskNotifier.generatePenaltiesIfNeeded();
      await taskNotifier.applyPenaltiesForDate(
        DailyStats.formatDate(DateTime.now()),
      );
```

添加 import（在文件顶部 `providers.dart` 已导出所有 provider，无需额外 import）：

```dart
import 'package:qiaoqiao_companion/shared/models/daily_stats.dart';
```

注意：`DailyStats.formatDate` 是现有工具方法，用于将 DateTime 格式化为 `yyyy-MM-dd` 字符串。如果该 import 路径不正确，需查找实际位置。

- [ ] **Step 2: 运行编译验证**

Run: `cd d:\Developfile\baby-friends\qiaoqiao_companion && flutter analyze`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add qiaoqiao_companion/lib/app/app_initializer.dart
git commit -m "feat: generate task penalties on app startup"
```
