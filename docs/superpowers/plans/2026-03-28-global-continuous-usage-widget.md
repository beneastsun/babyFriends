# 全局连续使用计时 Widget 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现全局连续使用计时 Widget，- 当用户使用任何被监控 app 时，右上角显示计时器
- 计时器显示累计使用时间，- 接近限制时变成倒计时模式

**Architecture:**
1. 新增两种 Widget 模式： stopwatch（计时器）和 countdown（倒计时）
2. 当任何被监控 app 在前台时显示 stopwatch widget
3. 当剩余时间 <= 5 分钟时切换为 countdown widget
4. 复用现有的 OverlayChannel 原生实现

**Tech Stack:** Flutter + Dart + Kotlin (Android Native)

---

## 文件结构

| 文件 | 变更 | 职责 |
|-----|------|------|
| `lib/core/platform/overlay_service.dart` | 修改 | 添加 stopwatch widget 方法 |
| `lib/core/services/usage_monitor_service.dart` | 修改 | 管理 widget 显示/隐藏/切换逻辑 |
| `android/.../channels/OverlayChannel.kt` | 修改 | 实现 stopwatch widget 原生视图 |

---

## Task 1: 扩展 OverlayService 添加 Stopwatch Widget 支持

**Files:**
- Modify: `qiaoqiao_companion/lib/core/platform/overlay_service.dart`

- [ ] **Step 1.1: 添加 stopwatch widget 相关方法**

在 `OverlayService` 类中添加以下方法（在 `showCountdownWidget` 方法附近）：

```dart
  /// Stopwatch 模式下，累计时间更新回调
  static void Function(int elapsedSeconds)? _onStopwatchTick;

  /// 初始化服务（设置回调监听）- 扩展现有 init 方法
  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOverlayDismissed') {
        final packageName = call.arguments['packageName'] as String? ?? '';
        _onOverlayDismissed?.call(packageName);
        _onOverlayDismissed = null;
      } else if (call.method == 'onCountdownEnded') {
        _onCountdownEnded?.call();
        _onCountdownEnded = null;
      } else if (call.method == 'onCountdownAlert') {
        final alertType = call.arguments['alertType'] as String? ?? '';
        _onCountdownAlert?.call(alertType);
      } else if (call.method == 'onStopwatchTick') {
        // 新增：接收原生层的秒数更新
        final elapsedSeconds = call.arguments['elapsedSeconds'] as int? ?? 0;
        _onStopwatchTick?.call(elapsedSeconds);
      }
    });
  }

  /// 显示秒表悬浮窗（计时器模式）
  ///
  /// [initialSeconds] 初始已计时的秒数
  /// [onTick] 每秒更新回调
  static Future<void> showStopwatchWidget({
    required int initialSeconds,
    void Function(int elapsedSeconds)? onTick,
  }) async {
    _onStopwatchTick = onTick;

    await _channel.invokeMethod<void>(
      'showStopwatchWidget',
      {
        'initialSeconds': initialSeconds,
      },
    );
  }

  /// 更新秒表悬浮窗的时间
  static Future<void> updateStopwatchWidget(int elapsedSeconds) async {
    await _channel.invokeMethod<void>(
      'updateStopwatchWidget',
      {
        'elapsedSeconds': elapsedSeconds,
      },
    );
  }

  /// 切换秒表为倒计时模式
  static Future<void> switchToCountdown({
    required int remainingSeconds,
    void Function()? onEnded,
    void Function(String alertType)? onAlert,
  }) async {
    _onCountdownEnded = onEnded;
    _onCountdownAlert = onAlert;

    await _channel.invokeMethod<void>(
      'switchStopwatchToCountdown',
      {
        'remainingSeconds': remainingSeconds,
      },
    );
  }

  /// 隐藏秒表悬浮窗
  static Future<void> hideStopwatchWidget() async {
    _onStopwatchTick = null;
    await _channel.invokeMethod<void>('hideStopwatchWidget');
  }

  /// 检查秒表悬浮窗是否正在显示
  static Future<bool> isStopwatchWidgetShowing() async {
    final result = await _channel.invokeMethod<bool>('isStopwatchWidgetShowing');
    return result ?? false;
  }
```

- [ ] **Step 1.2: 验证 Dart 代码语法正确**

Run: `cd qiaoqiao_companion && flutter analyze lib/core/platform/overlay_service.dart`
Expected: 无错误

---

## Task 2: 实现 Android 原生 Stopwatch Widget

**Files:**
- Modify: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/channels/OverlayChannel.kt`

- [ ] **Step 2.1: 添加 stopwatch widget 相关属性**

在 `OverlayChannel` 类中添加以下属性（在 `countdownWidgetView` 附近，约第 72-75 行）：

```kotlin
    // 秒表悬浮窗相关
    private var stopwatchWidgetView: View? = null
    private var isStopwatchWidgetShowing = false
    private var stopwatchAnimator: ValueAnimator? = null
    private var stopwatchWidgetLayoutParams: WindowManager.LayoutParams? = null
    private var stopwatchElapsedSeconds = 0
```

- [ ] **Step 2.2: 在 onMethodCall 中添加新方法处理**

在 `onMethodCall` 方法中添加以下 case（在 `isCountdownWidgetShowing` case 之后）：

```kotlin
            "showStopwatchWidget" -> {
                val initialSeconds = call.argument<Int>("initialSeconds") ?: 0
                showStopwatchWidget(initialSeconds, result)
            }

            "updateStopwatchWidget" -> {
                val elapsedSeconds = call.argument<Int>("elapsedSeconds") ?: 0
                updateStopwatchWidget(elapsedSeconds)
                result.success(null)
            }

            "switchStopwatchToCountdown" -> {
                val remainingSeconds = call.argument<Int>("remainingSeconds") ?: 300
                switchStopwatchToCountdown(remainingSeconds, result)
            }

            "hideStopwatchWidget" -> {
                hideStopwatchWidget()
                result.success(null)
            }

            "isStopwatchWidgetShowing" -> {
                result.success(isStopwatchWidgetShowing)
            }
```

- [ ] **Step 2.3: 实现 showStopwatchWidget 方法**

在文件末尾（`hideCountdownWidget()` 方法之后）添加：

```kotlin
    // ==================== 秒表悬浮窗相关方法 ====================

    /**
     * 显示秒表悬浮窗
     * 位于屏幕右上角，可拖动，显示累计时间
     */
    private fun showStopwatchWidget(initialSeconds: Int, result: MethodChannel.Result) {
        if (!hasOverlayPermission(context)) {
            result.error("NO_PERMISSION", "没有悬浮窗权限", null)
            return
        }

        // 如果已经在显示，先更新时间
        if (isStopwatchWidgetShowing && stopwatchWidgetView != null) {
            updateStopwatchWidget(initialSeconds)
            result.success(null)
            return
        }

        try {
            windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

            stopwatchElapsedSeconds = initialSeconds
            stopwatchWidgetView = createStopwatchWidgetView(initialSeconds)

            stopwatchWidgetLayoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.END
                x = 32
                y = 100
            }

            windowManager?.addView(stopwatchWidgetView, stopwatchWidgetLayoutParams)
            isStopwatchWidgetShowing = true

            // 入场动画
            stopwatchWidgetView?.alpha = 0f
            stopwatchWidgetView?.animate()
                ?.alpha(1f)
                ?.setDuration(200)
                ?.setInterpolator(DecelerateInterpolator())
                ?.start()

            // 启动计时器
            startStopwatchTimer()

            result.success(null)
        } catch (e: Exception) {
            result.error("STOPWATCH_WIDGET_ERROR", e.message, null)
        }
    }

    /**
     * 创建秒表悬浮窗视图
     */
    private fun createStopwatchWidgetView(initialSeconds: Int): View {
        val density = context.resources.displayMetrics.density

        // 创建容器 - 圆角矩形背景
        val container = FrameLayout(context).apply {
            val cornerRadius = (16 * density).toInt()
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(0x80000000.toInt()) // 半透明黑色
                this.cornerRadius = cornerRadius.toFloat()
            }
            setPadding(
                (12 * density).toInt(),
                (8 * density).toInt(),
                (12 * density).toInt(),
                (8 * density).toInt()
            )
        }

        // 内容布局
        val contentLayout = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        // Emoji 图标 - 计时器模式用闹钟
        val emojiView = TextView(context).apply {
            text = "⏱️"
            textSize = 18f
            setPadding(0, 0, (8 * density).toInt(), 0)
        }

        // 计时文字
        val timeText = TextView(context).apply {
            id = View.generateViewId()
            tag = "stopwatch_time" // 用于后续查找
            text = formatStopwatchTime(initialSeconds)
            textSize = 16f
            setTextColor(0xFFFFFFFF.toInt())
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }

        contentLayout.addView(emojiView)
        contentLayout.addView(timeText)

        container.addView(contentLayout)

        // 设置拖动监听
        setupStopwatchDragListener(container)

        return container
    }

    /**
     * 格式化秒表时间（累计模式：显示已用时间）
     */
    private fun formatStopwatchTime(seconds: Int): String {
        val min = seconds / 60
        val sec = seconds % 60
        return String.format("%02d:%02d", min, sec)
    }

    /**
     * 启动秒表计时器
     */
    private fun startStopwatchTimer() {
        stopwatchAnimator?.cancel()

        stopwatchAnimator = ValueAnimator.ofInt(0, Int.MAX_VALUE).apply {
            duration = Long.MAX_VALUE // 无限时长
            interpolator = android.view.animation.LinearInterpolator()

            addUpdateListener { animation ->
                // 每秒更新一次
                val tick = animation.animatedValue as Int
                if (tick % 60 == 0) { // 约1秒（60fps）
                    stopwatchElapsedSeconds++
                    updateStopwatchTimeDisplay()

                    // 通知 Flutter
                    notifyStopwatchTick(stopwatchElapsedSeconds)
                }
            }
        }
        stopwatchAnimator?.start()
    }

    /**
     * 更新秒表时间显示
     */
    private fun updateStopwatchTimeDisplay() {
        stopwatchWidgetView?.let { view ->
            val timeText = view.findViewWithTag<TextView>("stopwatch_time")
            timeText?.text = formatStopwatchTime(stopwatchElapsedSeconds)
        }
    }

    /**
     * 更新秒表时间（外部调用）
     */
    private fun updateStopwatchWidget(elapsedSeconds: Int) {
        stopwatchElapsedSeconds = elapsedSeconds
        updateStopwatchTimeDisplay()
    }

    /**
     * 设置秒表拖动监听
     */
    private fun setupStopwatchDragListener(view: View) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        view.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    stopwatchWidgetLayoutParams?.let { params ->
                        initialX = params.x
                        initialY = params.y
                    }
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    stopwatchWidgetLayoutParams?.let { params ->
                        params.x = initialX + (initialTouchX - event.rawX).toInt()
                        params.y = initialY + (event.rawY - event.rawY).toInt()
                        windowManager?.updateViewLayout(view, params)
                    }
                    true
                }
                else -> false
            }
        }
    }

    /**
     * 通知 Flutter 秒表时间更新
     */
    private fun notifyStopwatchTick(elapsedSeconds: Int) {
        channel.invokeMethod("onStopwatchTick", mapOf("elapsedSeconds" to elapsedSeconds))
    }

    /**
     * 切换秒表为倒计时模式
     */
    private fun switchStopwatchToCountdown(remainingSeconds: Int, result: MethodChannel.Result) {
        if (!isStopwatchWidgetShowing || stopwatchWidgetView == null) {
            // 如果秒表没有显示，直接显示倒计时
            showCountdownWidget(remainingSeconds, result)
            return
        }

        try {
            // 停止秒表计时器
            stopwatchAnimator?.cancel()
            stopwatchAnimator = null

            // 更新视图
            val density = context.resources.displayMetrics.density
            stopwatchWidgetView?.let { view ->
                // 更新 emoji
                val emojiView = (view as? FrameLayout)
                    ?.getChildAt(0) as? LinearLayout
                    ?.getChildAt(0) as? TextView
                emojiView?.text = "🐻"

                // 更新时间文字 tag
                val timeText = view.findViewWithTag<TextView>("stopwatch_time")
                timeText?.tag = "countdown_time"
                timeText?.text = formatCountdownTime(remainingSeconds)
            }

            // 启动倒计时动画
            startCountdownFromStopwatch(remainingSeconds)

            result.success(null)
        } catch (e: Exception) {
            result.error("SWITCH_ERROR", e.message, null)
        }
    }

    /**
     * 从秒表切换后启动倒计时动画
     */
    private fun startCountdownFromStopwatch(totalSeconds: Int) {
        countdownAnimator?.cancel()

        notified3min = false
        notified2min = false

        countdownAnimator = ValueAnimator.ofInt(totalSeconds, 0).apply {
            duration = totalSeconds * 1000L
            interpolator = android.view.animation.LinearInterpolator()

            addUpdateListener { animation ->
                val current = animation.animatedValue as Int
                stopwatchWidgetView?.let { view ->
                    val timeText = view.findViewWithTag<TextView>("countdown_time")
                    timeText?.text = formatCountdownTime(current)
                }

                if (current <= 180 && current > 120 && !notified3min) {
                    notified3min = true
                    notifyCountdownAlert("3min")
                }
                if (current <= 120 && current > 60 && !notified2min) {
                    notified2min = true
                    notifyCountdownAlert("2min")
                }
            }

            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    stopwatchWidgetView?.let { view ->
                        val timeText = view.findViewWithTag<TextView>("countdown_time")
                        timeText?.text = formatCountdownTime(0)
                    }
                    notifyCountdownEnded()
                    hideStopwatchWidget()
                }
            })
        }
        countdownAnimator?.start()
    }

    /**
     * 隐藏秒表悬浮窗
     */
    private fun hideStopwatchWidget() {
        stopwatchAnimator?.cancel()
        stopwatchAnimator = null

        stopwatchWidgetView?.let { view ->
            view.animate()
                .alpha(0f)
                .setDuration(200)
                .setListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        try {
                            windowManager?.removeView(view)
                        } catch (e: Exception) {
                            // 忽略移除失败
                        }
                        stopwatchWidgetView = null
                        isStopwatchWidgetShowing = false
                        stopwatchElapsedSeconds = 0
                    }
                })
                .start()
        }
    }
```

- [ ] **Step 2.4: 验证 Kotlin 代码编译**

Run: `cd qiaoqiao_companion && flutter build apk --debug 2>&1 | head -50`
Expected: 编译成功无错误

---

## Task 3: 修改 UsageMonitorService 管理 Widget 生命周期

**Files:**
- Modify: `qiaoqiao_companion/lib/core/services/usage_monitor_service.dart`

- [ ] **Step 3.1: 添加 widget 状态跟踪变量**

在 `UsageMonitorService` 类中添加以下状态变量（在 `_countdownWidgetShowing` 附近，约第 50-52 行）：

```dart
  // === 悬浮窗状态 ===
  bool _countdownWidgetShowing = false;
  String? _countdownTriggerApp; // 触发倒计时的应用

  // 新增：秒表悬浮窗状态
  bool _stopwatchWidgetShowing = false;
```

- [ ] **Step 3.2: 修改 _handleContinuousUsageTransition 方法**

找到 `_handleContinuousUsageTransition` 方法（约第 110 行），替换为以下实现：

```dart
  /// 处理连续使用跟踪的应用切换
  Future<void> _handleContinuousUsageTransition(String? currentApp, DateTime now) async {
    final monitoredApps = _ref.read(monitoredAppsProvider);

    // 计算上次轮询以来的时间
    final elapsedSeconds = _lastPollTime != null
        ? now.difference(_lastPollTime!).inSeconds
        : 0;

    // 验证时间合理性（防止大跳跃）
    final validElapsed = (elapsedSeconds > 0 && elapsedSeconds <= monitorIntervalSeconds * 3)
        ? elapsedSeconds
        : 0;

    // Step 1: 只有在会话活跃且监控应用在前台时才累加时间
    if (_isSessionActive && _currentSessionApp != null && validElapsed > 0) {
      await _continuousUsageService.onAppStopped(_currentSessionApp!, validElapsed);
      print('[UsageMonitor] Accumulated ${validElapsed}s for $_currentSessionApp');
    }

    // Step 2: 判断当前应用是否需要跟踪
    final shouldTrackCurrent = currentApp != null && monitoredApps.isMonitored(currentApp);

    // Step 3: 处理会话状态变化
    if (shouldTrackCurrent) {
      // 当前应用需要监控
      if (_currentSessionApp != currentApp) {
        // 应用切换或首次进入，通知会话（会处理恢复逻辑）
        await _continuousUsageService.onAppStarted(currentApp);
        print('[UsageMonitor] Session now tracking: $currentApp');
      }
      _currentSessionApp = currentApp;
      _isSessionActive = true;

      // 显示/更新秒表悬浮窗
      await _ensureStopwatchWidgetVisible();
    } else {
      // 离开监控应用（息屏或切换到非监控app）
      if (_isSessionActive) {
        print('[UsageMonitor] Session paused (not tracking), currentApp: $currentApp');
      }
      _isSessionActive = false;

      // 隐藏秒表悬浮窗
      await _hideStopwatchWidget();
    }
  }
```

- [ ] **Step 3.3: 添加 _ensureStopwatchWidgetVisible 方法**

在 `_handleContinuousUsageTransition` 方法之后添加：

```dart
  /// 确保秒表悬浮窗可见（显示或切换为倒计时）
  Future<void> _ensureStopwatchWidgetVisible() async {
    final settings = _ref.read(continuousUsageSettingsProvider);
    if (!settings.enabled) {
      // 未启用连续使用限制，不显示悬浮窗
      await _hideStopwatchWidget();
      return;
    }

    final session = await _continuousUsageService.getActiveSession();
    if (session == null) {
      await _hideStopwatchWidget();
      return;
    }

    final limitSeconds = settings.limitMinutes * 60;
    final remainingSeconds = limitSeconds - session.totalDurationSeconds;

    if (remainingSeconds <= 5 * 60) {
      // 剩余 5 分钟或更少，切换到倒计时模式
      if (!_countdownWidgetShowing) {
        await _switchToCountdownMode(remainingSeconds);
      }
    } else {
      // 显示秒表模式（显示已用时间）
      await _showStopwatchMode(session.totalDurationSeconds);
    }
  }

  /// 显示秒表模式（显示已用时间）
  Future<void> _showStopwatchMode(int elapsedSeconds) async {
    if (_countdownWidgetShowing) {
      // 当前是倒计时模式，不切换回秒表
      return;
    }

    final isShowing = await OverlayService.isStopwatchWidgetShowing();
    if (isShowing) {
      // 已显示，更新时间
      await OverlayService.updateStopwatchWidget(elapsedSeconds);
    } else {
      // 显示秒表悬浮窗
      _stopwatchWidgetShowing = true;
      await OverlayService.showStopwatchWidget(
        initialSeconds: elapsedSeconds,
        onTick: (seconds) {
          // 可以在这里处理 Flutter 侧的时间同步
          // 当前实现依赖原生计时器，这里不需要处理
        },
      );
    }
  }

  /// 切换到倒计时模式
  Future<void> _switchToCountdownMode(int remainingSeconds) async {
    if (_countdownWidgetShowing) return;

    _countdownWidgetShowing = true;
    _stopwatchWidgetShowing = false;

    await OverlayService.switchToCountdown(
      remainingSeconds: remainingSeconds,
      onEnded: () {
        _countdownWidgetShowing = false;
        // 倒计时结束，触发强制休息
        if (_currentSessionApp != null) {
          _triggerForcedRestAfterCountdown(_currentSessionApp!);
        }
      },
      onAlert: (alertType) {
        if (_currentSessionApp != null) {
          _handleCountdownAlert(_currentSessionApp!, alertType);
        }
      },
    );

    print('[UsageMonitor] Switched to countdown mode, remaining: ${remainingSeconds}s');
  }

  /// 隐藏秒表悬浮窗
  Future<void> _hideStopwatchWidget() async {
    if (_stopwatchWidgetShowing) {
      await OverlayService.hideStopwatchWidget();
      _stopwatchWidgetShowing = false;
    }
  }
```

- [ ] **Step 3.4: 在 ContinuousUsageService 中添加 getActiveSession 方法**

修改 `qiaoqiao_companion/lib/core/services/continuous_usage_service.dart`，在 `getStatus()` 方法之后添加：

```dart
  /// 获取当前活跃会话
  Future<ContinuousSession?> getActiveSession() async {
    return await _sessionDao.getActiveSession(_today());
  }
```

- [ ] **Step 3.5: 修改 _checkContinuousUsageAlerts 方法**

找到 `_checkContinuousUsageAlerts` 方法，修改为不再触发提醒（由 widget 处理）：

```dart
  /// 检查连续使用提醒（5分钟/3分钟/2分钟警告）
  /// 注意：现在由悬浮窗 widget 处理提醒，此方法仅处理其他逻辑
  Future<void> _checkContinuousUsageAlerts(String currentApp) async {
    // 如果倒计时悬浮窗已经在显示，不再重复触发提醒
    if (_countdownWidgetShowing) {
      return;
    }

    // 5分钟警告逻辑已由 _ensureStopwatchWidgetVisible 处理（切换到倒计时模式）
    // 这里保留原有的弹窗提醒逻辑，在切换到倒计时时显示初始提醒

    final alertType = await _continuousUsageService.getAlertToShow();
    if (alertType == null) return;

    // 标记提醒已显示，避免重复
    await _continuousUsageService.markAlertShown(alertType);

    // 只在 5 分钟警告时显示弹窗（作为倒计时开始的提示）
    if (alertType == '5min') {
      final message = '连续使用即将达到限制，还剩 5 分钟，记得休息哦！';
      final ruleType = 'continuous_usage_5min';

      await _reminderService.checkAndShowForbiddenReminder(
        packageName: currentApp,
        reason: message,
        ruleType: ruleType,
      );

      print('[UsageMonitor] 已显示5分钟警告弹窗');
    }
  }
```

- [ ] **Step 3.6: 验证 Dart 代码**

Run: `cd qiaoqiao_companion && flutter analyze lib/core/services/`
Expected: 无错误

---

## Task 4: 修改 stopMonitoring 清理 Widget

**Files:**
- Modify: `qiaoqiao_companion/lib/core/services/usage_monitor_service.dart`

- [ ] **Step 4.1: 修改 stopMonitoring 方法**

找到 `stopMonitoring` 方法，添加隐藏秒表悬浮窗的逻辑：

```dart
  /// 停止监控
  void stopMonitoring() {
    // 记录最后的时长
    if (_isSessionActive && _currentSessionApp != null && _lastPollTime != null) {
      final now = DateTime.now();
      final durationSeconds = now.difference(_lastPollTime!).inSeconds;
      if (durationSeconds > 0 && durationSeconds <= monitorIntervalSeconds * 3) {
        _continuousUsageService.onAppStopped(_currentSessionApp!, durationSeconds);
        print('[UsageMonitor] Final accumulation: ${durationSeconds}s for $_currentSessionApp');
      }
    }

    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
    _currentSessionApp = null;
    _isSessionActive = false;
    _stopwatchWidgetShowing = false;
    _countdownWidgetShowing = false;
    _resetLockStates();

    // 隐藏所有悬浮窗
    OverlayService.hideStopwatchWidget();
    OverlayService.hideCountdownWidget();
  }
```

---

## Task 5: 测试验证

**Files:**
- Test: `qiaoqiao_companion/test/`

- [ ] **Step 5.1: 运行现有测试确保无回归**

Run: `cd qiaoqiao_companion && flutter test`
Expected: 所有测试通过

- [ ] **Step 5.2: 在真机上测试 Widget 功能**

1. 安装应用到小米平板
2. 配置连续使用限制（如 10 分钟）
3. 添加被监控应用
4. 打开被监控应用
5. 验证右上角显示秒表悬浮窗（⏱️ 格式：已用时间）
6. 使用被监控应用接近 5 分钟
7. 验证切换为倒计时悬浮窗（🐻 格式：剩余时间）
8. 验证 3 分钟、2 分钟时弹出提醒
9. 验证倒计时结束时触发强制休息

---

## Self-Review Checklist

### 1. Spec Coverage
- [x] 针对所有被监控 app 一起计算时限 - 已有 `ContinuousUsageService` 实现
- [x] 多个 app 只累加一次时间 - `_handleContinuousUsageTransition` 只在会话活跃时累加
- [x] 使用 widget 计时 - 新增 `stopwatchWidget` 原生实现
- [x] 右上角显示 - `gravity = Gravity.TOP or Gravity.END`
- [x] 接近限制时切换倒计时 - `_switchToCountdownMode` 方法

### 2. Placeholder Scan
- [x] 无 "TBD"、"TODO"、"implement later" 等占位符
- [x] 所有代码步骤包含完整代码

### 3. Type Consistency
- [x] `OverlayService.showStopwatchWidget` 签名与调用一致
- [x] `UsageMonitorService._ensureStopwatchWidgetVisible` 调用的方法存在

---

**Plan complete.** 两种执行方式：

**1. Subagent-Driven (推荐)** - 每个任务派发独立 subagent，任务间有审查，快速迭代

**2. Inline Execution** - 在当前会话中使用 executing-plans 逐批执行

**选择哪种方式？**
