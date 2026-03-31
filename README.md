# 纹纹小伙伴

一款帮助儿童养成健康平板使用习惯的 Android 应用。

## 项目简介

纹纹小伙伴是一款专为 Android 平板设计的儿童使用管理应用。通过设置使用规则和时间限制，帮助孩子建立健康的数字生活习惯。

**目标设备**: 小米 Android 平板

## 功能特性

### 使用监控

- 实时追踪应用使用情况
- 自动记录每日使用数据
- 统计各应用使用时长

### 规则控制

**时间规则**
- 设置每日总使用时长限制
- 工作日/周末分别设置限额
- 设置禁止使用时段（学习、睡觉时间）

**应用分类规则**
- 游戏类：每日限额
- 视频类：每日限额
- 学习类：无限制
- 阅读类：无限制

### 提醒系统

分层提醒机制：
1. 时间快到时温和提醒
2. 时间到时认真提醒
3. 超时后严肃警告
4. 最终强制锁定

### 家长模式

- 密码保护的管理入口
- 修改时间规则和应用分类
- 查看使用报告
- 数据备份与恢复

## 技术栈

- **框架**: Flutter 3.x + Dart
- **状态管理**: Riverpod
- **路由**: GoRouter
- **数据库**: SQLite (sqflite)
- **平台**: Android

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── app/                         # 应用配置
│   ├── router.dart              # 路由配置
│   ├── app_initializer.dart     # 启动初始化
│   └── shell_page.dart          # 底部导航
├── core/
│   ├── database/                # 数据库层
│   ├── platform/                # Android 原生通道
│   ├── services/                # 业务服务
│   └── theme/                   # 主题样式
├── features/
│   ├── home/                    # 首页
│   ├── report/                  # 使用报告
│   ├── rules/                   # 规则展示
│   ├── settings/                # 设置
│   ├── onboarding/              # 引导流程
│   └── parent_mode/             # 家长模式
└── shared/
    ├── models/                  # 数据模型
    ├── providers/               # 状态管理
    └── widgets/                 # 共享组件
```

## 快速开始

### 环境要求

- Flutter SDK >= 3.11.1
- Dart SDK >= 3.11.1
- Android SDK (API 21+)

### 安装运行

```bash
# 进入项目目录
cd qiaoqiao_companion

# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建 Release APK
flutter build apk --release
```

### 测试

```bash
# 运行测试
flutter test

# 代码分析
flutter analyze
```

## 权限说明

| 权限 | 用途 |
|------|------|
| `PACKAGE_USAGE_STATS` | 获取应用使用统计 |
| `SYSTEM_ALERT_WINDOW` | 显示锁定覆盖层 |
| `FOREGROUND_SERVICE` | 后台监控服务 |
| `RECEIVE_BOOT_COMPLETED` | 开机自启动 |

## 许可证

MIT License
