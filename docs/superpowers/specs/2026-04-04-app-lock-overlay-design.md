# 防关闭锁屏系统设计

## 概述

为巧巧小伙伴App实现防关闭锁屏系统，防止孩子在最近任务界面滑掉App，确保监控功能持续运行。

## 需求

- **核心目标**：防止孩子在最近任务界面滑掉App
- **家长权限**：家长可以通过密码正常关闭
- **自动恢复**：如果被强制停止，App会自动重启
- **兼容性**：兼容所有Android版本，重点适配MIUI 13/14

## 架构

```
┌─────────────────────────────────────────────────────────┐
│                    用户滑掉App                           │
└─────────────────────┬───────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────────┐
│           MonitorForegroundService.onTaskRemoved()      │
│                    检测到任务被移除                        │
└─────────────────────┬───────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────────┐
│              启动 AppLockOverlayActivity                │
│           (全屏锁屏覆盖，需要密码解除)                      │
└─────────────────────┬───────────────────────────────────┘
                      ▼
          ┌───────────┴───────────┐
          ▼                       ▼
┌─────────────────┐     ┌─────────────────┐
│   输入正确密码   │     │   输入错误密码   │
│  → 解除锁定      │     │  → 继续锁定      │
└─────────────────┘     └─────────────────┘
```

## 组件设计

### 1. 任务移除检测 (增强现有)

**文件**: `android/app/src/main/kotlin/.../services/MonitorForegroundService.kt`

**修改内容**:
- 添加`onTaskRemoved()`回调
- 检测任务被移除时启动锁屏覆盖Activity
- 同时发送通知提醒家长

```kotlin
override fun onTaskRemoved(rootIntent: Intent?) {
    Log.d(TAG, "Task removed by user")
    if (AppLockManager.isLockEnabled(this)) {
        // 启动锁屏覆盖
        AppLockOverlayActivity.start(this)
        // 发送通知
        showLockNotification()
    }
    super.onTaskRemoved(rootIntent)
}
```

### 2. 锁屏覆盖Activity (新增)

**文件**: `android/app/src/main/kotlin/.../activities/AppLockOverlayActivity.kt`

**功能**:
- 全屏显示，覆盖所有内容
- 显示"纹纹小伙伴正在运行中"提示
- 需要输入家长密码才能解除
- 支持指纹解锁（可选）
- 解除后可选择：继续运行 / 完全关闭

**UI布局**:
```
┌────────────────────────────────┐
│                                │
│         🛡️                     │
│    纹纹小伙伴正在运行中          │
│                                │
│  为保护孩子的健康使用习惯        │
│  需要家长密码才能关闭           │
│                                │
│  ┌──────────────────────────┐  │
│  │ 请输入家长密码             │  │
│  └──────────────────────────┘  │
│                                │
│      [解除锁定]  [重新打开]     │
│                                │
└────────────────────────────────┘
```

**关键实现**:
```kotlin
class AppLockOverlayActivity : AppCompatActivity() {

    companion object {
        fun start(context: Context) {
            val intent = Intent(context, AppLockOverlayActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            }
            context.startActivity(intent)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 全屏设置
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        // 防止下拉状态栏
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_app_lock_overlay)

        setupPasswordInput()
    }

    // 返回键禁用
    override fun onBackPressed() {
        // 不执行任何操作，阻止返回
    }
}
```

### 3. App锁管理器 (新增)

**文件**: `android/app/src/main/kotlin/.../managers/AppLockManager.kt`

**功能**:
- 管理锁屏启用/禁用状态
- 持久化设置到SharedPreferences
- 提供状态查询接口

```kotlin
object AppLockManager {
    private const val PREFS_NAME = "app_lock_prefs"
    private const val KEY_LOCK_ENABLED = "lock_enabled"

    fun isLockEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_LOCK_ENABLED, true) // 默认启用
    }

    fun setLockEnabled(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_LOCK_ENABLED, enabled).apply()
    }
}
```

### 4. Flutter端通信 (新增)

**文件**: `android/app/src/main/kotlin/.../channels/AppLockChannel.kt`

**通道名**: `com.qiaoqiao.qiaoqiao_companion/app_lock`

**方法**:
| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `isLockEnabled` | - | Boolean | 查询锁屏是否启用 |
| `setLockEnabled` | enabled: Boolean | Boolean | 设置锁屏启用状态 |
| `verifyPassword` | password: String | Boolean | 验证家长密码 |

**Flutter端**:

**文件**: `lib/core/platform/app_lock_service.dart`

```dart
class AppLockService {
  static const _channel = MethodChannel('com.qiaoqiao.qiaoqiao_companion/app_lock');

  Future<bool> isLockEnabled() async {
    return await _channel.invokeMethod('isLockEnabled');
  }

  Future<bool> setLockEnabled(bool enabled) async {
    return await _channel.invokeMethod('setLockEnabled', {'enabled': enabled});
  }

  Future<bool> verifyPassword(String password) async {
    return await _channel.invokeMethod('verifyPassword', {'password': password});
  }
}
```

### 5. 锁屏设置UI (修改现有)

**文件**: `lib/features/parent_mode/presentation/settings_page.dart`

**新增设置项**:
```dart
SwitchListTile(
  title: Text('防关闭保护'),
  subtitle: Text('防止孩子在最近任务中关闭App'),
  value: appLockEnabled,
  onChanged: (value) async {
    await ref.read(appLockProvider.notifier).setEnabled(value);
  },
),
```

## 用户流程

### 正常使用流程

1. App启动，前台服务运行
2. 孩子正常使用平板
3. 孩子尝试滑掉App → 立即显示锁屏覆盖
4. 需要家长密码才能解除

### 家长关闭流程

1. 长按头像进入家长模式
2. 输入密码验证
3. 在设置中关闭"防关闭保护"
4. 此时可以正常滑掉App

### 强制停止恢复流程

1. 如果被强制停止
2. KeepAliveWorker检测到服务停止（15分钟内）
3. 自动重启服务
4. 显示通知"纹纹小伙伴已重新启动"

## 数据存储

### SharedPreferences

| Key | 类型 | 默认值 | 说明 |
|-----|------|--------|------|
| `app_lock_enabled` | Boolean | true | 是否启用防关闭锁 |
| `app_lock_last_trigger` | Long | 0 | 上次触发时间戳 |

## 权限需求

| 权限 | 状态 | 用途 |
|------|------|------|
| SYSTEM_ALERT_WINDOW | ✅ 已有 | 显示锁屏覆盖 |
| FOREGROUND_SERVICE | ✅ 已有 | 保持后台运行 |
| USE_FINGERPRINT | 🔜 可选 | 指纹解锁（后续版本） |
| USE_BIOMETRIC | 🔜 可选 | 生物识别（后续版本） |

## 兼容性处理

### Android版本兼容

| 版本 | 处理方式 |
|------|----------|
| 5.0-7.1 | 使用Activity全屏模式 + STATUS_BAR_HIDDEN |
| 8.0-9.0 | 使用全屏Activity + FLAG_FULLSCREEN |
| 10+ | 使用全屏Activity + LayoutParams隐藏系统栏 |

### ROM特定处理

| ROM | 特殊处理 |
|-----|----------|
| MIUI | 处理神隐模式，在锁屏提示中引导设置无限制后台 |
| EMUI | 处理后台管理，引导手动锁定最近任务 |
| ColorOS | 处理后台冻结，引导加入白名单 |

### MIUI 13/14 特定优化

1. 引导用户在"开发者选项"中关闭"后台进程限制"
2. 引导在"电池优化"中将App设为"不优化"
3. 引导在"自启动管理"中允许自启动

## 实现步骤

### 第一阶段：核心功能

1. 创建 `AppLockManager.kt` - 状态管理
2. 创建 `AppLockChannel.kt` - Flutter通信通道
3. 创建 `AppLockOverlayActivity.kt` - 锁屏覆盖界面
4. 修改 `MonitorForegroundService.kt` - 添加 `onTaskRemoved()` 处理
5. 创建 `lib/core/platform/app_lock_service.dart` - Flutter端服务
6. 创建 `lib/shared/providers/app_lock_provider.dart` - 状态管理

### 第二阶段：UI集成

1. 修改 `settings_page.dart` - 添加防关闭设置开关
2. 创建锁屏覆盖布局文件 `activity_app_lock_overlay.xml`
3. 添加锁屏相关资源（图标、字符串）

### 第三阶段：兼容性优化

1. 添加MIUI特定引导提示
2. 添加其他ROM兼容性处理
3. 完善错误处理和日志

## 验证方法

1. **功能测试**:
   - 启用防关闭锁，滑掉App → 应显示锁屏覆盖
   - 输入错误密码 → 应拒绝解除
   - 输入正确密码 → 应解除锁定
   - 禁用防关闭锁，滑掉App → 应正常关闭

2. **兼容性测试**:
   - 小米平板5 (MIUI 13/14) - 主目标设备
   - 其他Android设备 (Android 8.0+) - 兼容性验证

3. **稳定性测试**:
   - 多次滑掉/恢复循环
   - 长时间后台运行后测试
   - 低内存场景测试
