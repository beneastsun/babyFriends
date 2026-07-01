# 应用包名配置指南

## 快速修改应用ID

要修改应用的包名（Application ID），只需修改一个文件：

### 步骤

1. 打开 `android/local.properties` 文件
2. 找到以下行：
   ```properties
   app.applicationId=com.qiaoqiao.qiaoqiao_companion_new
   ```
3. 修改 `app.applicationId` 的值为你想要的包名，例如：
   ```properties
   app.applicationId=com.yourcompany.yourapp
   ```
4. 清理并重新构建项目：
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## 快速修改应用名称

要修改应用的显示名称，需要两步操作：

### 步骤

1. **修改配置文件**：打开 `android/local.properties` 文件
   ```properties
   app.appName=巧巧
   ```

2. **同步配置**：运行同步脚本（自动更新 strings.xml）
   - Windows: 双击运行 `sync_app_name.ps1`
   - 或在 PowerShell 中执行：`.\sync_app_name.ps1`

3. **清理并重新构建**：
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### 或者直接修改 strings.xml

您也可以直接编辑 `android/app/src/main/res/values/strings.xml`：
```xml
<string name="app_name">巧巧</string>
```

## 配置说明

### 当前配置位置

- **应用ID配置**: `android/local.properties`
  - 属性名: `app.applicationId`
  - 默认值: `com.qiaoqiao.qiaoqiao_companion`

- **应用名称配置**: 
  - 配置文件: `android/local.properties` (属性名: `app.appName`)
  - 实际生效: `android/app/src/main/res/values/strings.xml` (`<string name="app_name">`)
  - 同步脚本: `sync_app_name.ps1` (自动从 local.properties 同步到 strings.xml)

### 自动同步的配置项

**应用ID相关**（修改 `local.properties` 后自动生效）：
1. ✅ Android `applicationId` (build.gradle.kts) - **决定应用的唯一标识**
2. ✅ AndroidManifest.xml 中的广播 Action (`${applicationId}`)
3. ✅ MainActivity 中的应用频道名称 (动态获取)

**应用名称相关**（需要运行同步脚本）：
1. ✅ 运行 `sync_app_name.ps1` 脚本自动同步到 strings.xml
2. ✅ 应用显示名称 (AndroidManifest.xml 引用 `@string/app_name`)
3. ✅ 通知标题和描述 (所有服务中通过 `R.string.app_name` 动态获取)
4. ✅ AppLock 覆盖层通知标题

### 保持不变配置

以下配置**不会**随 applicationId 改变：

- ✅ Android `namespace` - 保持为 `com.qiaoqiao.qiaoqiao_companion`（R类资源引用）
- ✅ Kotlin 文件的 package 声明（内部代码结构）
- ✅ Flutter MethodChannel 的频道名称（通信协议标识符）
- ✅ Dart 代码中的包名引用

## 注意事项

1. **包名格式**: 建议使用反向域名格式，如 `com.company.appname`
2. **唯一性**: 每个安装的应用必须有唯一的 applicationId
3. **同时安装**: 不同的 applicationId 可以在同一设备上同时安装
4. **数据隔离**: 不同包名的应用数据完全独立

## 示例

### 开发版本
```properties
app.applicationId=com.qiaoqiao.qiaoqiao_companion_dev
app.appName=纹纹小伙伴-开发版
```

### 测试版本
```properties
app.applicationId=com.qiaoqiao.qiaoqiao_companion_test
app.appName=纹纹小伙伴-测试版
```

### 正式版本
```properties
app.applicationId=com.qiaoqiao.qiaoqiao_companion
app.appName=纹纹小伙伴
```

## 技术实现

### 应用ID配置 (build.gradle.kts)
```kotlin
// 从 local.properties 读取应用ID
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

val appApplicationId = localProperties.getProperty("app.applicationId", "com.qiaoqiao.qiaoqiao_companion")

android {
    namespace = "com.qiaoqiao.qiaoqiao_companion"
    
    defaultConfig {
        applicationId = appApplicationId
    }
}
```

### 应用名称配置

**方式1：使用同步脚本（推荐）**
1. 修改 `local.properties`: `app.appName=巧巧`
2. 运行 `sync_app_name.ps1` 脚本
3. 脚本自动更新 `strings.xml` 中的 `<string name="app_name">巧巧</string>`

**方式2：直接修改 strings.xml**
```xml
<string name="app_name">巧巧</string>
```

**在代码中使用**：
```kotlin
// Kotlin 代码中获取应用名称
val appName = getString(R.string.app_name)

// 用于通知标题
.setContentTitle("$appName正在运行中")
```

**重要说明**：
- `namespace`：决定 R 类的包名，必须与 Kotlin 代码的 package 声明一致
- `applicationId`：决定应用在设备上的唯一标识，可以独立修改
- `app_name`：通过 strings.xml 定义，避免 resValue 的编码问题

### AndroidManifest.xml
```xml
<!-- 使用 ${applicationId} 占位符自动替换 -->
<intent-filter>
    <action android:name="${applicationId}.RESTART_SERVICE" />
</intent-filter>
```

### MainActivity.kt
```kotlin
// 运行时动态获取包名
val appChannel = MethodChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    "${applicationContext.packageName}/app"
)
```
