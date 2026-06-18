# SG-Exam WSL2 部署计划

## TL;DR
> **Summary**: 在WSL2 Ubuntu中部署sg-exam在线考试系统，包括MySQL、Redis、MinIO等基础设施，以及Spring Boot后端和Vue前端，使服务可通过Windows浏览器访问。
> **Deliverables**: 
> - WSL2中运行的MySQL、Redis、MinIO服务
> - 构建并运行的sg-exam后端服务
> - 构建的Vue前端（Web、Admin、Mobile）
> - Windows浏览器可访问的完整系统
> **Effort**: Medium
> **Parallel**: YES - 3 waves
> **Critical Path**: Docker Desktop集成 → 基础设施启动 → Java/Node安装 → 后端构建 → 前端构建 → 服务启动

## Context

### Original Request
用户已在WSL2 Ubuntu中下载了sg-exam源码，需要进行二次开发。要求：
1. 安装MySQL、Redis等依赖服务
2. 部署并启动sg-exam服务
3. 使服务可在Windows中访问

### Interview Summary
- **项目类型**: Spring Boot 2.7.1 + Vue 3 在线考试系统
- **构建工具**: Gradle（后端）、npm/yarn（前端）
- **运行环境**: Java 17、Node.js、MySQL 5.7、Redis、MinIO
- **部署方式**: Docker Compose（推荐）或原生安装
- **WSL2环境**: Ubuntu 26.04 LTS，无Docker/Java/Gradle
- **Windows端口占用**: 80(IIS)、33060(MySQL)、6379(Redis)、8081(占用)

### 技术决策
1. **部署方式选择**: Docker Desktop WSL2集成 + 原生构建
   - 理由：Docker Desktop已安装，启用WSL2集成最简单；后端/前端需要原生构建以便二次开发
2. **端口规划**: 避免与Windows服务冲突
   - MySQL: 3307:3306
   - Redis: 6380:6379
   - MinIO: 9000:9000, 9090:9090
   - 后端: 8080:8080

## Work Objectives

### Core Objective
在WSL2 Ubuntu中成功部署sg-exam系统，包括所有依赖服务，并可通过Windows浏览器访问。

### Deliverables
1. MySQL 5.7服务（Docker容器，端口3307）
2. Redis服务（Docker容器，端口6380）
3. MinIO服务（Docker容器，端口9000/9090）
4. sg-exam后端服务（Spring Boot，端口8080）
5. sg-exam前端文件（通过nginx或直接服务）
6. 完整的数据库初始化和表结构

### Definition of Done
- [ ] MySQL服务运行中，可连接，数据库已初始化
- [ ] Redis服务运行中，可连接
- [ ] MinIO服务运行中，可通过控制台访问
- [ ] sg-exam后端服务启动成功
- [ ] Windows浏览器可访问 http://localhost:8080/sg-user-service
- [ ] 前端页面可正常加载

### Must Have
- MySQL数据库及所有表结构
- Redis缓存服务
- MinIO对象存储服务
- sg-exam后端API服务
- 前端静态文件服务

### Must NOT Have
- 不修改源码中的配置文件（使用环境变量覆盖）
- 不安装不必要的系统包
- 不暴露敏感信息（密码等使用默认值即可）

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.

- Test decision: 手动验证 + API测试
- QA policy: 每个服务启动后验证连接性
- Evidence: .omo/evidence/task-{N}-{slug}.{ext}

## Execution Strategy

### Wave 1: 基础设施准备（并行）
1. 启用Docker Desktop WSL2集成
2. 安装Java 17
3. 安装Node.js和npm

### Wave 2: 依赖服务启动（串行）
1. 修改docker-compose配置（端口映射）
2. 启动MySQL、Redis、MinIO容器
3. 验证服务连接性

### Wave 3: 应用构建和启动（并行）
1. 构建后端（Gradle）
2. 构建前端（npm/yarn）
3. 启动后端服务
4. 配置前端服务

### Dependency Matrix
```
Task 1 (Docker Desktop) → Task 4 (docker-compose)
Task 2 (Java 17) → Task 7 (后端构建)
Task 3 (Node.js) → Task 8 (前端构建)
Task 4 → Task 5 (MySQL) → Task 9 (后端启动)
Task 4 → Task 6 (Redis/MinIO) → Task 9
Task 7 → Task 9
Task 8 → Task 10 (前端部署)
Task 9 → Task 11 (完整验证)
```

## TODOs

- [ ] 1. 启用Docker Desktop WSL2集成

  **What to do**: 
  在Windows上打开Docker Desktop，进入Settings → Resources → WSL Integration，启用对Ubuntu的集成。验证WSL2中可以使用docker命令。

  **Must NOT do**: 
  - 不要修改Docker Desktop的其他设置
  - 不要重启Docker Desktop（除非必要）

  **Recommended Agent Profile**:
  - Category: `quick` - 简单配置任务
  - Skills: [] - 无需特殊技能
  - Omitted: [`playwright`] - 非浏览器任务

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [4] | Blocked By: []

  **References**:
  - Pattern: WSL2 Docker集成文档
  - External: https://docs.docker.com/desktop/wsl/

  **Acceptance Criteria**:
  - [ ] 在WSL2 Ubuntu中运行 `docker --version` 成功
  - [ ] 运行 `docker ps` 无报错

  **QA Scenarios**:
  ```
  Scenario: 验证Docker集成
    Tool: Bash
    Steps: 
      1. 在WSL2中运行 `docker --version`
      2. 运行 `docker run hello-world`
    Expected: 
      - docker命令可用
      - hello-world容器成功运行
    Evidence: .omo/evidence/task-1-docker-integration.txt
  ```

  **Commit**: NO

---

- [ ] 2. 安装Java 17

  **What to do**: 
  在WSL2 Ubuntu中安装OpenJDK 17。使用apt包管理器安装。

  **Must NOT do**: 
  - 不要安装其他版本的Java
  - 不要配置JAVA_HOME（除非必要）

  **Recommended Agent Profile**:
  - Category: `quick` - 简单安装任务
  - Skills: [] - 无需特殊技能

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [7] | Blocked By: []

  **References**:
  - Pattern: Ubuntu apt安装Java

  **Acceptance Criteria**:
  - [ ] 运行 `java -version` 显示版本17
  - [ ] 运行 `javac -version` 成功

  **QA Scenarios**:
  ```
  Scenario: 验证Java安装
    Tool: Bash
    Steps: 
      1. 运行 `java -version`
      2. 运行 `javac -version`
    Expected: 
      - 版本号显示17.x
      - 编译器可用
    Evidence: .omo/evidence/task-2-java-install.txt
  ```

  **Commit**: NO

---

- [ ] 3. 安装Node.js和npm

  **What to do**: 
  在WSL2 Ubuntu中安装Node.js 18.x LTS和npm。使用NodeSource仓库安装。

  **Must NOT do**: 
  - 不要使用Windows的npm（通过/mnt/c/）
  - 不要全局安装不必要的包

  **Recommended Agent Profile**:
  - Category: `quick` - 简单安装任务
  - Skills: [] - 无需特殊技能

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: [8] | Blocked By: []

  **References**:
  - Pattern: NodeSource安装Node.js

  **Acceptance Criteria**:
  - [ ] 运行 `node --version` 显示v18.x
  - [ ] 运行 `npm --version` 成功
  - [ ] 运行 `which node` 显示WSL2路径（非/mnt/c/）

  **QA Scenarios**:
  ```
  Scenario: 验证Node.js安装
    Tool: Bash
    Steps: 
      1. 运行 `node --version`
      2. 运行 `npm --version`
      3. 运行 `which node`
    Expected: 
      - 版本号显示v18.x
      - npm版本正常
      - 路径为/usr/bin/node或类似（非/mnt/c/）
    Evidence: .omo/evidence/task-3-node-install.txt
  ```

  **Commit**: NO

---

- [ ] 4. 修改docker-compose配置

  **What to do**: 
  修改docker-compose.yml文件，调整端口映射以避免与Windows服务冲突：
  - MySQL: 3307:3306
  - Redis: 6380:6379
  - 其他服务保持不变

  **Must NOT do**: 
  - 不要修改服务的内部端口
  - 不要修改网络配置
  - 不要修改卷挂载路径

  **Recommended Agent Profile**:
  - Category: `quick` - 简单配置修改
  - Skills: [] - 无需特殊技能

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: [5, 6] | Blocked By: [1]

  **References**:
  - Pattern: `/home/chenjj/sg-exam/docker-compose.yml`
  - Config: 端口映射配置

  **Acceptance Criteria**:
  - [ ] MySQL端口改为3307:3306
  - [ ] Redis端口改为6380:6379
  - [ ] 文件语法正确

  **QA Scenarios**:
  ```
  Scenario: 验证配置修改
    Tool: Bash
    Steps: 
      1. 查看docker-compose.yml内容
      2. 验证端口配置
    Expected: 
      - MySQL端口为3307:3306
      - Redis端口为6380:6379
    Evidence: .omo/evidence/task-4-compose-config.txt
  ```

  **Commit**: YES | Message: `fix(deploy): adjust ports to avoid Windows conflicts` | Files: [docker-compose.yml]

---

- [ ] 5. 启动MySQL容器

  **What to do**: 
  使用docker-compose启动MySQL服务，等待容器完全启动，验证数据库可连接。

  **Must NOT do**: 
  - 不要手动创建数据库（由初始化脚本处理）
  - 不要修改MySQL配置

  **Recommended Agent Profile**:
  - Category: `quick` - 简单服务启动
  - Skills: [] - 无需特殊技能

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: [9] | Blocked By: [4]

  **References**:
  - Pattern: docker-compose up命令
  - Config: config-repo/mysql/init.sql

  **Acceptance Criteria**:
  - [ ] MySQL容器运行中
  - [ ] 可通过 `docker exec mysql-service mysql -u root -p123456 -e "SHOW DATABASES"` 连接
  - [ ] sg-exam-user数据库已创建

  **QA Scenarios**:
  ```
  Scenario: 验证MySQL服务
    Tool: Bash
    Steps: 
      1. 运行 `docker-compose up -d mysql-service`
      2. 等待30秒
      3. 运行 `docker exec mysql-service mysql -u root -p123456 -e "SHOW DATABASES"`
    Expected: 
      - 容器启动成功
      - 显示数据库列表，包含sg-exam-user
    Evidence: .omo/evidence/task-5-mysql-start.txt
  ```

  **Commit**: NO

---

- [ ] 6. 启动Redis和MinIO容器

  **What to do**: 
  使用docker-compose启动Redis和MinIO服务，验证服务可连接。

  **Must NOT do**: 
  - 不要修改Redis配置
  - 不要修改MinIO配置

  **Recommended Agent Profile**:
  - Category: `quick` - 简单服务启动
  - Skills: [] - 无需特殊技能

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: [9] | Blocked By: [4]

  **References**:
  - Pattern: docker-compose up命令

  **Acceptance Criteria**:
  - [ ] Redis容器运行中
  - [ ] MinIO容器运行中
  - [ ] Redis可连接：`docker exec redis-service redis-cli ping` 返回PONG
  - [ ] MinIO控制台可访问：http://localhost:9090

  **QA Scenarios**:
  ```
  Scenario: 验证Redis和MinIO
    Tool: Bash
    Steps: 
      1. 运行 `docker-compose up -d redis-service minio-service`
      2. 等待30秒
      3. 运行 `docker exec redis-service redis-cli ping`
      4. 访问 http://localhost:9090
    Expected: 
      - 容器启动成功
      - Redis返回PONG
      - MinIO控制台可访问
    Evidence: .omo/evidence/task-6-redis-minio-start.txt
  ```

  **Commit**: NO

---

- [ ] 7. 构建后端服务

  **What to do**: 
  在WSL2中使用Gradle构建sg-exam后端服务。执行 `./gradlew build -x test` 构建所有模块。

  **Must NOT do**: 
  - 不要运行测试（-x test）
  - 不要修改构建配置
  - 不要使用sudo

  **Recommended Agent Profile**:
  - Category: `unspecified-low` - 构建任务
  - Skills: [] - 无需特殊技能

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: [9] | Blocked By: [2]

  **References**:
  - Pattern: `/home/chenjj/sg-exam/gradlew`
  - Config: `/home/chenjj/sg-exam/build.gradle`

  **Acceptance Criteria**:
  - [ ] 构建成功，无错误
  - [ ] 生成jar文件：`ls sg-user-service/build/libs/*.jar`

  **QA Scenarios**:
  ```
  Scenario: 验证后端构建
    Tool: Bash
    Steps: 
      1. 运行 `cd /home/chenjj/sg-exam && ./gradlew build -x test`
      2. 运行 `ls sg-user-service/build/libs/*.jar`
    Expected: 
      - 构建成功
      - 存在jar文件
    Evidence: .omo/evidence/task-7-backend-build.txt
  ```

  **Commit**: NO

---

- [ ] 8. 构建前端服务

  **What to do**: 
  在WSL2中构建三个前端应用：
  1. sg-exam-web: `cd frontend/sg-exam-web && npm install && npm run build`
  2. sg-exam-admin: `cd frontend/sg-exam-admin && npm install && npm run build`
  3. sg-exam-mobile: `cd frontend/sg-exam-mobile && npm install && npm run build:h5`

  **Must NOT do**: 
  - 不要修改前端代码
  - 不要使用Windows的npm

  **Recommended Agent Profile**:
  - Category: `unspecified-low` - 构建任务
  - Skills: [] - 无需特殊技能

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: [10] | Blocked By: [3]

  **References**:
  - Pattern: `/home/chenjj/sg-exam/frontend/*/package.json`

  **Acceptance Criteria**:
  - [ ] 三个前端应用构建成功
  - [ ] 存在dist目录：`ls frontend/*/dist`

  **QA Scenarios**:
  ```
  Scenario: 验证前端构建
    Tool: Bash
    Steps: 
      1. 依次构建三个前端应用
      2. 运行 `ls frontend/*/dist`
    Expected: 
      - 构建成功
      - 存在dist目录
    Evidence: .omo/evidence/task-8-frontend-build.txt
  ```

  **Commit**: NO

---

- [ ] 9. 启动后端服务

  **What to do**: 
  启动sg-exam后端服务。使用以下命令：
  ```bash
  cd /home/chenjj/sg-exam
  java -jar sg-user-service/build/libs/sg-user-service-0.0.15.jar \
    --spring.profiles.active=docker \
    --SG_DB_USER_HOST=127.0.0.1 \
    --SG_DB_USER_POST=3307 \
    --SG_REDIS_USER_HOST=127.0.0.1 \
    --SG_REDIS_USER_POST=6380 \
    --MINIO_ENDPOINT=http://127.0.0.1:9000
  ```

  **Must NOT do**: 
  - 不要使用sudo
  - 不要修改配置文件
  - 不要后台运行（便于调试）

  **Recommended Agent Profile**:
  - Category: `unspecified-low` - 服务启动
  - Skills: [] - 无需特殊技能

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: [11] | Blocked By: [5, 6, 7]

  **References**:
  - Config: `/home/chenjj/sg-exam/config-repo/sg-exam.env`
  - Config: `/home/chenjj/sg-exam/config-repo/sg-user-service.yml`

  **Acceptance Criteria**:
  - [ ] 服务启动成功，无异常
  - [ ] 日志显示 "Started SgUserApplication"
  - [ ] 可通过curl访问：`curl http://localhost:8080/sg-user-service`

  **QA Scenarios**:
  ```
  Scenario: 验证后端服务
    Tool: Bash
    Steps: 
      1. 启动后端服务
      2. 等待60秒
      3. 运行 `curl -s http://localhost:8080/sg-user-service/v1/home/home`
    Expected: 
      - 服务启动成功
      - 返回JSON响应（可能是错误码，但有响应）
    Evidence: .omo/evidence/task-9-backend-start.txt
  ```

  **Commit**: NO

---

- [ ] 10. 部署前端文件

  **What to do**: 
  将构建好的前端文件复制到nginx可访问的位置，或配置后端服务直接提供静态文件。

  **Must NOT do**: 
  - 不要修改前端构建产物
  - 不要暴露敏感信息

  **Recommended Agent Profile**:
  - Category: `quick` - 简单文件操作
  - Skills: [] - 无需特殊技能

  **Parallelization**: Can Parallel: YES | Wave 3 | Blocks: [11] | Blocked By: [8]

  **References**:
  - Pattern: nginx配置

  **Acceptance Criteria**:
  - [ ] 前端文件可访问
  - [ ] Windows浏览器可打开 http://localhost:8080/sg-user-service

  **QA Scenarios**:
  ```
  Scenario: 验证前端部署
    Tool: Bash
    Steps: 
      1. 复制前端文件到nginx目录（或配置后端）
      2. 访问 http://localhost:8080/sg-user-service
    Expected: 
      - 前端页面可加载
      - 无404错误
    Evidence: .omo/evidence/task-10-frontend-deploy.txt
  ```

  **Commit**: NO

---

- [ ] 11. 完整验证

  **What to do**: 
  验证整个系统运行正常：
  1. 所有服务运行中
  2. 数据库连接正常
  3. API可访问
  4. Windows浏览器可访问

  **Must NOT do**: 
  - 不要修改任何配置
  - 不要停止服务

  **Recommended Agent Profile**:
  - Category: `quick` - 验证任务
  - Skills: [] - 无需特殊技能

  **Parallelization**: Can Parallel: NO | Final | Blocks: [] | Blocked By: [9, 10]

  **References**:
  - Pattern: 完整系统验证

  **Acceptance Criteria**:
  - [ ] 所有Docker容器运行中
  - [ ] 后端服务运行中
  - [ ] API响应正常
  - [ ] Windows浏览器可访问

  **QA Scenarios**:
  ```
  Scenario: 完整系统验证
    Tool: Bash
    Steps: 
      1. 运行 `docker ps` 检查容器状态
      2. 运行 `curl -s http://localhost:8080/sg-user-service/v1/home/home`
      3. 在Windows浏览器访问 http://localhost:8080/sg-user-service
    Expected: 
      - 所有容器运行中
      - API返回响应
      - 浏览器可访问
    Evidence: .omo/evidence/task-11-full-verification.txt
  ```

  **Commit**: NO

## Final Verification Wave

- [ ] F1. 服务状态检查 — 运行 `docker ps` 和 `ps aux | grep java` 确认所有服务运行中
- [ ] F2. API响应测试 — 运行 `curl` 测试所有主要API端点
- [ ] F3. 数据库连接测试 — 验证MySQL和Redis可连接
- [ ] F4. Windows访问测试 — 在浏览器中访问 http://localhost:8080/sg-user-service

## Commit Strategy
- Task 4: 修改docker-compose配置后提交
- 其他任务：无需提交（部署过程）

## Success Criteria
1. ✅ WSL2中MySQL服务运行（端口3307）
2. ✅ WSL2中Redis服务运行（端口6380）
3. ✅ WSL2中MinIO服务运行（端口9000/9090）
4. ✅ sg-exam后端服务运行（端口8080）
5. ✅ Windows浏览器可访问 http://localhost:8080/sg-user-service
6. ✅ 数据库表结构已初始化
7. ✅ 系统可正常登录和使用

## Notes
- 由于Windows已占用端口80、3306、6379，WSL2中使用3307和6380
- 后端服务使用docker profile连接数据库
- 前端文件可通过nginx或直接由后端服务提供
- 所有密码使用默认值（123456），生产环境需修改
