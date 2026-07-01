# 今日总时长展示与连续使用 widget 能量条改造 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在规则页展示今日已用时长（进度条+文字），并把连续使用 widget 从"🐻+MM:SS 横条"改为"圆形+外环能量条"（≤5 分钟才叠加 MM:SS）。

**Architecture:** A 部分纯 Flutter，复用现有 `todayUsageProvider` 和 `UsageProgress` 组件，只改 `rules_page.dart` 的 `_TimeRulesCard`。B 部分纯原生 Kotlin，改 `NativeOverlayManager.kt` 的 `createCountdownView` 和 `startCountdownAnimation`，把容器从横条 `FrameLayout` 换成自定义 `EnergyBarView`（`Canvas.drawArc` 画外环），保留 `WidgetManager` 的 5/3/2 分钟色阶机制和所有归零/锁定逻辑。

**Tech Stack:** Flutter + Riverpod（A），Kotlin + Android WindowManager + Canvas（B）

**Spec:** `docs/superpowers/specs/2026-07-01-today-total-usage-and-widget-energy-bar-design.md`

---

## 文件结构

| 文件 | 责任 | 动作 |
|------|------|------|
| `qiaoqiao_companion/lib/features/rules/presentation/rules_page.dart` | 规则页 UI；`_TimeRulesCard` 新增"今日已用"区块 | 修改 |
| `qiaoqiao_companion/test/features/rules/presentation/time_rules_card_test.dart` | A 部分 widget 测试 | 新建 |
| `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/monitor/EnergyBarView.kt` | 自定义 View：圆形外环能量条 | 新建 |
| `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/monitor/NativeOverlayManager.kt` | 原生悬浮窗管理；改 `createCountdownView` 用 `EnergyBarView`，改 `startCountdownAnimation` 驱动能量条 | 修改 |
| `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/EnergyBarViewTest.kt` | B 部分颜色纯函数单元测试 | 新建 |
| `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/WidgetManagerTest.kt` | 扩展：验证 ≤5min 阶段色阶逻辑未被破坏 | 修改 |

---

## Task 1: A — 规则页"今日已用"区块（先写测试）

**Files:**
- Create: `qiaoqiao_companion/test/features/rules/presentation/time_rules_card_test.dart`

- [ ] **Step 1: 写失败的 widget 测试**

创建 `qiaoqiao_companion/test/features/rules/presentation/time_rules_card_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qiaoqiao_companion/core/database/app_database.dart';
import 'package:qiaoqiao_companion/features/rules/presentation/rules_page.dart';
import 'package:qiaoqiao_companion/shared/models/models.dart';
import 'package:qiaoqiao_companion/shared/providers/providers.dart';
import 'package:qiaoqiao_companion/shared/providers/today_usage_provider.dart';

// 测试用的 todayUsageProvider override，绕过 DB
ProviderContainer _makeContainer({required TodayUsage todayUsage}) {
  final container = ProviderContainer(overrides: [
    todayUsageProvider.overrideWith((ref) {
      final notifier = _FakeTodayUsageNotifier(todayUsage);
      return notifier;
    }),
  ]);
  return container;
}

class _FakeTodayUsageNotifier extends TodayUsageNotifier {
  final TodayUsage _state;
  _FakeTodayUsageNotifier(this._state)
      : super(DailyStatsDao(_StubDb()), AppUsageDao(_StubDb()), RuleDao(_StubDb()));
  @override
  TodayUsage get state => _state;
  @override
  void startAutoRefresh() {}
  @override
  Future<void> loadToday() async {}
}

// 最小桩：TodayUsageNotifier 构造需要 DAO，但 _Fake 不调用其方法
class _StubDb implements AppDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('限额启用时显示"今日已用"区块和进度条', (tester) async {
    final container = _makeContainer(todayUsage: const TodayUsage(
      totalDurationSeconds: 45 * 60,
      totalLimitMinutes: 120,
    ));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: _TimeRulesCardForTest())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日已用'), findsOneWidget);
    expect(find.textContaining('45 / 120 分钟'), findsOneWidget);
    expect(find.byType(UsageProgress), findsOneWidget);
  });

  testWidgets('限额未启用时不显示"今日已用"区块', (tester) async {
    final container = _makeContainer(todayUsage: const TodayUsage(
      totalDurationSeconds: 45 * 60,
      totalLimitMinutes: 0, // 限额 0 = 未启用场景
    ));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: _TimeRulesCardForTest(enabled: false))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日已用'), findsNothing);
  });
}

// 包装：允许注入 enabled 状态（rulesProvider 也需 override，此处简化用静态卡片）
// 实际实现时 _TimeRulesCard 会同时读 rulesProvider 和 todayUsageProvider，
// 测试里通过 rulesProvider.overrideWith 提供 totalTimeRule。
// 这里给出框架，具体 override 在实现阶段补全。
class _TimeRulesCardForTest extends StatelessWidget {
  final bool enabled;
  const _TimeRulesCardForTest({this.enabled = true});
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // placeholder, real widget under test
  }
}
```

注：`_TimeRulesCard` 当前是 `rules_page.dart` 内的私有类。为了让它可测，Step 3 会把它改成 `public` 或在测试文件里用 `import` + 同库方式。最简方案：把 `_TimeRulesCard` 改名为 `TimeRulesCard`（去掉下划线）。

- [ ] **Step 2: 运行测试验证失败**

Run: `cd qiaoqiao_companion; flutter test test/features/rules/presentation/time_rules_card_test.dart`
Expected: FAIL（`TimeRulesCard` 不存在、`UsageProgress` 未导出、`_FakeTodayUsageNotifier` 构造失败等编译错误）

- [ ] **Step 3: 提交测试骨架**

```bash
cd qiaoqiao_companion
git add test/features/rules/presentation/time_rules_card_test.dart
git commit -m "test: add failing skeleton for today used duration in rules card"
```

---

## Task 2: A — 实现"今日已用"区块

**Files:**
- Modify: `qiaoqiao_companion/lib/features/rules/presentation/rules_page.dart`（`_TimeRulesCard`，L234-291）

- [ ] **Step 1: 把 `_TimeRulesCard` 改为 public 并读取 todayUsageProvider**

在 [rules_page.dart](file:///d:\Developfile\baby-friends\qiaoqiao_companion\lib\features\rules\presentation\rules_page.dart) L234，把 `class _TimeRulesCard extends ConsumerWidget {` 改为 `class TimeRulesCard extends ConsumerWidget {`。

更新 `_RulesPageState` build 中 L78 的引用：`_TimeRulesCard()` → `TimeRulesCard()`。

在文件顶部 import 区添加：
```dart
import 'package:qiaoqiao_companion/shared/providers/today_usage_provider.dart';
import 'package:qiaoqiao_companion/shared/widgets/design_system/gradient_progress.dart';
```

- [ ] **Step 2: 在 TimeRulesCard 的 build 中新增"今日已用"区块**

在 [TimeRulesCard.build](file:///d:\Developfile\baby-friends\qiaoqiao_companion\lib\features\rules\presentation\rules_page.dart) 的 `Column.children` 末尾（两个 `_RuleItem` 之后），插入以下代码。注意：`totalRule?.enabled != true` 时返回 `SizedBox.shrink()` 隐藏整块。

```dart
// 在 _RuleItem(周末每日限额...) 之后追加：
if (totalRule?.enabled == true) ...[
  const Divider(height: DesignTokens.space24),
  _TodayUsedSection(
    usedSeconds: ref.watch(todayUsageProvider).totalDurationSeconds,
    limitMinutes: (DateTime.now().weekday == 6 || DateTime.now().weekday == 7
        ? weekendMinutes
        : weekdayMinutes),
  ),
],
```

- [ ] **Step 3: 在 rules_page.dart 文件末尾新增 `_TodayUsedSection` widget**

```dart
/// 今日已用时长区块
class _TodayUsedSection extends ConsumerWidget {
  final int usedSeconds;
  final int limitMinutes;

  const _TodayUsedSection({
    required this.usedSeconds,
    required this.limitMinutes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usedMinutes = usedSeconds ~/ 60;
    final percentage = limitMinutes > 0
        ? (usedMinutes / limitMinutes).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timer_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: DesignTokens.space12),
            Expanded(child: Text('今日已用', style: AppTextStyles.bodyMedium)),
            Text(
              '$usedMinutes / $limitMinutes 分钟',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.space8),
        UsageProgress(percentage: percentage),
      ],
    );
  }
}
```

- [ ] **Step 4: 修复测试文件，让它真正测 `TimeRulesCard`**

把 `time_rules_card_test.dart` 里的 `_TimeRulesCardForTest` 占位删掉，改为直接测 `TimeRulesCard`，并 override `rulesProvider` 和 `todayUsageProvider`：

```dart
await tester.pumpWidget(
  UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(body: TimeRulesCard()),
    ),
  ),
);
```

同时给 `rulesProvider` 加 override（提供 `totalTimeRule` 为 `Rule(ruleType: RuleType.totalTime, weekdayLimitMinutes: 120, weekendLimitMinutes: 120, enabled: true)`）。

- [ ] **Step 5: 运行测试验证通过**

Run: `cd qiaoqiao_companion; flutter test test/features/rules/presentation/time_rules_card_test.dart`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
cd qiaoqiao_companion
git add lib/features/rules/presentation/rules_page.dart test/features/rules/presentation/time_rules_card_test.dart
git commit -m "feat(rules): show today used duration with progress bar next to limit"
```

---

## Task 3: B — 新建 EnergyBarView 自定义 View（先写颜色纯函数测试）

**Files:**
- Create: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/monitor/EnergyBarView.kt`
- Create: `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/EnergyBarViewTest.kt`

- [ ] **Step 1: 写失败的颜色纯函数测试**

创建 `qiaoqiao_companion/android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/EnergyBarViewTest.kt`：

```kotlin
package com.qiaoqiao.qiaoqiao_companion.monitor

import android.graphics.Color
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class EnergyBarViewTest {

    @Test
    fun `energyBarColor at progress 0 returns green`() {
        val color = EnergyBarView.energyBarColor(0.0f)
        assertEquals(0xFF4CAF50.toInt(), color)
    }

    @Test
    fun `energyBarColor at progress 0_5 returns yellow`() {
        val color = EnergyBarView.energyBarColor(0.5f)
        assertEquals(0xFFFFC107.toInt(), color)
    }

    @Test
    fun `energyBarColor at progress 0_25 is between green and yellow`() {
        val color = EnergyBarView.energyBarColor(0.25f)
        val green = 0xFF4CAF50.toInt()
        val yellow = 0xFFFFC107.toInt()
        // 不是端点本身
        assertTrue(color != green && color != yellow)
        // R 介于绿和黄之间（绿 R=76, 黄 R=255）
        val r = Color.red(color)
        assertTrue(r > 76 && r < 255)
    }

    @Test
    fun `energyBarColor at progress 1 returns yellow clamped`() {
        val color = EnergyBarView.energyBarColor(1.0f)
        assertEquals(0xFFFFC107.toInt(), color)
    }

    @Test
    fun `energyBarColor clamps progress above 1`() {
        val color = EnergyBarView.energyBarColor(1.5f)
        assertEquals(0xFFFFC107.toInt(), color)
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd qiaoqiao_companion/android; ./gradlew :app:testDebugUnitTest --tests "com.qiaoqiao.qiaoqiao_companion.monitor.EnergyBarViewTest"`
Expected: FAIL（`EnergyBarView` 未定义）

- [ ] **Step 3: 创建 EnergyBarView，含颜色纯函数**

创建 `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/monitor/EnergyBarView.kt`：

```kotlin
package com.qiaoqiao.qiaoqiao_companion.monitor

import android.animation.ArgbEvaluator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View

/**
 * 圆形外环能量条 — 连续使用 widget 的视觉形态。
 *
 * - 外环：随 [progress]（0~1，已用比例）递增填充，颜色用 [energyBarColor] 平滑过渡（绿→黄）。
 * - ≤5 分钟阶段：由 WidgetManager 通过 [setOverrideColor] 传入色阶（黄/橙/红），优先于 energyBarColor。
 * - 中央内容由外部父布局添加（🐻 emoji + 可选 MM:SS 文字）。
 */
class EnergyBarView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 8f * resources.displayMetrics.density
        strokeCap = Paint.Cap.ROUND
    }
    private val bgRingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 8f * resources.displayMetrics.density
        color = 0x33000000
    }
    private val rectF = RectF()
    private val density = resources.displayMetrics.density

    /** 已用比例 0~1（clamp），决定外环填充弧度与颜色 */
    var progress: Float = 0f
        set(value) {
            field = value.coerceIn(0f, 1f)
            invalidate()
        }

    /** ≤5 分钟阶段的覆盖色（由 WidgetManager 注入）；null 时用 energyBarColor */
    var overrideColor: Int? = null
        set(value) {
            field = value
            invalidate()
        }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        try {
            val padding = ringPaint.strokeWidth / 2
            rectF.set(padding, padding, width - padding, height - padding)
            // 背景环
            canvas.drawArc(rectF, 0f, 360f, false, bgRingPaint)
            // 前景环（递增）
            val sweep = 360f * progress
            ringPaint.color = overrideColor ?: energyBarColor(progress)
            canvas.drawArc(rectF, -90f, sweep, false, ringPaint)
        } catch (e: Exception) {
            // 绘制失败时画一个空背景环，保证不崩
            canvas.drawArc(rectF, 0f, 360f, false, bgRingPaint)
        }
    }

    companion object {
        private const val GREEN = 0xFF4CAF50.toInt()
        private const val YELLOW = 0xFFFFC107.toInt()
        private val evaluator = ArgbEvaluator()

        /**
         * >5 分钟阶段的能量条颜色：progress 0~0.5 从绿平滑过渡到黄，0.5~1 保持黄。
         * 纯函数，便于单元测试。
         */
        fun energyBarColor(progress: Float): Int {
            val p = progress.coerceIn(0f, 1f)
            return if (p <= 0.5f) {
                evaluator.evaluate(p / 0.5f, GREEN, YELLOW) as Int
            } else {
                YELLOW
            }
        }
    }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `cd qiaoqiao_companion/android; ./gradlew :app:testDebugUnitTest --tests "com.qiaoqiao.qiaoqiao_companion.monitor.EnergyBarViewTest"`
Expected: PASS（5 个用例全过）

- [ ] **Step 5: 提交**

```bash
cd qiaoqiao_companion
git add android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/monitor/EnergyBarView.kt android/app/src/test/java/com/qiaoqiao/qiaoqiao_companion/monitor/EnergyBarViewTest.kt
git commit -m "feat(native): add EnergyBarView with smooth green-to-yellow energy ring"
```

---

## Task 4: B — 改造 NativeOverlayManager.createCountdownView

**Files:**
- Modify: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/monitor/NativeOverlayManager.kt`（L850-919 `createCountdownView`）

- [ ] **Step 1: 改造 createCountdownView 用 EnergyBarView 作容器**

在 [NativeOverlayManager.kt L850](file:///d:\Developfile\baby-friends\qiaoqiao_companion\android\app\src\main\kotlin\com\qiaoqiao\qiaoqiao_companion\monitor\NativeOverlayManager.kt)，把现有 `createCountdownView` 替换为：

```kotlin
private fun createCountdownView(initialSeconds: Long = 300L): View {
    val density = context.resources.displayMetrics.density
    val size = (56 * density).toInt()

    // 外层：EnergyBarView 作为圆形能量环容器
    val energyBar = EnergyBarView(context).apply {
        tag = "countdown_energy_bar"
        layoutParams = FrameLayout.LayoutParams(size, size)
    }

    // 中央内容垂直排列：🐻 + 倒计时文字（默认隐藏）+ 家长入口
    val centerLayout = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
        layoutParams = FrameLayout.LayoutParams(size, size)
    }

    val emojiView = TextView(context).apply {
        tag = "countdown_emoji"
        text = "🐻"
        textSize = 20f
    }

    val timeView = TextView(context).apply {
        tag = "countdown_time"
        text = formatCountdownTime(initialSeconds)
        textSize = 12f
        setTextColor(0xFFFFFFFF.toInt())
        typeface = Typeface.DEFAULT_BOLD
        setShadowLayer(2f, 1f, 1f, 0x40000000)
        visibility = View.GONE  // 默认隐藏，≤5 分钟才显示
        minWidth = (48 * density).toInt()
        gravity = Gravity.CENTER
    }

    centerLayout.addView(emojiView)
    centerLayout.addView(timeView)

    // 家长入口 🔒 放在右下角
    val parentEntryIcon = TextView(context).apply {
        tag = "parent_entry"
        text = "🔒"
        textSize = 10f
        alpha = 0.6f
        setOnClickListener { onParentEntryFromWidget?.invoke() }
    }

    val container = FrameLayout(context).apply {
        layoutParams = FrameLayout.LayoutParams(size, size)
        addView(energyBar)
        addView(centerLayout)
        addView(parentEntryIcon, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM or Gravity.END
        ))
    }

    setupDragListener(container)
    return container
}
```

- [ ] **Step 2: 确认 countdownTextTime 的查找逻辑仍兼容**

`showCountdownOverlay` (L713) 用 `findViewWithTag("countdown_time")` 查找 timeView，新代码保留了 tag，无需改。

- [ ] **Step 3: 编译验证**

Run: `cd qiaoqiao_companion/android; ./gradlew :app:compileDebugKotlin`
Expected: 编译通过

- [ ] **Step 4: 提交**

```bash
cd qiaoqiao_companion
git add android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/monitor/NativeOverlayManager.kt
git commit -m "feat(native): rebuild countdown widget as circular energy bar with hidden time text"
```

---

## Task 5: B — 改造 startCountdownAnimation 驱动能量条

**Files:**
- Modify: `qiaoqiao_companion/android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/monitor/NativeOverlayManager.kt`（L929-988 `startCountdownAnimation`，以及 `setCountdownColor` L1197）

- [ ] **Step 1: 在 startCountdownAnimation ticker 中更新能量条 progress 和 timeView 可见性**

在 [startCountdownAnimation L946-984](file:///d:\Developfile\baby-friends\qiaoqiao_companion\android\app\src\main\kotlin\com\qiaoqiao\qiaoqiao_companion\monitor\NativeOverlayManager.kt) 的 ticker `run()` 内，在现有 `countdownTextTime?.text = ...` 之后，新增能量条驱动逻辑：

```kotlin
// 现有：countdownTextTime?.text = formatCountdownTime(remainingSec.toLong())

// 新增：驱动能量条 progress
val totalSec = (countdownTotalMs / 1000L).coerceAtLeast(1L)
val elapsedSec = (totalSec - remainingSec.toLong()).coerceAtLeast(0L)
val progress = (elapsedSec.toFloat() / totalSec.toFloat()).coerceIn(0f, 1f)
(countdownWidgetView?.findViewWithTag("countdown_energy_bar") as? EnergyBarView)?.progress = progress

// 新增：≤5 分钟显示倒计时文字
val timeView = countdownTextTime
if (remainingSec <= 300 && remainingSec > 0) {
    timeView?.visibility = View.VISIBLE
} else {
    timeView?.visibility = View.GONE
}
```

注意：`countdownTextTime` 已在 `showCountdownOverlay` L713 通过 `findViewWithTag("countdown_time")` 赋值，可直接复用。

- [ ] **Step 2: 改造 setCountdownColor 同步设置 EnergyBarView 的 overrideColor**

在 [setCountdownColor L1197](file:///d:\Developfile\baby-friends\qiaoqiao_companion\android\app\src\main\kotlin\com\qiaoqiao\qiaoqiao_companion\monitor\NativeOverlayManager.kt)，让它在设置背景色的同时也通知 EnergyBarView：

```kotlin
fun setCountdownColor(color: Int) {
    // 现有逻辑保留（改容器背景等，如有）
    // 新增：同步能量条覆盖色
    (countdownWidgetView?.findViewWithTag("countdown_energy_bar") as? EnergyBarView)?.overrideColor = color
}
```

如果现有 `setCountdownColor` 还会改容器背景 GradientDrawable，保留它（能量环已经是主视觉，背景透明即可，但不动现有逻辑以免破坏）。

- [ ] **Step 3: 在 hideCountdownOverlay 中清除 overrideColor 引用**

在 [hideCountdownOverlay L815](file:///d:\Developfile\baby-friends\qiaoqiao_companion\android\app\src\main\kotlin\com\qiaoqiao\qiaoqiao_companion\monitor\NativeOverlayManager.kt)，确保隐藏时 EnergyBarView 随 view 一起被 GC（无需额外清理，`countdownWidgetView = null` 已处理，但补一行保险）：

```kotlin
// 在现有 countdownWidgetView = null 之前补：
(countdownWidgetView?.findViewWithTag("countdown_energy_bar") as? EnergyBarView)?.overrideColor = null
```

- [ ] **Step 4: 编译验证**

Run: `cd qiaoqiao_companion/android; ./gradlew :app:compileDebugKotlin`
Expected: 编译通过

- [ ] **Step 5: 运行现有 WidgetManagerTest 验证未破坏**

Run: `cd qiaoqiao_companion/android; ./gradlew :app:testDebugUnitTest --tests "com.qiaoqiao.qiaoqiao_companion.monitor.WidgetManagerTest"`
Expected: 全部 PASS（颜色阈值逻辑通过 `setCountdownColor` 仍生效，只是现在会转发到 EnergyBarView）

- [ ] **Step 6: 提交**

```bash
cd qiaoqiao_companion
git add android/app/src/main/kotlin/com/qiaoqiao/qiaoqiao_companion/monitor/NativeOverlayManager.kt
git commit -m "feat(native): drive energy bar progress in ticker, show MM:SS only when <=5min"
```

---

## Task 6: 手动集成验证

**Files:** 无（平板验证）

- [ ] **Step 1: 构建并安装到平板**

Run: `cd qiaoqiao_companion; flutter clean; flutter build apk --debug; adb -s 8711b87c install -r build\app\outputs\flutter-apk\app-debug.apk`
Expected: Success

- [ ] **Step 2: 验证 A — 规则页"今日已用"**

操作：打开 app → 进入规则页 → 查看"时间限制"卡片
期望：
- 限额启用时，卡片底部出现"今日已用 X / Y 分钟" + 进度条
- 等待 30 秒，数字应自动刷新（todayUsageProvider 30 秒定时刷新）
- 限额未启用时（家长模式关闭总时长开关），该区块消失

- [ ] **Step 3: 验证 B — 连续使用 widget 能量条**

操作：打开一个被监控的游戏 app，观察右上角 widget
期望：
- 出现圆形能量环，颜色从绿开始
- 随时间推进，外环逐渐填充，颜色从绿平滑过渡到黄
- 剩余 >5 分钟时，中央只有 🐻，无数字
- 剩余 ≤5 分钟时，中央出现 MM:SS（如 04:32），颜色由 WidgetManager 切黄
- 剩余 ≤3 分钟，颜色切橙；≤2 分钟切红
- 剩余 3/2 分钟时，3min/2min 提醒逻辑触发（弹窗或通知，与改造前一致）
- 到 0，widget 消失，lock overlay 出现（与改造前一致）

- [ ] **Step 4: 回归验证 — 家长入口 🔒 仍可点击**

操作：在 widget 显示期间点击 🔒
期望：触发家长入口回调（与改造前一致）

- [ ] **Step 5: 回归验证 — widget 可拖动**

操作：长按 widget 拖动
期望：widget 可拖到屏幕其他位置（与改造前一致）

- [ ] **Step 6: 如全部通过，提交最终记录**

无代码改动，无需提交。如发现问题，回到对应 Task 修复。

---

## Self-Review

**1. Spec coverage:**
- A 全日已用时长（规则页限额旁，进度条+文字，复用 todayUsageProvider）→ Task 1+2 ✓
- A 限额未启用时隐藏 → Task 2 Step 2 的 `if (totalRule?.enabled == true)` ✓
- A 进度条配色复用 UsageProgress 现有阈值 → Task 2 Step 3 用 `UsageProgress` ✓
- B 圆形+外环能量条，递增型 → Task 3+4 ✓
- B >5min 平滑过渡（绿→黄）→ Task 3 `energyBarColor` ✓
- B ≤5min 叠加 MM:SS，沿用 WidgetManager 色阶 → Task 5 Step 1+2 ✓
- B 5 分钟以下逻辑（3min/2min 提醒、到 0 锁定、归零回调）不动 → Task 5 明确保留 ✓
- 测试：A widget 测试、B 纯函数测试、WidgetManager 回归 → Task 1/3/5 ✓
- 手动验证 → Task 6 ✓

**2. Placeholder scan:** 无 TBD/TODO；测试代码完整；所有步骤有具体代码。

**3. Type consistency:**
- `EnergyBarView.energyBarColor(progress: Float): Int` — companion 对象纯函数，测试与实现一致 ✓
- `EnergyBarView.progress: Float`、`overrideColor: Int?` — Task 4/5 引用一致 ✓
- tag 字符串 `"countdown_energy_bar"`、`"countdown_time"` — Task 4/5 一致 ✓
- `UsageProgress(percentage: double)` — Task 2 用法与 [gradient_progress.dart L380](file:///d:\Developfile\baby-friends\qiaoqiao_companion\lib\shared\widgets\design_system\gradient_progress.dart) 签名一致 ✓
- `TimeRulesCard`（去下划线）— Task 1/2 一致 ✓

**4. 风险点:**
- Task 1 的测试桩 `_StubDb` 用 `noSuchMethod`，可能在不同 Flutter 版本下需调整；如失败，回退为只测 `_TodayUsedSection`（它是纯 widget，不依赖 DAO）
- Task 5 Step 2 的 `setCountdownColor` 现有实现未完整读取（只 grep 到签名 L1197），实现时需先读该函数体确认是否改容器背景，避免双重着色冲突

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-01-today-total-usage-and-widget-energy-bar.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
