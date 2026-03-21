# 禁用App递进式提醒功能设计

## 概述

当检测到禁用app（禁止时段、时间用完、黑名单等）时，显示递进式提醒对话框。用户可以关闭前3次提醒，但间隔会逐渐缩短，第4次及以后无法关闭（强制锁定）。

## 需求

### 触发条件

禁用app包括以下情况：
- 禁止时段内使用娱乐app（如21:00-07:00）
- 时间用完后继续使用（游戏/视频/总时间）
- 特定被完全禁用的app（家长黑名单）

### 触发时机

检测到禁用app时**立即**弹出提示框。

### 递进式提醒规则

| 提醒次数 | 关闭后等待时间 | 是否可关闭 | 说明 |
|---------|--------------|----------|------|
| 第1次 | 2分钟 | ✅ | 温和提醒 |
| 第2次 | 1分钟 | ✅ | 认真警告 |
| 第3次 | 30秒 | ✅ | 最后警告 |
| 第4次+ | - | ❌ | 强制锁定，无法关闭 |

### 重置规则

- 每天午夜（00:00）重置所有app的提醒计数器
- 用户切换到其他app后切回，计数器不重置（继续累计）
- **设计决策**：提醒计数仅存储在内存中，不持久化。应用重启后计数器归零。这是有意的设计，因为：
  - 强制锁定场景下用户通常会重启设备或关闭应用
  - 每日重置已经提供了合理的边界
  - 避免过度复杂的持久化逻辑

## 现有代码分析

### 相关枚举说明

项目中存在两个提醒相关的枚举：

1. **`ReminderLevel`** (`lib/core/services/reminder_service.dart`)
   - 用于内部提醒级别逻辑
   - 值：`gentle`, `serious`, `final_`, `locked`
   - **保持不变**，仅用于内部状态管理

2. **`ReminderType`** (`lib/core/platform/overlay_service.dart`)
   - 用于Flutter与Android原生层通信
   - 值：`reminder`, `warning`, `serious`, `lock`
   - **需要扩展**，新增禁用app类型

两个枚举职责不同，保持分离。

## 架构设计

### 新增组件

#### 1. ForbiddenAppTracker

**位置**: `lib/core/services/forbidden_app_tracker.dart`

**设计决策**：作为普通类（非Riverpod Provider），由 `ReminderService` 直接持有。原因：
- 生命周期与 `ReminderService` 绑定
- 不需要跨组件共享状态
- 简化依赖关系

**职责**:
- 跟踪每个禁用app的提醒次数（按包名分组）
- 记录上次提醒关闭时间
- 计算是否应该显示下次提醒
- 提供重置功能

**数据结构**:
```dart
class ForbiddenAppRecord {
  final String packageName;
  int reminderCount;           // 提醒次数
  DateTime? lastDismissedAt;   // 上次关闭时间
  DateTime? lastShownAt;       // 上次显示时间（用于间隔判断）
}
```

**核心方法**:
```dart
class ForbiddenAppTracker {
  final Map<String, ForbiddenAppRecord> _records = {};

  /// 是否应该显示提醒（检查间隔时间）
  /// 如果是第一次，立即返回true
  /// 如果之前关闭过，检查是否已过等待间隔
  bool shouldShowReminder(String packageName) {
    final record = _records[packageName];
    if (record == null) return true;
    if (record.lastDismissedAt == null) return true;

    final interval = getReminderInterval(record.reminderCount);
    if (interval == Duration.zero) return true; // 第4次+立即显示

    final elapsed = DateTime.now().difference(record.lastDismissedAt!);
    return elapsed >= interval;
  }

  /// 记录overlay已显示（在显示时调用）
  void recordShown(String packageName) {
    final record = _records[packageName] ?? ForbiddenAppRecord(packageName: packageName);
    _records[packageName] = ForbiddenAppRecord(
      packageName: packageName,
      reminderCount: record.reminderCount,
      lastDismissedAt: record.lastDismissedAt,
      lastShownAt: DateTime.now(),
    );
  }

  /// 记录用户关闭了提醒（从Android回调）
  void recordDismissal(String packageName) {
    final record = _records[packageName];
    if (record == null) return;

    _records[packageName] = ForbiddenAppRecord(
      packageName: packageName,
      reminderCount: record.reminderCount + 1,
      lastDismissedAt: DateTime.now(),
      lastShownAt: record.lastShownAt,
    );
  }

  /// 获取当前提醒次数
  int getReminderCount(String packageName) {
    return _records[packageName]?.reminderCount ?? 0;
  }

  /// 是否可以关闭（前3次可关闭）
  bool isDismissible(String packageName) {
    final count = getReminderCount(packageName);
    // 注意：count是已关闭次数，所以 count < 3 表示还未到第4次
    return count < 3;
  }

  /// 重置所有记录（午夜调用）
  void resetAll() {
    _records.clear();
  }

  /// 重置单个app记录
  void resetForApp(String packageName) {
    _records.remove(packageName);
  }
}
```

**提醒间隔计算**:
```dart
Duration getReminderInterval(int closedCount) {
  // closedCount是已关闭的次数
  // 第1次关闭后等2分钟，第2次关闭后等1分钟，第3次关闭后等30秒
  switch (closedCount) {
    case 0: return Duration.zero;  // 首次立即显示
    case 1: return Duration(minutes: 2);
    case 2: return Duration(minutes: 1);
    case 3: return Duration(seconds: 30);
    default: return Duration.zero; // 第4次+立即显示（不可关闭）
  }
}
```

#### 2. 扩展 ReminderType

**位置**: `lib/core/platform/overlay_service.dart`

```dart
enum ReminderType {
  reminder('reminder'),
  warning('warning'),
  serious('serious'),
  lock('lock'),
  forbiddenDismissible('forbidden_dismissible'),  // 新增：可关闭的禁用提醒
  forbiddenLocked('forbidden_locked');            // 新增：不可关闭的禁用锁定

  const ReminderType(this.code);
  final String code;

  static ReminderType fromCode(String code) {
    return ReminderType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ReminderType.reminder,
    );
  }
}
```

### 关闭回调架构

由于Android overlay关闭事件需要回传给Flutter，需要添加回调机制：

#### 方案：使用 MethodChannel 事件流

**Android端** (OverlayChannel.kt):
```kotlin
class OverlayChannel(private val context: Context, binaryMessenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(binaryMessenger, "com.qiaoqiao.companion/overlay")
    private var dismissCallback: ((String) -> Unit)? = null

    init {
        channel.setMethodCallHandler(this)
    }

    // 设置dismiss回调（供内部使用）
    fun setOnDismissListener(callback: (String) -> Unit) {
        dismissCallback = callback
    }

    private fun showOverlay(arguments: Map<String, Any>, result: MethodChannel.Result) {
        val title = arguments["title"] as? String ?: ""
        val message = arguments["message"] as? String ?: ""
        val type = arguments["type"] as? String ?: "reminder"
        val durationSeconds = (arguments["durationSeconds"] as? Number)?.toInt() ?: 0
        val dismissible = arguments["dismissible"] as? Boolean ?: true
        val packageName = arguments["packageName"] as? String ?: ""

        // ... 创建overlay view

        if (dismissible) {
            overlayView.setOnDismissListener {
                // 通知Flutter用户关闭了overlay
                channel.invokeMethod("onOverlayDismissed", mapOf(
                    "packageName" to packageName
                ))
            }
        }

        result.success(null)
    }
}
```

**Flutter端** (OverlayService.dart):
```dart
class OverlayService {
  static const MethodChannel _channel =
      MethodChannel('com.qiaoqiao.companion/overlay');

  static VoidCallback? _onDismissedCallback;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOverlayDismissed') {
        _onDismissedCallback?.call();
        _onDismissedCallback = null;
      }
    });
  }

  static Future<void> showOverlay({
    required String title,
    required String message,
    ReminderType type = ReminderType.reminder,
    int durationSeconds = 0,
    bool dismissible = true,
    String packageName = '',  // 用于回调识别
    VoidCallback? onDismissed,  // 关闭回调
  }) async {
    _onDismissedCallback = onDismissed;

    await _channel.invokeMethod<void>(
      'showOverlay',
      {
        'title': title,
        'message': message,
        'type': type.code,
        'durationSeconds': durationSeconds,
        'dismissible': dismissible,
        'packageName': packageName,
      },
    );
  }
}
```

### 修改现有组件

#### 1. ReminderService

**位置**: `lib/core/services/reminder_service.dart`

**新增成员**:
```dart
class ReminderService {
  final Ref _ref;
  final ForbiddenAppTracker _forbiddenAppTracker = ForbiddenAppTracker();
  String? _currentForbiddenPackage;
  // ... 现有成员
}
```

**新增方法**:
```dart
/// 检查并显示禁用app提醒
/// 返回true表示显示了提醒，false表示未显示（还在等待间隔）
Future<bool> checkAndShowForbiddenReminder({
  required String packageName,
  required String reason,
}) async {
  // 1. 检查是否应该显示提醒
  if (!_forbiddenAppTracker.shouldShowReminder(packageName)) {
    return false;
  }

  // 2. 更新当前禁用的包名
  _currentForbiddenPackage = packageName;

  // 3. 记录已显示
  _forbiddenAppTracker.recordShown(packageName);

  // 4. 根据次数决定是否可关闭
  final isDismissible = _forbiddenAppTracker.isDismissible(packageName);
  final type = isDismissible
    ? ReminderType.forbiddenDismissible
    : ReminderType.forbiddenLocked;

  // 5. 获取提醒次数（用于标题）
  final count = _forbiddenAppTracker.getReminderCount(packageName);

  // 6. 显示overlay
  await OverlayService.showOverlay(
    title: _getTitle(count),
    message: reason,
    type: type,
    dismissible: isDismissible,
    packageName: packageName,
    onDismissed: isDismissible ? () {
      _forbiddenAppTracker.recordDismissal(packageName);
    } : null,
  );

  return true;
}

String _getTitle(int closedCount) {
  // closedCount是已关闭次数，显示的是下一次
  switch (closedCount) {
    case 0: return '这个应用不能使用哦';
    case 1: return '巧巧提醒你';
    case 2: return '最后提醒';
    default: return '时间结束';
  }
}

/// 处理Android端的dismiss回调（通过OverlayService调用）
void onOverlayDismissed(String packageName) {
  if (packageName == _currentForbiddenPackage) {
    _forbiddenAppTracker.recordDismissal(packageName);
  }
}
```

**修改 reset() 方法**:
```dart
void reset() {
  _hasSentGentleReminder = false;
  _hasSentSeriousReminder = false;
  _hasSentFinalWarning = false;
  _hasLocked = false;
  _currentLockedPackage = null;

  // 新增：重置禁用app跟踪器
  _forbiddenAppTracker.resetAll();
}
```

#### 2. UsageMonitorService

**位置**: `lib/core/services/usage_monitor_service.dart`

**新增依赖**:
```dart
class UsageMonitorService {
  final AppDatabase _database;
  final ReminderService _reminderService;
  final RuleCheckerService _ruleCheckerService;  // 新增

  // ...
}
```

**修改构造函数**:
```dart
UsageMonitorService(this._database, this._reminderService)
    : _appUsageDao = AppUsageDao(_database),
      _dailyStatsDao = DailyStatsDao(_database),
      _ruleDao = RuleDao(_database),
      _pointsDao = PointsDao(_database),
      _ruleCheckerService = RuleCheckerService(_database);  // 新增
```

**修改 _pollUsageStats() 方法**:
```dart
Future<void> _pollUsageStats() async {
  try {
    // 获取当前前台应用
    final currentApp = await UsageStatsService.getCurrentForegroundApp();

    if (currentApp != null && currentApp != _lastForegroundApp) {
      // 应用切换，记录上一个应用的使用时间
      if (_lastForegroundApp != null && _lastForegroundTime != null) {
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

      if (elapsed.inSeconds >= monitorIntervalSeconds) {
        await _recordUsage(currentApp, _lastForegroundTime!, now);
        _lastForegroundTime = now;
      }
    }

    // 检查现有规则（时间限制等）
    await _checkRules();

    // 新增：检查当前app是否被禁用
    if (currentApp != null) {
      await _checkForbiddenApp(currentApp);
    }

  } catch (e, stackTrace) {
    print('[UsageMonitor] Error in _pollUsageStats: $e');
  }
}

/// 检查禁用app（新增方法）
Future<void> _checkForbiddenApp(String packageName) async {
  // 使用RuleCheckerService检查app是否被禁用
  final result = await _ruleCheckerService.checkAppUsage(packageName);

  if (!result.allowed) {
    // app被禁用，显示递进式提醒
    await _reminderService.checkAndShowForbiddenReminder(
      packageName: packageName,
      reason: result.reason ?? '该应用当前不可使用',
    );
  } else {
    // app允许使用，隐藏任何显示中的禁用提醒
    final isShowing = await OverlayService.isOverlayShowing();
    if (isShowing && _reminderService.isLocked) {
      // 只有当overlay是锁定类型时才隐藏
      // 注意：这里需要谨慎处理，避免误关闭用户的提醒
    }
  }
}
```

#### 3. OverlayService (Flutter)

**位置**: `lib/core/platform/overlay_service.dart`

**修改 showOverlay() 方法**:
```dart
static Future<void> showOverlay({
  required String title,
  required String message,
  ReminderType type = ReminderType.reminder,
  int durationSeconds = 0,
  bool dismissible = true,
  String packageName = '',
  VoidCallback? onDismissed,
}) async {
  _onDismissedCallback = onDismissed;

  await _channel.invokeMethod<void>(
    'showOverlay',
    {
      'title': title,
      'message': message,
      'type': type.code,
      'durationSeconds': durationSeconds,
      'dismissible': dismissible,
      'packageName': packageName,
    },
  );
}
```

**修改 ReminderMessage 类**:
```dart
class ReminderMessage {
  final String title;
  final String message;
  final ReminderType type;
  final int durationSeconds;
  final bool dismissible;  // 新增
  final String packageName; // 新增

  ReminderMessage({
    required this.title,
    required this.message,
    required this.type,
    this.durationSeconds = 0,
    this.dismissible = true,
    this.packageName = '',
  });

  Future<void> show({VoidCallback? onDismissed}) async {
    await OverlayService.showOverlay(
      title: title,
      message: message,
      type: type,
      durationSeconds: durationSeconds,
      dismissible: dismissible,
      packageName: packageName,
      onDismissed: onDismissed,
    );
  }
}
```

#### 4. OverlayChannel.kt (Android)

**位置**: `android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/OverlayChannel.kt`

**修改 showOverlay() 方法**:
```kotlin
private fun showOverlay(call: MethodCall, result: MethodChannel.Result) {
    val arguments = call.arguments as Map<String, Any>
    val title = arguments["title"] as? String ?: ""
    val message = arguments["message"] as? String ?: ""
    val type = arguments["type"] as? String ?: "reminder"
    val durationSeconds = (arguments["durationSeconds"] as? Number)?.toInt() ?: 0
    val dismissible = arguments["dismissible"] as? Boolean ?: true
    val packageName = arguments["packageName"] as? String ?: ""

    // 在主线程显示overlay
    Handler(Looper.getMainLooper()).post {
        when (type) {
            "forbidden_locked" -> {
                showForbiddenLockOverlay(title, message)
            }
            "forbidden_dismissible" -> {
                showDismissibleOverlay(title, message, packageName)
            }
            else -> {
                showExistingOverlay(title, message, type, durationSeconds)
            }
        }
    }

    result.success(null)
}

private fun showForbiddenLockOverlay(title: String, message: String) {
    // 创建不可关闭的overlay
    val overlayView = createOverlayView(title, message)
    overlayView.setCancelable(false)
    overlayView.setOnKeyListener { _, keyCode, _ ->
        keyCode == KeyEvent.KEYCODE_BACK
    }
    // 显示overlay...
}

private fun showDismissibleOverlay(title: String, message: String, packageName: String) {
    val overlayView = createOverlayView(title, message)
    overlayView.setCancelable(true)
    overlayView.setOnDismissListener {
        // 通知Flutter用户关闭了overlay
        channel.invokeMethod("onOverlayDismissed", mapOf(
            "packageName" to packageName
        ))
    }
    // 显示overlay...
}
```

#### 5. AppInitializer

**位置**: `lib/app/app_initializer.dart`

**添加 OverlayService 初始化**:
```dart
Future<void> _initializeServices() async {
  // ... 现有初始化代码

  // 新增：初始化OverlayService的回调监听
  OverlayService.init();
}
```

## 数据流

```
┌─────────────────────────────────────────────────────────────┐
│                    UsageMonitorService                       │
│                       _pollUsageStats()                      │
│                      (每30秒轮询)                            │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              检测当前前台app (currentApp)                    │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│           RuleCheckerService.checkAppUsage(packageName)     │
└─────────────────────────┬───────────────────────────────────┘
                          │
                ┌─────────┴─────────┐
                │                   │
           allowed=true        allowed=false
                │                   │
                ▼                   ▼
            不做处理    ┌───────────────────────────────────┐
                        │   ReminderService                  │
                        │   checkAndShowForbiddenReminder() │
                        └───────────────┬───────────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────────────┐
                        │   ForbiddenAppTracker             │
                        │   shouldShowReminder()?           │
                        └───────────────┬───────────────────┘
                                        │
                                  ┌─────┴─────┐
                                  │           │
                               false        true
                                  │           │
                              等待下次       │
                                            ▼
                            ┌───────────────────────────────┐
                            │   OverlayService.showOverlay() │
                            │   type: forbiddenDismissible   │
                            │         或 forbiddenLocked     │
                            │   onDismissed: callback        │
                            └───────────────┬───────────────┘
                                            │
                                            ▼
                            ┌───────────────────────────────┐
                            │   Android OverlayChannel      │
                            │   显示overlay                  │
                            └───────────────┬───────────────┘
                                            │
                                  ┌─────────┴─────────┐
                                  │                   │
                            用户关闭            不可关闭
                                  │              (第4次+)
                                  ▼
                            ┌───────────────────────────────┐
                            │   MethodChannel回调            │
                            │   "onOverlayDismissed"         │
                            └───────────────┬───────────────┘
                                            │
                                            ▼
                            ┌───────────────────────────────┐
                            │   recordDismissal()           │
                            │   记录时间，等待下次触发       │
                            └───────────────────────────────┘
```

## 多App切换场景

当用户在多个禁用app之间快速切换时的行为：

| 场景 | 行为 |
|-----|------|
| App A被禁用，显示提醒 → 切换到App B（也被禁用） | App B开始新的提醒计数，App A的计数暂停 |
| App A被禁用，关闭提醒 → 切换到App B → 2分钟后回到App A | App A继续原计数，如果间隔已过则显示下一次提醒 |
| 多个禁用app同时在前台（分屏） | 以主应用为准进行提醒 |

**设计决策**：每个app独立计数，互不影响。

## 文件变更清单

| 文件 | 变更类型 | 说明 |
|-----|---------|------|
| `lib/core/services/forbidden_app_tracker.dart` | 新增 | 禁用app跟踪器 |
| `lib/core/services/reminder_service.dart` | 修改 | 添加禁用app提醒方法和ForbiddenAppTracker |
| `lib/core/services/usage_monitor_service.dart` | 修改 | 添加RuleCheckerService依赖和禁用app检测 |
| `lib/core/platform/overlay_service.dart` | 修改 | 添加dismissible参数、packageName、onDismissed回调 |
| `lib/app/app_initializer.dart` | 修改 | 添加OverlayService.init()调用 |
| `android/.../OverlayChannel.kt` | 修改 | 支持不可关闭的overlay和dismiss回调 |

## 测试要点

### 单元测试

1. `ForbiddenAppTracker`
   - 提醒次数累加正确
   - 间隔时间计算正确（0→2分钟→1分钟→30秒→0）
   - shouldShowReminder()判断正确
   - 重置功能正常

2. `ReminderService`
   - 根据次数选择正确的ReminderType
   - isDismissible()判断正确（0,1,2为true，3+为false）

### 集成测试

1. 检测到禁用app时立即弹出提示
2. 关闭后等待正确的时间间隔再弹出
3. 第4次及以后无法关闭
4. 午夜重置后计数器归零
5. 应用重启后计数器归零
6. 切换到允许使用的app后overlay隐藏

## 风险与考虑

1. **性能**：每次轮询都会调用 `RuleCheckerService`，已有5分钟缓存机制
2. **电池**：频繁的overlay显示可能影响电池，已通过递进间隔缓解
3. **用户体验**：强制锁定可能引起用户不满，但这是设计的核心功能
4. **回调可靠性**：MethodChannel回调可能丢失，但影响有限（最多导致计数不准，用户下次触发时会修正）
