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


android {
    namespace = "com.qiaoqiao.qiaoqiao_companion"  // 保持原有namespace，R类使用此包名
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
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

}

// ── 图标主题自动切换：读取 strings.xml 的 app_icon_theme ──
val stringsXml = file("src/main/res/values/strings.xml")
val iconTheme = if (stringsXml.exists()) {
    val m = """<string\s+name="app_icon_theme">([^<]+)</string>""".toRegex()
    m.find(stringsXml.readText())?.groupValues?.getOrNull(1) ?: "default"
} else "default"

tasks.register("applyIconTheme") {
    doLast {
        val themeRes = file("src/icons/$iconTheme/res")
        if (!themeRes.exists()) { logger.warn("Theme '$iconTheme' not found"); return@doLast }
        val mainRes = file("src/main/res")
        // 删除旧图标
        listOf(
            "drawable/ic_notification.xml",
            "drawable-hdpi/ic_launcher_foreground.png", "drawable-hdpi/ic_notification.png",
            "drawable-mdpi/ic_launcher_foreground.png", "drawable-mdpi/ic_notification.png",
            "drawable-xhdpi/ic_launcher_foreground.png", "drawable-xhdpi/ic_notification.png",
            "drawable-xxhdpi/ic_launcher_foreground.png", "drawable-xxhdpi/ic_notification.png",
            "drawable-xxxhdpi/ic_launcher_foreground.png", "drawable-xxxhdpi/ic_notification.png",
            "mipmap-anydpi-v26/ic_launcher.xml",
            "mipmap-hdpi/ic_launcher.png", "mipmap-mdpi/ic_launcher.png",
            "mipmap-xhdpi/ic_launcher.png", "mipmap-xxhdpi/ic_launcher.png", "mipmap-xxxhdpi/ic_launcher.png",
            "values/colors.xml"
        ).forEach { f -> file("$mainRes/$f").delete() }
        // 清除空 drawable-* 目录
        mainRes.listFiles()?.filter { it.isDirectory && it.name.startsWith("drawable-") }
            ?.filter { it.listFiles()?.isEmpty() == true }?.forEach { it.delete() }
        // 复制新图标
        copy { from(themeRes) { include("**/*") }; into(mainRes) }
    }
}
tasks.named("preBuild") { dependsOn("applyIconTheme") }

tasks.withType<Test> {
    useJUnitPlatform()
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring (required by flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // WorkManager for background keep-alive
    implementation("androidx.work:work-runtime-ktx:2.9.0")

    // Unit test infrastructure
    testImplementation("org.junit.jupiter:junit-jupiter-api:5.10.2")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:5.10.2")
    testImplementation("org.mockito:mockito-core:5.11.0")
    testImplementation("org.mockito.kotlin:mockito-kotlin:5.2.1")
}
