# 项目指令 —— baby-friends（巧巧小伙伴）

> 此文件自动叠加到全局指令之上。项目级规则优先。

---

## 🔴 项目级 DCP 强制保留

在全局规则基础上，以下 baby-friends 特有内容必须保留：

```
1. 项目架构图：Flutter + Kotlin 原生通道的分层架构
2. 核心业务流程：UsageMonitor → RuleChecker → Reminder 的触发链
3. UsageStatsManager + AccessibilityService 的双层前台检测逻辑
4. MIUI 适配的特殊逻辑（queryEvents 空结果、lastTimeUsed 不刷新、sticky cache）
5. 当前未完成的 TODO、已知 BUG、待决策项
6. Database schema 定义（app_database.dart 的 6 张表）
7. ROM 适配表（MIUI/EMUI/ColorOS 等各厂商的权限引导）
```

---

## 🎯 项目记忆重点

每次应答前特别关注以下文件：
- `Workspace/baby-friends/dev-log.md` — 开发历史记录
- `Workspace/baby-friends/pitfalls.md` — 项目特有踩坑
- `Workspace/baby-friends/sop.md` — 项目特有操作流程

---

## 📦 项目特有持久数据

- Database: `D:\Developfile\baby-friends\qiaoqiao_companion\` (Flutter SQLite)
- 原生代码: `android/app/src/main/kotlin/` (Kotlin 原生通道)
- 配置: `qiaoqiao_companion/pubspec.yaml` (Flutter 依赖)
