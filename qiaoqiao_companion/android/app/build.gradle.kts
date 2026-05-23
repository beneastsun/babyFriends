import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 从 local.properties 读取应用ID配置
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

val appApplicationId = localProperties.getProperty("app.applicationId", "com.qiaoqiao.qiaoqiao_companion")
val appAppName = localProperties.getProperty("app.appName", "纹纹小伙伴")

// 从 strings.xml 读取图标主题配置
val stringsFile = file("src/main/res/values/strings.xml")
val appIconTheme = if (stringsFile.exists()) {
    val text = stringsFile.readText()
    val regex = """<string\s+name="app_icon_theme">([^<]+)</string>""".toRegex()
    regex.find(text)?.groupValues?.getOrNull(1) ?: "default"
} else {
    "default"
}

android {
    namespace = "com.qiaoqiao.qiaoqiao_companion"  // 保持原有namespace，R类使用此包名
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = appApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    sourceSets {
        getByName("main") {
            val themeResDir = file("src/icons/$appIconTheme/res")
            if (themeResDir.exists()) {
                res.srcDirs("src/main/res", themeResDir.absolutePath)
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // WorkManager for background keep-alive
    implementation("androidx.work:work-runtime-ktx:2.9.0")
}
