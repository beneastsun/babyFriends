# Hermes Agent 全面强化方案

## TL;DR
> **目标**: 为 WSL2 中的 Hermes Agent 安装最优 skill 组合，最大化能力增强
> **原则**: 按优先级分层安装，先核心后扩展，避免过度配置
> **预期效果**: Hermes 从基础聊天工具升级为全栈自动化平台
> **新增模块**: 全网抓取、专业研究、多模态升级、控成本提效率、生态入口

---

## 一、现状分析

### 已安装 Skills（50+）
你的 `~/.hermes/skills/` 已包含多个类别：
- **autonomous-ai-agents**: claude-code, codex, hermes-agent, opencode
- **creative**: comfyui, excalidraw, ascii-art 等 20+ 创意类
- **github**: 6 个 GitHub 工作流 skill
- **email**: himalaya
- **mcp**: native-mcp
- **media**: gif-search, spotify, heartmula
- **devops**: feishu-gateway-troubleshooting, kanban

### 当前配置状态
```yaml
# config.yaml 关键配置
toolsets:
  - hermes-cli          # 核心工具集
platform_toolsets:
  cli:
    - browser           # ✅ 已启用
    - clarify           # ✅ 已启用
    - code_execution    # ✅ 已启用
    - delegation        # ✅ 已启用
    - file              # ✅ 已启用
    - memory            # ✅ 已启用
    - terminal          # ✅ 已启用
    - todo              # ✅ 已启用
    - web               # ✅ 已启用
    - session_search    # ✅ 已启用
    - skills            # ✅ 已启用
    - kanban            # ✅ 已启用
    - mcp               # ✅ 已启用
web:
  auth: false           # ⚠️ 无认证（建议启用）
```

---

## 二、强化方案（按优先级排序）

### 🔴 第一优先级：核心能力增强（已启用）

#### 1. 代码执行能力
- **状态**: ✅ 已启用
- **工具**: `code_execution` + `terminal`
- **使用方式**: 直接调用，无需安装
- **能力**: Python 脚本执行、shell 命令、数据处理

#### 2. 浏览器自动化
- **状态**: ✅ 已启用
- **工具**: `browser` + `web`
- **使用方式**: 直接调用，无需安装
- **能力**: 网页浏览、内容提取、截图、表单填写

#### 3. MCP 协议支持
- **状态**: ✅ 已启用
- **工具**: `mcp`
- **使用方式**: 直接调用，无需配置
- **能力**: 连接外部工具和服务

---

### 🟡 第二优先级：效率提升（已启用）

#### 4. 任务管理
- **状态**: ✅ 已启用
- **工具**: `todo` + `kanban`
- **使用方式**: 直接调用
- **能力**: 任务规划、批量处理、进度跟踪

#### 5. 记忆系统
- **状态**: ✅ 已启用
- **工具**: `memory` + `session_search`
- **使用方式**: 直接调用
- **能力**: 上下文记忆、会话搜索、用户画像

#### 6. 技能管理
- **状态**: ✅ 已启用
- **工具**: `skills`
- **使用方式**: 直接调用
- **能力**: 已安装 50+ 技能，覆盖多领域

---

### 🟢 第三优先级：专业领域（已启用）

#### 7. 研究能力
- **状态**: ✅ 已启用
- **工具**: Deep Research Skill
- **使用方式**: 直接调用
- **能力**: 两阶段深度研究，输出结构化报告

#### 8. 代码分析
- **状态**: ✅ 已启用
- **工具**: `code_execution` + `file`
- **使用方式**: 直接调用
- **能力**: 代码审查、架构分析、重构建议

---

## 七、配置优化

### 1. 启用 WebUI 认证
```bash
# 设置密码保护
export HERMES_WEBUI_PASSWORD="your-secure-password"
```
**原因**: 当前 `auth: false` 暴露文件系统和 agent 访问权限

### 2. 优化 Agent 委派配置
```yaml
delegation:
  model: ""              # 使用主模型
  max_iterations: 50     # 增加迭代次数
  max_concurrent_children: 5  # 增加并发子 agent
```

### 3. 启用 Prompt 缓存
```yaml
prompt_caching:
  cache_ttl: 10m         # 延长缓存时间（默认 5m）
```

### 4. 优化浏览器配置
```yaml
browser:
  inactivity_timeout: 300  # 延长超时（默认 120s）
  record_sessions: true    # 启用会话录制
```

---

## 四、已启用工具集（无需额外安装）

### 核心工具集（已启用）
```yaml
toolsets:
  - hermes-cli          # 核心工具集
platform_toolsets:
  cli:
    - browser           # ✅ 网页浏览和内容提取
    - clarify           # ✅ 澄清和确认
    - code_execution    # ✅ Python 代码执行
    - delegation        # ✅ 任务委派
    - file              # ✅ 文件操作
    - memory            # ✅ 记忆系统
    - terminal          # ✅ 终端命令
    - todo              # ✅ 任务管理
    - web               # ✅ 网页搜索
    - session_search    # ✅ 会话搜索
    - skills            # ✅ 技能管理
    - kanban            # ✅ 看板管理
    - mcp               # ✅ MCP 协议
```

### MCP 服务器配置（可选，需 API Key）

#### 文件系统和 GitHub
```yaml
mcp_servers:
  filesystem:
    command: "npx"
    args: ["-y", "@anthropic/mcp-filesystem"]
    env:
      FILESYSTEM_ROOT: "/home/chenjj"
  
  github:
    command: "npx"
    args: ["-y", "@anthropic/mcp-github"]
    env:
      GITHUB_TOKEN: "${GITHUB_TOKEN}"
```

#### 网页抓取（可选）
```yaml
  firecrawl:
    command: "npx"
    args: ["-y", "firecrawl-mcp"]
    env:
      FIRECRAWL_API_KEY: "your_api_key"
  
  jina:
    command: "npx"
    args: ["-y", "@anthropic/mcp-jina"]
  
  exa:
    command: "npx"
    args: ["-y", "@anthropic/mcp-exa"]
    env:
      EXA_API_KEY: "your_key"
```

#### 模型路由（可选）
```yaml
  openrouter:
    command: "npx"
    args: ["-y", "@anthropic/mcp-openrouter"]
    env:
      OPENROUTER_API_KEY: "your_key"
```

### MCP 服务器配置（可选，需 API Key）

#### 文件系统和 GitHub
```yaml
mcp_servers:
  filesystem:
    command: "npx"
    args: ["-y", "@anthropic/mcp-filesystem"]
    env:
      FILESYSTEM_ROOT: "/home/chenjj"
  
  github:
    command: "npx"
    args: ["-y", "@anthropic/mcp-github"]
    env:
      GITHUB_TOKEN: "${GITHUB_TOKEN}"
```

#### 网页抓取（可选）
```yaml
  firecrawl:
    command: "npx"
    args: ["-y", "firecrawl-mcp"]
    env:
      FIRECRAWL_API_KEY: "your_api_key"
  
  jina:
    command: "npx"
    args: ["-y", "@anthropic/mcp-jina"]
  
  exa:
    command: "npx"
    args: ["-y", "@anthropic/mcp-exa"]
    env:
      EXA_API_KEY: "your_key"
```

#### 模型路由（可选）
```yaml
  openrouter:
    command: "npx"
    args: ["-y", "@anthropic/mcp-openrouter"]
    env:
      OPENROUTER_API_KEY: "your_key"
```

---

## 三、执行计划

### 阶段 1：配置优化（30 分钟）
1. ✅ 已完成：WebUI 安装和自动启动
2. ✅ 已完成：工具集确认（全部已启用）
3. 优化 Prompt 缓存配置
4. 启用 WebUI 认证（安全加固）

### 阶段 2：效率优化（30 分钟）
1. 配置并行执行参数
2. 优化任务管理流程
3. 测试 Deep Research 功能

### 阶段 3：验证测试（30 分钟）
1. 测试网页抓取能力
2. 测试代码执行能力
3. 测试浏览器自动化
4. 测试研究功能

---

## 五、MCP 服务器配置（可选）

### 🔥 网页抓取类
| 服务 | 用途 | 配置复杂度 |
|------|------|------------|
| Firecrawl | 全站抓取转 Markdown | 中（需 API Key） |
| Crawl4AI | AI 训练数据采集 | 低（pip install） |
| Bright Data | 反爬虫代理网络 | 高（企业级） |
| Jina Reader | URL 转 Markdown | 低（免费层够用） |
| Exa Search | 语义搜索 | 低（免费层够用） |

### 🔬 研究类
| 服务 | 用途 | 配置复杂度 |
|------|------|------------|
| Deep Research | 两阶段深度研究 | 零（已内置） |
| Exa | 语义搜索 | 低 |
| Jina | 内容提取 | 低 |

### 🎨 多模态类
| 服务 | 用途 | 配置复杂度 |
|------|------|------------|
| ComfyUI | 图像生成/处理 | 高（需 GPU） |
| Whisper | 语音转文字 | 中（pip install） |
| Edge TTS | 文字转语音 | 低（pip install） |
| PaddleOCR | 中文 OCR | 中（pip install） |

### 💰 成本控制类
| 服务 | 用途 | 配置复杂度 |
|------|------|------------|
| OpenRouter | 模型路由 | 低（需 API Key） |
| Ollama | 本地模型 | 中（需 GPU） |
| Prompt 缓存 | 降低成本 | 零（已支持） |

---

## 六、成本优化配置

### 💰 成本优化策略

#### 1. Prompt 缓存配置
- **Hermes 原生支持**: `prompt_caching` 配置
- **配置优化**:
  ```yaml
  prompt_caching:
    cache_ttl: 10m  # 延长缓存时间（默认 5m）
  ```
- **预期节省**: 30-50% 重复请求成本

#### 2. 并行执行优化
- **配置**:
  ```yaml
  delegation:
    max_concurrent_children: 5  # 增加并发子 agent
    max_iterations: 50          # 增加迭代次数
  ```
- **优势**: 提高任务处理效率

#### 3. 模型选择策略
| 任务类型 | 推荐模型 | 成本 |
|----------|----------|------|
| 简单对话 | 当前模型（iFlytek） | 最低成本 |
| 代码生成 | 当前模型 | 适中 |
| 复杂推理 | 当前模型 | 适中 |
| 研究分析 | 当前模型 | 适中 |

#### 4. 任务批量处理
- **使用 todo 工具**: 批量管理任务
- **异步执行**: 配置并行处理
- **优势**: 减少交互次数，提高效率

### 效率提升建议
1. **任务规划**: 使用 todo 工具提前规划
2. **批量执行**: 合并相关任务一起处理
3. **缓存利用**: 充分利用 prompt 缓存
4. **并行处理**: 配置并发执行多个子任务

---

## 七、验证方法

### 1. Skill 安装验证
```bash
hermes skills list | grep -E "software|browser|github"
```

### 2. MCP 服务器验证
```bash
hermes doctor  # 检查 MCP 连接状态
curl -s http://localhost:8787/health  # 检查 WebUI
```

### 3. 功能测试
```bash
# 测试代码执行
hermes "用 Python 写一个斐波那契数列生成器"

# 测试浏览器自动化
hermes "打开 GitHub 并搜索 hermes-agent"

# 测试 MCP 集成
hermes "列出我的 GitHub 仓库"
```

---

## 八、注意事项

1. **安全优先**: 不要在生产环境禁用 WebUI 认证
2. **资源管理**: MCP 服务器会消耗内存，监控 `/proc/meminfo`
3. **Skill 审查**: 定期运行 `hermes skills audit` 检查 skill 安全性
4. **备份配置**: 重要修改前备份 `~/.hermes/config.yaml`
5. **网络要求**: 部分 skill 需要访问外部 API，确保网络畅通

---

*方案生成时间: 2026-06-13*
*基于: Hermes Agent v0.15.2 + WebUI v0.51.163*
