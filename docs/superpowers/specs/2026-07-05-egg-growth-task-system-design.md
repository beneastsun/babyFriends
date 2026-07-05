# 成长树任务系统设计规格

**日期**: 2026-07-05
**状态**: 已认可，待实现

## 背景与目标

qiaoqiao_companion 是一款帮助学龄前/低年级儿童管理 app 使用时长的应用。当前只有"限制"机制，缺少"正向激励"。成长树任务系统将"管理屏幕时间"从纯限制变为"完成任务→获得积分→兑换加时券"的正向激励机制，同时通过蛋仔成长形象和游戏化设计让儿童更愿意参与。

核心目标：
- 培养儿童自觉完成日常任务（健康运动、学习阅读等）
- 通过积分→加时券的奖励链路，将"做该做的事"和"获得更多使用时长"关联
- 通过蛋仔成长形象的游戏化设计，让打卡变成有趣的养成体验
- 通过惩罚机制（未完成扣减次日时长），确保任务有约束力

## 分阶段实现

**设计完整，实现分 3 个子项目串行交付**：

| 子项目 | 范围 | 依赖 |
|--------|------|------|
| **P1 核心任务系统** | 任务 CRUD、打卡、积分奖励/惩罚、数据库迁移、任务 Tab、家长端任务管理 | 无 |
| **P2 成长树与形象** | 蛋仔形象渲染、5阶段升级动画/语音/庆祝、4套风格切换 | P1 |
| **P3 任务提醒** | 定时提醒、未响应重复提醒、声音+展示性弹窗 | P1 |

每个子项目独立 spec→plan→实现，交付后可独立运行和验证。

## 确认的设计决策

- **任务创建**：纯家长设定，分类+自定义（健康运动/学习阅读/家务劳动/自律守则）
- **积分体系**：复用现有 `points_history` 表和 `PointsProvider`
- **奖励机制**：积分兑换加时券（复用现有 `CouponsProvider`），默认 10 积分 = 1 分钟
- **惩罚机制**：未完成基础次数→扣减**次日**使用时长，按任务设定惩罚分钟数
- **成长形象**：蛋仔风格，5 阶段，4 套风格可切换，衣服随成长升级
- **配色**：沿用现有主题色（`Theme.of(context)`），不自成一格

---

## P1 核心任务系统

### 数据库迁移（v5 → v6）

新增 3 张表 + 修复 2 个现有问题：

```sql
-- 1. 任务定义表（家长创建）
CREATE TABLE task_definitions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL DEFAULT '⭐',
  category TEXT NOT NULL,              -- health/study/chore/discipline
  base_points INTEGER NOT NULL,        -- 基础积分（完成1次得多少）
  extra_points INTEGER NOT NULL DEFAULT 0,  -- 超额额外积分
  min_daily_count INTEGER NOT NULL DEFAULT 1,  -- 每日最低完成次数
  max_daily_count INTEGER NOT NULL DEFAULT 1,  -- 单日上限次数
  daily_points_cap INTEGER,            -- 单日积分上限（null=不限）
  checkin_mode TEXT NOT NULL DEFAULT 'self',  -- self/parent_confirm/scheduled
  scheduled_time TEXT,                 -- HH:mm，仅 scheduled 模式
  penalty_minutes INTEGER NOT NULL DEFAULT 0,  -- 未完成扣减次日时长（分钟）
  reminder_time TEXT,                  -- 提醒时间 HH:mm
  reminder_repeat_interval INTEGER NOT NULL DEFAULT 0,  -- 未响应重复提醒间隔（分钟）
  enabled INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- 2. 任务打卡记录表
CREATE TABLE task_checkins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL,
  checkin_date TEXT NOT NULL,          -- YYYY-MM-DD
  checkin_time TEXT NOT NULL,          -- HH:mm:ss
  points_earned INTEGER NOT NULL DEFAULT 0,
  confirmed_by_parent INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (task_id) REFERENCES task_definitions(id)
);

-- 3. 每日任务惩罚记录表
CREATE TABLE task_penalties (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id INTEGER NOT NULL,
  penalty_date TEXT NOT NULL,          -- 惩罚生效日期（次日 YYYY-MM-DD）
  penalty_minutes INTEGER NOT NULL,
  reason TEXT NOT NULL,
  applied INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);

-- 修复1: user_achievements 建表（现有 bug，AchievementDao 引用但未建表）
CREATE TABLE IF NOT EXISTS user_achievements (
  achievement_id TEXT PRIMARY KEY,
  unlocked_at INTEGER NOT NULL,
  progress INTEGER NOT NULL DEFAULT 0,
  is_unlocked INTEGER NOT NULL DEFAULT 0
);

-- 修复2: points_history 添加 category 列（PointsHistory.toMap() 已写入该字段但表无此列）
ALTER TABLE points_history ADD COLUMN category TEXT NOT NULL DEFAULT 'other';
```

### 数据模型（Dart）

```dart
enum TaskCategory { health, study, chore, discipline }

enum CheckinMode { self, parentConfirm, scheduled }

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
}

class TaskCheckin {
  final int? id;
  final int taskId;
  final String checkinDate;
  final String checkinTime;
  final int pointsEarned;
  final bool confirmedByParent;
  final DateTime createdAt;
}

class TaskPenalty {
  final int? id;
  final int taskId;
  final String penaltyDate;
  final int penaltyMinutes;
  final String reason;
  final bool applied;
  final DateTime createdAt;
}
```

### 积分联动

完成打卡时积分发放规则：
- 基础次数内（第 1 ~ minDailyCount 次）：每次得 `basePoints` 积分
- 超额（第 minDailyCount+1 ~ maxDailyCount 次）：每次得 `extraPoints` 积分
- 单日积分上限：`dailyPointsCap`（null = 不限）
- PointsCategory 映射：health→exerciseReward, study→studyReward, chore→choreReward, discipline→restReward

积分兑换加时券：
- 复用现有 `CouponsProvider.exchange()` 机制
- 默认兑换比例：10 积分 = 1 分钟加时券（与现有 50 积分=5 分钟一致）
- 家长可在设置中自定义兑换比例（存入 `app_settings` 表，key=`points_exchange_rate`）

### 惩罚执行

- **生成惩罚**：app 启动时检查，统计昨天未完成基础次数（即打卡次数 < minDailyCount）的任务，生成 `TaskPenalty` 记录（`penalty_date = 今天`）。如果 app 连续多天未启动，一并补生成所有未生成的惩罚记录
- **执行惩罚**：每日启动时，读取 `task_penalties` 中 `penalty_date = 今天 AND applied = 0` 的记录，累计扣减分钟数从当日总时长限额中扣除，标记 `applied = 1`
- **当天提醒**："今天有 X 个任务还没完成哦，如果不完成，明天会减少 Y 分钟使用时长"
- **次日提醒**："昨天有 X 个任务未完成，今天的使用时长减少了 Y 分钟"

### 页面与交互

**底部导航改造**（[shell_page.dart](../qiaoqiao_companion/lib/app/shell_page.dart)）：3 Tab → 4 Tab

| 索引 | 图标 | 标签 | 路由 |
|------|------|------|------|
| 0 | `Icons.home_rounded` | 首页 | `/home` |
| 1 | `Icons.rule_rounded` | 规则 | `/rules` |
| 2 | `Icons.emoji_nature_rounded` | 任务 | `/tasks` |
| 3 | `Icons.person_rounded` | 我的 | `/settings` |

**任务 Tab 页面**（`task_page.dart`）：

1. 成长树区域（P1 用 emoji 占位，P2 替换为真实图片+动画）
2. 统计栏：圆形进度（任务完成率）+ 今日积分 + 可用加时券数
3. 今日任务列表：
   - 已完成：灰色边框 + 删除线名称 + ✓ 标记 + 已得积分
   - 未完成（自助打卡）：主题色边框 + "打卡"按钮
   - 未完成（需家长确认）：主题色边框 + "待确认"状态
   - 未完成（有惩罚）：警告色边框 + ⚠️ 扣减提示
4. 兑换入口：底部浮动按钮"兑换加时券"

**打卡交互**：

- **自助打卡（self）**：点击"打卡"→ 立即生效 → 积分动画 → 卡片变已完成
- **需家长确认（parentConfirm）**：点击"打卡"→ 弹出家长密码确认框 → 确认后生效
- **定时自动完成（scheduled）**：到达 scheduledTime 自动打卡

**家长端任务管理**：

在 parent_mode_page.dart 新增入口"管理任务"（图标 `Icons.task_alt_rounded`，路由 `/parent-mode/tasks`）。

新增 `task_management_page.dart`：
- 任务列表（可拖拽排序）
- 每个任务卡片：emoji + 名称 + 分类标签 + 启用开关
- 添加任务按钮 → `task_edit_page.dart`（表单：名称、emoji 选择器、分类、积分、次数、打卡方式、惩罚、提醒）
- 长按/滑动删除

---

## P2 成长树与形象

### 形象资源

4 套风格 × 5 阶段 = 20 张图片，内置 app：

```
assets/images/egg/
  princess/    stage_0.png ~ stage_4.png    甜美公主风
  sporty/      stage_0.png ~ stage_4.png    运动活力风
  fairy/       stage_0.png ~ stage_4.png    奇幻精灵风
  school/      stage_0.png ~ stage_4.png    校园学霸风
```

### 5 阶段定义

| 阶段 | 完成比例 | 名称 | 表情 | 通用 mood |
|------|---------|------|------|----------|
| 0 | 0% | 蛋宝宝 | 闭眼迷糊 | 💤 刚起步 |
| 1 | 1-20% | 小蛋仔 | 好奇睁眼 | 😊 努力中 |
| 2 | 21-40% | 活力蛋 | 开心大笑 | 😄 越来越棒 |
| 3 | 41-60% | 闪亮蛋 | 星星眼 | 🤩 闪闪发光 |
| 4 | 61-100% | 超级蛋 | 大星星眼 | 🏆 完美达成 |

阶段计算：`stage = (已达标任务数 / 总任务数 * 5).floor().clamp(0, 4)`，其中"已达标任务数"= 打卡次数 >= minDailyCount 的任务数

### 4 套风格及衣服路线

**👸 甜美公主**：小肚兜 → 草莓裙 → 薰衣草套裙 → 公主裙 → 彩虹魔法袍

**🏃 运动活力**：小背心 → 网球裙 → 运动套装 → 啦啦队服 → 冠军战袍

**🧚 奇幻精灵**：小翅膀 → 花仙子裙 → 月光精灵 → 星辰巫师 → 彩虹独角兽

**📚 校园学霸**：ABC 围嘴 → 校服裙 → 学院风 → 博士服 → 诺贝尔礼服

### 升级效果

当 stage 值变化时触发 3 层组合效果：

1. **Lottie 弹跳动画**（1.5秒）：蛋仔放大→弹跳→落定，叠加星星/爱心粒子
2. **语音鼓励**（audioplayers）：每个阶段专属鼓励语（4 套风格各有 5 段语音），语音文件内置 `assets/audio/egg/`
3. **全屏庆祝卡片**（2秒）：彩带+星星飘落，中央弹出升级卡片（蛋仔形象+新名称+鼓励语），3秒后自动消失

### 风格切换

- 家长在 parent_mode 设置中选择风格
- 存入 `app_settings` 表（key=`egg_style`，value=`princess/sporty/fairy/school`）
- 小孩侧实时生效（下次打开任务 Tab 或完成打卡时刷新）

---

## P3 任务提醒

### 提醒触发流程

```
到达 reminder_time
  → 播放提示音（1秒短促叮咚）
  → 显示展示性弹窗（不阻塞当前使用）
  → 30秒自动关闭 或 手动关闭
  → 如果未响应（未打卡），按 reminderRepeatInterval 分钟后再次提醒
  → 直到打卡或当天结束
```

### 展示性弹窗

- 使用 Flutter 层的 `OverlayEntry`（在 app 前台时），原生层 Overlay（app 在后台时，通过 MethodChannel 调用已有悬浮窗机制）
- 位置：屏幕顶部居中，不遮挡底部操作区
- 内容：emoji + 任务名称 + "该完成啦！" + 关闭按钮 ×
- 不抢焦点，不阻塞当前 app 使用
- 30秒倒计时进度条，到 0 自动关闭

### 定时机制

- 使用 `flutter_local_notifications` 包实现本地定时通知
- app 在前台时用 Overlay 弹窗；app 在后台时用系统通知
- 每日首次启动 app 时注册当天所有任务的提醒

### 提示音

内置 `assets/audio/reminder.mp3`（1秒短促叮咚），通过 audioplayers 播放

---

## 文件结构（新增/修改）

### P1 核心任务系统

| 文件 | 动作 | 责任 |
|------|------|------|
| `lib/core/constants/database_constants.dart` | 修改 | 新增 TaskCategory/CheckinMode 枚举和表名常量 |
| `lib/core/database/app_database.dart` | 修改 | v6 迁移：新增 3 表 + 修复 2 bug |
| `lib/core/database/daos/task_definition_dao.dart` | 新建 | 任务定义 CRUD |
| `lib/core/database/daos/task_checkin_dao.dart` | 新建 | 打卡记录 CRUD |
| `lib/core/database/daos/task_penalty_dao.dart` | 新建 | 惩罚记录 CRUD |
| `lib/shared/models/task_definition.dart` | 新建 | 任务定义模型 |
| `lib/shared/models/task_checkin.dart` | 新建 | 打卡记录模型 |
| `lib/shared/models/task_penalty.dart` | 新建 | 惩罚记录模型 |
| `lib/shared/providers/task_provider.dart` | 新建 | 任务状态管理（列表/打卡/惩罚） |
| `lib/features/tasks/presentation/task_page.dart` | 新建 | 任务 Tab 页面 |
| `lib/features/parent_mode/presentation/task_management_page.dart` | 新建 | 家长端任务列表管理 |
| `lib/features/parent_mode/presentation/task_edit_page.dart` | 新建 | 家长端任务编辑表单 |
| `lib/app/shell_page.dart` | 修改 | 3 Tab → 4 Tab |
| `lib/app/router.dart` | 修改 | 新增 /tasks 路由和家长端任务管理路由 |
| `lib/features/parent_mode/presentation/parent_mode_page.dart` | 修改 | 新增"管理任务"入口 |
| `lib/shared/providers/points_provider.dart` | 修改 | addPoints/deductPoints 传递 category 参数 |

### P2 成长树与形象

| 文件 | 动作 | 责任 |
|------|------|------|
| `assets/images/egg/{princess,sporty,fairy,school}/stage_0~4.png` | 新建 | 20 张蛋仔形象图片 |
| `assets/audio/egg/{princess,sporty,fairy,school}_0~4.mp3` | 新建 | 20 段语音 |
| `lib/shared/widgets/egg_character.dart` | 新建 | 蛋仔形象组件（根据 style+stage 显示图片） |
| `lib/shared/widgets/egg_upgrade_overlay.dart` | 新建 | 升级全屏庆祝 overlay |
| `lib/shared/providers/egg_style_provider.dart` | 新建 | 蛋仔风格设置 provider |
| `pubspec.yaml` | 修改 | 声明新增 assets |

### P3 任务提醒

| 文件 | 动作 | 责任 |
|------|------|------|
| `assets/audio/reminder.mp3` | 新建 | 提醒提示音 |
| `lib/features/tasks/presentation/task_reminder_overlay.dart` | 新建 | 展示性弹窗 |
| `lib/features/tasks/presentation/task_reminder_service.dart` | 新建 | 提醒调度服务 |
| `pubspec.yaml` | 修改 | 新增 flutter_local_notifications 依赖 |

---

## 范围外（YAGNI）

- 不改首页巧巧卡
- 不改现有积分/加时券核心逻辑（只新增 category 传参）
- 不做运行时 AI 生成形象（全部预置资源）
- 不做任务模板/推荐系统
- 不做社交分享（"炫耀我的蛋仔"）
- 不做多孩子/多账户支持
- 不做历史任务统计图表（仅当日本日视图）
