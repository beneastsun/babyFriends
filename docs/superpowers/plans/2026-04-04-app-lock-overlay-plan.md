# 防关闭锁屏系统实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现App防关闭锁屏系统，防止孩子在最近任务界面滑掉App

**Architecture:** 通过监听Service的`onTaskRemoved()`回调检测任务被移除，立即启动全屏锁屏Activity覆盖屏幕，需要家长密码才能解除。

**Tech Stack:** Kotlin (Android Native), Dart (Flutter), MethodChannel通信

---

## 文件结构

### 新建文件

| 文件 | 职责 |
|------|------|
| `android/.../managers/AppLockManager.kt` | 管理锁屏启用/禁用状态，SharedPreferences持久化 |
| `android/.../channels/AppLockChannel.kt` | Flutter ↔ Native通信通道 |
| `android/.../activities/AppLockOverlayActivity.kt` | 全屏锁屏覆盖界面 |
| `android/.../res/layout/activity_app_lock_overlay.xml` | 锁屏界面布局 |
| `lib/core/platform/app_lock_service.dart` | Flutter端服务封装 |
| `lib/shared/providers/app_lock_provider.dart` | Riverpod状态管理 |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `android/.../services/MonitorForegroundService.kt` | 添加`onTaskRemoved()`处理 |
| `android/.../QiaoqiaoApplication.kt` | 注册AppLockChannel |
| `android/.../AndroidManifest.xml` | 注册AppLockOverlayActivity |
| `lib/features/parent_mode/presentation/parent_mode_page.dart` | 添加防关闭设置开关 |

---

## Task 1: 创建AppLockManager

**Files:**
- Create: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/managers/AppLockManager.kt`

- [ ] **Step 1: 创建AppLockManager.kt**

```kotlin
package com.qiaoqiao.qiaoqiao_companion.managers

import android.content.Context

/**
 * App锁管理器
 * 管理防关闭锁屏的启用状态
 */
object AppLockManager {

    private const val PREFS_NAME = "app_lock_prefs"
    private const val KEY_LOCK_ENABLED = "lock_enabled"
    private const val KEY_LAST_TRIGGER_TIME = "last_trigger_time"

    /**
     * 检查锁屏是否启用
     */
    fun isLockEnabled(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_LOCK_ENABLED, true) // 默认启用
    }

    /**
     * 设置锁屏启用状态
     */
    fun setLockEnabled(context: Context, enabled: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_LOCK_ENABLED, enabled).apply()
    }

    /**
     * 记录上次触发时间
     */
    fun setLastTriggerTime(context: Context, time: Long) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putLong(KEY_LAST_TRIGGER_TIME, time).apply()
    }

    /**
     * 获取上次触发时间
     */
    fun getLastTriggerTime(context: Context): Long {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getLong(KEY_LAST_TRIGGER_TIME, 0)
    }
}
```

- [ ] **Step 2: 验证文件创建成功**

Run: `ls -la qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/managers/`
Expected: `AppLockManager.kt` 文件存在

- [ ] **Step 3: Commit**

```bash
cd qiaoqiao_companion
git add android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/managers/AppLockManager.kt
git commit -m "feat(android): add AppLockManager for lock state management"
```

---

## Task 2: 创建AppLockChannel

**Files:**
- Create: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/channels/AppLockChannel.kt`

- [ ] **Step 1: 创建AppLockChannel.kt**

```kotlin
package com.qiaoqiao.qiaoqiao_companion.channels

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.qiaoqiao.qiaoqiao_companion.managers.AppLockManager
import com.qiaoqiao.qiaoqiao_companion.features.parent_mode.data.ParentPasswordRepository

/**
 * App锁通道
 * Flutter与原生锁屏功能的通信桥梁
 */
class AppLockChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "AppLockChannel"
        const val CHANNEL_NAME = "com.qiaoqiao.qiaoqiao_companion/app_lock"
    }

    private lateinit var passwordRepository: ParentPasswordRepository

    fun init() {
        passwordRepository = ParentPasswordRepository(context)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isLockEnabled" -> {
                isLockEnabled(result)
            }
            "setLockEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                setLockEnabled(enabled, result)
            }
            "verifyPassword" -> {
                val password = call.argument<String>("password")
                if (password != null) {
                    verifyPassword(password, result)
                } else {
                    result.error("INVALID_ARGUMENT", "Password is required", null)
                }
            }
            "getLastTriggerTime" -> {
                getLastTriggerTime(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * 检查锁屏是否启用
     */
    private fun isLockEnabled(result: MethodChannel.Result) {
        try {
            val enabled = AppLockManager.isLockEnabled(context)
            result.success(enabled)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check lock enabled", e)
            result.error("LOCK_ERROR", e.message, null)
        }
    }

    /**
     * 设置锁屏启用状态
     */
    private fun setLockEnabled(enabled: Boolean, result: MethodChannel.Result) {
        try {
            AppLockManager.setLockEnabled(context, enabled)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set lock enabled", e)
            result.error("LOCK_ERROR", e.message, null)
        }
    }

    /**
     * 验证家长密码
     */
    private fun verifyPassword(password: String, result: MethodChannel.Result) {
        try {
            val isValid = passwordRepository.verifyPassword(password)
            result.success(isValid)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to verify password", e)
            result.error("AUTH_ERROR", e.message, null)
        }
    }

    /**
     * 获取上次触发时间
     */
    private fun getLastTriggerTime(result: MethodChannel.Result) {
        try {
            val time = AppLockManager.getLastTriggerTime(context)
            result.success(time)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get last trigger time", e)
            result.error("LOCK_ERROR", e.message, null)
        }
    }
}
```

- [ ] **Step 2: 创建ParentPasswordRepository (Kotlin版本)**

由于需要从Native端验证密码，需要创建Kotlin版本的密码仓库:

```kotlin
package com.qiaoqiao.qiaoqiao_companion.features.parent_mode.data

import android.content.Context
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec
import java.security.SecureRandom
import java.util.Base64

/**
 * 家长密码仓库 (Kotlin版本)
 * 用于Native端密码验证
 */
class ParentPasswordRepository(private val context: Context) {

    companion object {
        private const val PREFS_NAME = "parent_auth_prefs"
        private const val KEY_PASSWORD_HASH = "password_hash"
        private const val KEY_SALT = "password_salt"
        private const val ITERATIONS = 10000
        private const val KEY_LENGTH = 256
    }

    /**
     * 检查是否已设置密码
     */
    fun hasPassword(): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.contains(KEY_PASSWORD_HASH)
    }

    /**
     * 验证密码
     */
    fun verifyPassword(password: String): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val storedHash = prefs.getString(KEY_PASSWORD_HASH, null) ?: return false
        val salt = prefs.getString(KEY_SALT, null) ?: return false

        val inputHash = hashPassword(password, Base64.getDecoder().decode(salt))
        return storedHash == inputHash
    }

    /**
     * 哈希密码
     */
    private fun hashPassword(password: String, salt: ByteArray): String {
        val spec = PBEKeySpec(password.toCharArray(), salt, ITERATIONS, KEY_LENGTH)
        val factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val hash = factory.generateSecret(spec).encoded
        return Base64.getEncoder().encodeToString(hash)
    }
}
```

- [ ] **Step 3: 验证文件创建成功**

Run: `ls -la qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/channels/`
Expected: `AppLockChannel.kt` 文件存在

- [ ] **Step 4: Commit**

```bash
cd qiaoqiao_companion
git add android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/channels/AppLockChannel.kt
git add android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/features/parent_mode/data/ParentPasswordRepository.kt
git commit -m "feat(android): add AppLockChannel for Flutter-Native communication"
```

---

## Task 3: 创建锁屏覆盖布局

**Files:**
- Create: `qiaoqiao_companion/android/app/src/main/res/layout/activity_app_lock_overlay.xml`
- Create: `qiaoqiao_companion/android/app/src/main/res/drawable/ic_shield.xml` (如果不存在)

- [ ] **Step 1: 检查并创建drawable目录**

Run: `mkdir -p qiaoqiao_companion/android/app/src/main/res/drawable`

- [ ] **Step 2: 创建盾牌图标 (ic_shield.xml)**

```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="96dp"
    android:height="96dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#4CAF50"
        android:pathData="M12,1L3,5v6c0,5.55 3.84,10.74 9,12 5.16,-1.26 9,-6.45 9,-12V5l-9,-4z"/>
</vector>
```

- [ ] **Step 3: 创建锁屏覆盖布局**

```xml
<?xml version="1.0" encoding="utf-8"?>
<androidx.constraintlayout.widget.ConstraintLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    xmlns:tools="http://schemas.android.com/tools"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="#E3F2FD"
    android:padding="32dp"
    tools:context=".activities.AppLockOverlayActivity">

    <ImageView
        android:id="@+id/ivShield"
        android:layout_width="96dp"
        android:layout_height="96dp"
        android:src="@drawable/ic_shield"
        app:layout_constraintTop_toTopOf="parent"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        android:layout_marginTop="80dp"
        app:tint="#4CAF50" />

    <TextView
        android:id="@+id/tvTitle"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="@string/app_lock_title"
        android:textSize="24sp"
        android:textStyle="bold"
        android:textColor="#1565C0"
        app:layout_constraintTop_toBottomOf="@id/ivShield"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        android:layout_marginTop="24dp" />

    <TextView
        android:id="@+id/tvMessage"
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:text="@string/app_lock_message"
        android:textSize="16sp"
        android:textColor="#424242"
        android:gravity="center"
        android:lineSpacingExtra="4dp"
        app:layout_constraintTop_toBottomOf="@id/tvTitle"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        android:layout_marginTop="16dp" />

    <EditText
        android:id="@+id/etPassword"
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:hint="@string/app_lock_password_hint"
        android:inputType="numberPassword"
        android:maxLength="6"
        android:textSize="18sp"
        android:gravity="center"
        android:background="@android:drawable/edit_text"
        android:padding="16dp"
        app:layout_constraintTop_toBottomOf="@id/tvMessage"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        android:layout_marginTop="32dp"
        android:layout_marginHorizontal="32dp" />

    <TextView
        android:id="@+id/tvError"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="@string/app_lock_error"
        android:textColor="#F44336"
        android:textSize="14sp"
        android:visibility="gone"
        app:layout_constraintTop_toBottomOf="@id/etPassword"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        android:layout_marginTop="8dp" />

    <Button
        android:id="@+id/btnUnlock"
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:text="@string/app_lock_unlock"
        android:textSize="16sp"
        android:padding="16dp"
        app:layout_constraintTop_toBottomOf="@id/tvError"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        android:layout_marginTop="24dp"
        android:layout_marginHorizontal="32dp" />

    <Button
        android:id="@+id/btnReopen"
        style="@style/Widget.AppCompat.Button.Borderless"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="@string/app_lock_reopen"
        android:textColor="#1565C0"
        android:textSize="14sp"
        app:layout_constraintTop_toBottomOf="@id/btnUnlock"
        app:layout_constraintStart_toStartOf="parent"
        app:layout_constraintEnd_toEndOf="parent"
        android:layout_marginTop="16dp" />

</androidx.constraintlayout.widget.ConstraintLayout>
```

- [ ] **Step 4: 添加字符串资源**

在 `qiaoqiao_companion/android/app/src/main/res/values/strings.xml` 中添加:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- 现有字符串... -->

    <!-- App Lock Overlay -->
    <string name="app_lock_title">纹纹小伙伴正在运行中</string>
    <string name="app_lock_message">为保护孩子的健康使用习惯\n需要家长密码才能关闭</string>
    <string name="app_lock_password_hint">请输入家长密码</string>
    <string name="app_lock_error">密码错误，请重试</string>
    <string name="app_lock_unlock">解除锁定</string>
    <string name="app_lock_reopen">重新打开App</string>
</resources>
```

如果 `strings.xml` 不存在，创建它。如果已存在，只添加新字符串。

- [ ] **Step 5: 验证文件创建成功**

Run: `ls -la qiaoqiao_companion/android/app/src/main/res/layout/`
Expected: `activity_app_lock_overlay.xml` 文件存在

- [ ] **Step 6: Commit**

```bash
cd qiaoqiao_companion
git add android/app/src/main/res/layout/activity_app_lock_overlay.xml
git add android/app/src/main/res/drawable/ic_shield.xml
git add android/app/src/main/res/values/strings.xml
git commit -m "feat(android): add app lock overlay layout and resources"
```

---

## Task 4: 创建AppLockOverlayActivity

**Files:**
- Create: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/activities/AppLockOverlayActivity.kt`

- [ ] **Step 1: 创建AppLockOverlayActivity.kt**

```kotlin
package com.qiaoqiao.qiaoqiao_companion.activities

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.qiaoqiao.qiaoqiao_companion.MainActivity
import com.qiaoqiao.qiaoqiao_companion.R
import com.qiaoqiao.qiaoqiao_companion.features.parent_mode.data.ParentPasswordRepository
import com.qiaoqiao.qiaoqiao_companion.managers.AppLockManager

/**
 * App锁屏覆盖Activity
 * 当用户尝试滑掉App时显示，需要家长密码才能解除
 */
class AppLockOverlayActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "AppLockOverlayActivity"

        /**
         * 启动锁屏覆盖
         */
        fun start(context: Context) {
            // 记录触发时间
            AppLockManager.setLastTriggerTime(context, System.currentTimeMillis())

            val intent = Intent(context, AppLockOverlayActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            }
            context.startActivity(intent)
        }
    }

    private lateinit var passwordRepository: ParentPasswordRepository
    private lateinit var etPassword: EditText
    private lateinit var tvError: TextView
    private lateinit var btnUnlock: Button
    private lateinit var btnReopen: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 设置全屏
        setupFullScreen()

        setContentView(R.layout.activity_app_lock_overlay)

        passwordRepository = ParentPasswordRepository(this)

        initViews()
        setupListeners()
    }

    /**
     * 设置全屏显示
     */
    private fun setupFullScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let { controller ->
                controller.hide(android.view.WindowInsets.Type.statusBars() or android.view.WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )
        }

        // 防止截屏（可选）
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    /**
     * 初始化视图
     */
    private fun initViews() {
        etPassword = findViewById(R.id.etPassword)
        tvError = findViewById(R.id.tvError)
        btnUnlock = findViewById(R.id.btnUnlock)
        btnReopen = findViewById(R.id.btnReopen)
    }

    /**
     * 设置监听器
     */
    private fun setupListeners() {
        btnUnlock.setOnClickListener {
            attemptUnlock()
        }

        btnReopen.setOnClickListener {
            reopenApp()
        }

        // 密码输入时隐藏错误
        etPassword.setOnEditorActionListener { _, _, _ ->
            attemptUnlock()
            true
        }
    }

    /**
     * 尝试解锁
     */
    private fun attemptUnlock() {
        val password = etPassword.text.toString()

        if (password.isEmpty()) {
            showError("请输入密码")
            return
        }

        if (passwordRepository.verifyPassword(password)) {
            // 密码正确，关闭锁屏
            Log.d(TAG, "Password correct, unlocking")
            finish()
        } else {
            // 密码错误
            showError("密码错误，请重试")
            etPassword.text?.clear()
        }
    }

    /**
     * 显示错误信息
     */
    private fun showError(message: String) {
        tvError.text = message
        tvError.visibility = View.VISIBLE
    }

    /**
     * 重新打开App
     */
    private fun reopenApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        startActivity(intent)
        finish()
    }

    /**
     * 禁用返回键
     */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // 不执行任何操作，阻止返回
    }
}
```

- [ ] **Step 2: 在AndroidManifest.xml中注册Activity**

在 `qiaoqiao_companion/android/app/src/main/AndroidManifest.xml` 的 `<application>` 标签内添加:

```xml
        <!-- App锁屏覆盖Activity -->
        <activity
            android:name=".activities.AppLockOverlayActivity"
            android:exported="false"
            android:excludeFromRecents="true"
            android:launchMode="singleTask"
            android:taskAffinity=""
            android:theme="@style/Theme.AppCompat.Light.NoActionBar" />
```

- [ ] **Step 3: 验证文件创建成功**

Run: `ls -la qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/activities/`
Expected: `AppLockOverlayActivity.kt` 文件存在

- [ ] **Step 4: Commit**

```bash
cd qiaoqiao_companion
git add android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/activities/AppLockOverlayActivity.kt
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): add AppLockOverlayActivity for lock screen overlay"
```

---

## Task 5: 修改MonitorForegroundService添加onTaskRemoved处理

**Files:**
- Modify: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/services/MonitorForegroundService.kt`

- [ ] **Step 1: 在MonitorForegroundService中添加onTaskRemoved方法**

在 `MonitorForegroundService.kt` 文件末尾的 `onDestroy()` 方法之后添加:

```kotlin
    /**
     * 当任务被移除时调用（用户在最近任务中滑掉App）
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d(TAG, "Task removed by user")

        // 检查是否启用了防关闭锁
        if (AppLockManager.isLockEnabled(applicationContext)) {
            Log.d(TAG, "App lock is enabled, showing overlay")

            // 启动锁屏覆盖
            AppLockOverlayActivity.start(applicationContext)

            // 尝试重启服务
            try {
                val restartIntent = Intent(applicationContext, MonitorForegroundService::class.java)
                restartIntent.action = "START"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    applicationContext.startForegroundService(restartIntent)
                } else {
                    applicationContext.startService(restartIntent)
                }
                Log.d(TAG, "Service restart triggered")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to restart service", e)
            }
        }

        super.onTaskRemoved(rootIntent)
    }
```

- [ ] **Step 2: 添加必要的import**

在文件顶部的import区域添加:

```kotlin
import com.qiaoqiao.qiaoqiao_companion.activities.AppLockOverlayActivity
import com.qiaoqiao.qiaoqiao_companion.managers.AppLockManager
```

- [ ] **Step 3: 验证修改**

Run: `grep -n "onTaskRemoved" qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/services/MonitorForegroundService.kt`
Expected: 显示新增的onTaskRemoved方法

- [ ] **Step 4: Commit**

```bash
cd qiaoqiao_companion
git add android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/services/MonitorForegroundService.kt
git commit -m "feat(android): add onTaskRemoved handler to trigger app lock overlay"
```

---

## Task 6: 注册AppLockChannel到Application

**Files:**
- Modify: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/QiaoqiaoApplication.kt`

- [ ] **Step 1: 在QiaoqiaoApplication中注册AppLockChannel**

修改 `QiaoqiaoApplication.kt`:

```kotlin
package com.qiaoqiao.qiaoqiao_companion

import android.app.Application
import android.util.Log
import androidx.work.Configuration
import com.qiaoqiao.qiaoqiao_companion.channels.AppLockChannel
import com.qiaoqiao.qiaoqiao_companion.workers.KeepAliveWorker
import io.flutter.plugin.common.MethodChannel

/**
 * 应用 Application 类
 * 初始化后台保活组件
 */
class QiaoqiaoApplication : Application(), Configuration.Provider {

    companion object {
        private const val TAG = "QiaoqiaoApplication"
    }

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setMinimumLoggingLevel(Log.DEBUG)
            .build()

    private var appLockChannel: AppLockChannel? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Application onCreate")

        // 初始化App锁通道
        appLockChannel = AppLockChannel(this).apply {
            init()
        }

        // 注意：已实现 Configuration.Provider 接口，WorkManager 会自动使用 workManagerConfiguration
        // 不需要手动调用 WorkManager.initialize()

        // 启动后台保活任务
        KeepAliveWorker.start(this)
        Log.d(TAG, "Keep-alive worker initialized")
    }

    /**
     * 获取App锁通道实例
     * 供Flutter引擎使用
     */
    fun getAppLockChannel(): MethodChannel.MethodCallHandler? {
        return appLockChannel
    }
}
```

- [ ] **Step 2: 在MainActivity中注册MethodChannel**

修改 `MainActivity.kt`，在 `configureFlutterEngine` 方法中添加通道注册。首先查看当前内容:

Read: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/MainActivity.kt`

- [ ] **Step 3: Commit**

```bash
cd qiaoqiao_companion
git add android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/QiaoqiaoApplication.kt
git commit -m "feat(android): register AppLockChannel in Application"
```

---

## Task 7: 在MainActivity中注册MethodChannel

**Files:**
- Modify: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/MainActivity.kt`

- [ ] **Step 1: 查看当前MainActivity内容**

Run: `cat qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/MainActivity.kt`

- [ ] **Step 2: 修改MainActivity添加AppLockChannel注册**

将 `MainActivity.kt` 修改为:

```kotlin
package com.qiaoqiao.qiaoqiao_companion

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.qiaoqiao.qiaoqiao_companion.channels.AppLockChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 注册App锁通道
        val appLockChannel = AppLockChannel(this).apply {
            init()
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AppLockChannel.CHANNEL_NAME
        ).setMethodCallHandler(appLockChannel)
    }
}
```

- [ ] **Step 3: 验证修改**

Run: `grep -n "AppLockChannel" qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/MainActivity.kt`
Expected: 显示AppLockChannel相关代码

- [ ] **Step 4: Commit**

```bash
cd qiaoqiao_companion
git add android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/MainActivity.kt
git commit -m "feat(android): register AppLockChannel in MainActivity"
```

---

## Task 8: 创建Flutter端AppLockService

**Files:**
- Create: `qiaoqiao_companion/lib/core/platform/app_lock_service.dart`

- [ ] **Step 1: 创建app_lock_service.dart**

```dart
import 'package:flutter/services.dart';

/// App锁服务
/// 管理防关闭锁屏功能
class AppLockService {
  AppLockService._();

  static const _channel = MethodChannel('com.qiaoqiao.qiaoqiao_companion/app_lock');

  /// 检查锁屏是否启用
  static Future<bool> isLockEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLockEnabled');
      return result ?? true;
    } on PlatformException catch (e) {
      print('检查锁屏状态失败: ${e.message}');
      return true; // 默认启用
    }
  }

  /// 设置锁屏启用状态
  static Future<bool> setLockEnabled(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>('setLockEnabled', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('设置锁屏状态失败: ${e.message}');
      return false;
    }
  }

  /// 验证家长密码
  static Future<bool> verifyPassword(String password) async {
    try {
      final result = await _channel.invokeMethod<bool>('verifyPassword', {
        'password': password,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('验证密码失败: ${e.message}');
      return false;
    }
  }

  /// 获取上次触发时间
  static Future<int> getLastTriggerTime() async {
    try {
      final result = await _channel.invokeMethod<int>('getLastTriggerTime');
      return result ?? 0;
    } on PlatformException catch (e) {
      print('获取上次触发时间失败: ${e.message}');
      return 0;
    }
  }
}
```

- [ ] **Step 2: 验证文件创建成功**

Run: `ls -la qiaoqiao_companion/lib/core/platform/`
Expected: `app_lock_service.dart` 文件存在

- [ ] **Step 3: Commit**

```bash
cd qiaoqiao_companion
git add lib/core/platform/app_lock_service.dart
git commit -m "feat(flutter): add AppLockService for Flutter-Native communication"
```

---

## Task 9: 创建Flutter端AppLockProvider

**Files:**
- Create: `qiaoqiao_companion/lib/shared/providers/app_lock_provider.dart`

- [ ] **Step 1: 创建app_lock_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/platform/app_lock_service.dart';

/// App锁状态
class AppLockState {
  final bool isEnabled;
  final bool isLoading;
  final int lastTriggerTime;
  final String? error;

  const AppLockState({
    this.isEnabled = true,
    this.isLoading = false,
    this.lastTriggerTime = 0,
    this.error,
  });

  AppLockState copyWith({
    bool? isEnabled,
    bool? isLoading,
    int? lastTriggerTime,
    String? error,
  }) {
    return AppLockState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLoading: isLoading ?? this.isLoading,
      lastTriggerTime: lastTriggerTime ?? this.lastTriggerTime,
      error: error,
    );
  }
}

/// App锁Provider
final appLockProvider =
    StateNotifierProvider<AppLockNotifier, AppLockState>((ref) {
  return AppLockNotifier();
});

/// App锁Notifier
class AppLockNotifier extends StateNotifier<AppLockState> {
  AppLockNotifier() : super(const AppLockState()) {
    _init();
  }

  /// 初始化，加载当前状态
  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final isEnabled = await AppLockService.isLockEnabled();
    final lastTriggerTime = await AppLockService.getLastTriggerTime();
    state = AppLockState(
      isEnabled: isEnabled,
      lastTriggerTime: lastTriggerTime,
    );
  }

  /// 设置启用状态
  Future<bool> setEnabled(bool enabled) async {
    state = state.copyWith(isLoading: true, error: null);

    final success = await AppLockService.setLockEnabled(enabled);

    if (success) {
      state = state.copyWith(
        isEnabled: enabled,
        isLoading: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: '设置失败',
      );
      return false;
    }
  }

  /// 刷新状态
  Future<void> refresh() async {
    await _init();
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }
}
```

- [ ] **Step 2: 验证文件创建成功**

Run: `ls -la qiaoqiao_companion/lib/shared/providers/`
Expected: `app_lock_provider.dart` 文件存在

- [ ] **Step 3: Commit**

```bash
cd qiaoqiao_companion
git add lib/shared/providers/app_lock_provider.dart
git commit -m "feat(flutter): add AppLockProvider for state management"
```

---

## Task 10: 在家长设置页面添加防关闭开关

**Files:**
- Modify: `qiaoqiao_companion/lib/features/parent_mode/presentation/parent_mode_page.dart`

- [ ] **Step 1: 查看当前parent_mode_page.dart内容**

Run: `cat qiaoqiao_companion/lib/features/parent_mode/presentation/parent_mode_page.dart`

- [ ] **Step 2: 根据现有结构添加防关闭设置开关**

根据文件内容，在适当位置添加防关闭设置。通常在设置列表中添加:

```dart
// 在文件顶部添加import
import 'package:qiaoqiao_companion/shared/providers/app_lock_provider.dart';

// 在设置列表中添加以下组件（具体位置取决于现有结构）
Consumer(
  builder: (context, ref, child) {
    final appLockState = ref.watch(appLockProvider);
    return SwitchListTile(
      title: const Text('防关闭保护'),
      subtitle: const Text('防止孩子在最近任务中关闭App'),
      secondary: const Icon(Icons.lock),
      value: appLockState.isEnabled,
      onChanged: appLockState.isLoading
          ? null
          : (value) async {
              final success = await ref
                  .read(appLockProvider.notifier)
                  .setEnabled(value);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('设置失败，请重试')),
                );
              }
            },
    );
  },
),
```

- [ ] **Step 3: 验证修改**

Run: `grep -n "app_lock_provider" qiaoqiao_companion/lib/features/parent_mode/presentation/parent_mode_page.dart`
Expected: 显示app_lock_provider相关代码

- [ ] **Step 4: Commit**

```bash
cd qiaoqiao_companion
git add lib/features/parent_mode/presentation/parent_mode_page.dart
git commit -m "feat(flutter): add app lock toggle to parent settings page"
```

---

## Task 11: 构建和测试

- [ ] **Step 1: 清理并获取依赖**

Run: `cd qiaoqiao_companion && flutter clean && flutter pub get`
Expected: 命令成功完成

- [ ] **Step 2: 分析代码**

Run: `cd qiaoqiao_companion && flutter analyze`
Expected: 无错误（warnings可接受）

- [ ] **Step 3: 构建APK**

Run: `cd qiaoqiao_companion && flutter build apk --debug`
Expected: 构建成功

- [ ] **Step 4: 功能测试清单**

手动测试以下场景:

1. **启用防关闭保护测试**:
   - 进入家长模式 → 设置 → 启用"防关闭保护"
   - 回到主页，滑掉App（最近任务中上滑）
   - 预期: 显示锁屏覆盖界面

2. **密码解锁测试**:
   - 在锁屏界面输入错误密码
   - 预期: 显示"密码错误"提示
   - 输入正确密码
   - 预期: 锁屏界面消失

3. **禁用防关闭保护测试**:
   - 进入家长模式 → 设置 → 禁用"防关闭保护"
   - 回到主页，滑掉App
   - 预期: App正常关闭，不显示锁屏

4. **重新打开按钮测试**:
   - 触发锁屏界面
   - 点击"重新打开App"按钮
   - 预期: App重新启动到主页

- [ ] **Step 5: 最终Commit**

```bash
cd qiaoqiao_companion
git add -A
git commit -m "feat: complete app lock overlay implementation"
```

---

## 验证方法

### 功能测试

| 测试场景 | 预期结果 |
|----------|----------|
| 启用防关闭锁，滑掉App | 显示锁屏覆盖 |
| 输入错误密码 | 拒绝解除，显示错误 |
| 输入正确密码 | 解除锁定 |
| 禁用防关闭锁，滑掉App | 正常关闭 |
| 点击"重新打开" | App重新启动 |

### 兼容性测试

| 设备 | 状态 |
|------|------|
| 小米平板5 (MIUI 13/14) | 待测试 |
| 其他Android 8.0+设备 | 待测试 |

### 稳定性测试

- 多次滑掉/恢复循环
- 长时间后台运行后测试
- 低内存场景测试
