package com.qiaoqiao.qiaoqiao_companion.utils

import android.annotation.SuppressLint
import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader

/**
 * ROM工具类
 * 检测厂商ROM类型并提供对应的设置页面Intent
 */
object RomUtils {

    private const val TAG = "RomUtils"

    /**
     * ROM类型枚举
     */
    enum class RomType {
        MIUI,           // 小米
        EMUI,           // 华为EMUI
        HARMONY,        // 华为HarmonyOS
        COLOR_OS,       // OPPO ColorOS
        FUNTOUCH_OS,    // vivo FuntouchOS
        ORIGIN_OS,      // vivo OriginOS
        ONE_UI,         // 三星 One UI
        FLYME,          // 魅族 Flyme
        SMARTISAN_OS,   // 锤子 Smartisan OS
        NATIVE,         // 原生Android
        OTHER           // 其他
    }

    /**
     * 获取ROM类型
     */
    fun getRomType(context: Context): RomType {
        return when {
            isMiui() -> RomType.MIUI
            isEmui() -> RomType.EMUI
            isHarmony() -> RomType.HARMONY
            isColorOs() -> RomType.COLOR_OS
            isFuntouchOs() -> RomType.FUNTOUCH_OS
            isOriginOs() -> RomType.ORIGIN_OS
            isOneUi() -> RomType.ONE_UI
            isFlyme() -> RomType.FLYME
            isSmartisanOs() -> RomType.SMARTISAN_OS
            isNativeAndroid() -> RomType.NATIVE
            else -> RomType.OTHER
        }
    }

    /**
     * 获取自启动设置Intent
     */
    fun getAutoStartSettingIntent(context: Context): Intent? {
        val romType = getRomType(context)
        val intents = when (romType) {
            RomType.MIUI -> getMiuiAutoStartIntents()
            RomType.EMUI, RomType.HARMONY -> getHuaweiAutoStartIntents()
            RomType.COLOR_OS -> getColorOsAutoStartIntents()
            RomType.FUNTOUCH_OS, RomType.ORIGIN_OS -> getVivoAutoStartIntents()
            RomType.ONE_UI -> getSamsungAutoStartIntents()
            RomType.FLYME -> getFlymeAutoStartIntents()
            RomType.SMARTISAN_OS -> getSmartisanAutoStartIntents()
            else -> listOf(getAppDetailSettingIntent(context))
        }

        // 尝试每个Intent，直到找到可用的
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.resolveActivity(context.packageManager) != null) {
                    return intent
                }
            } catch (e: Exception) {
                Log.d(TAG, "Intent not available: ${e.message}")
            }
        }

        // 如果都失败，返回应用详情设置
        return getAppDetailSettingIntent(context)
    }

    /**
     * 获取应用详情设置Intent
     */
    fun getAppDetailSettingIntent(context: Context): Intent {
        return Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", context.packageName, null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }

    // ==================== ROM检测方法 ====================

    private fun isMiui(): Boolean {
        return getSystemProperty("ro.miui.ui.version.name").isNotEmpty()
    }

    private fun isEmui(): Boolean {
        return getSystemProperty("ro.build.version.emui").isNotEmpty()
    }

    private fun isHarmony(): Boolean {
        return getSystemProperty("ro.build.version.harmonyos").isNotEmpty()
    }

    private fun isColorOs(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return manufacturer.contains("oppo") ||
               manufacturer.contains("realme") ||
               manufacturer.contains("oneplus") ||
               getSystemProperty("ro.build.version.oplusrom").isNotEmpty() ||
               getSystemProperty("ro.coloros.version").isNotEmpty()
    }

    private fun isFuntouchOs(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return manufacturer.contains("vivo") && getSystemProperty("ro.vivo.os.version").isNotEmpty()
    }

    private fun isOriginOs(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return manufacturer.contains("vivo") && getSystemProperty("ro.vivo.os.build.display.id").contains("Origin")
    }

    private fun isOneUi(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return manufacturer.contains("samsung")
    }

    private fun isFlyme(): Boolean {
        return getSystemProperty("ro.build.display.id").lowercase().contains("flyme")
    }

    private fun isSmartisanOs(): Boolean {
        return getSystemProperty("ro.smartisan.version").isNotEmpty()
    }

    private fun isNativeAndroid(): Boolean {
        return Build.MANUFACTURER.lowercase() in listOf("google", "android")
    }

    // ==================== 厂商自启动Intent列表 ====================

    /**
     * 小米MIUI自启动设置
     */
    private fun getMiuiAutoStartIntents(): List<Intent> {
        return listOf(
            // MIUI 12+
            Intent().apply {
                action = "miui.intent.action.APP_PERM_EDITOR"
                putExtra("extra_pkgname", "com.qiaoqiao.qiaoqiao_companion")
            },
            // 旧版MIUI
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )
            },
        )
    }

    /**
     * 华为EMUI/HarmonyOS自启动设置
     */
    private fun getHuaweiAutoStartIntents(): List<Intent> {
        return listOf(
            // HarmonyOS
            Intent().apply {
                component = ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                )
            },
            // EMUI
            Intent().apply {
                action = "huawei.intent.action.HSM_BOOTAPP_MANAGER"
            },
            // 旧版EMUI
            Intent().apply {
                component = ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity"
                )
            },
        )
    }

    /**
     * OPPO ColorOS自启动设置
     */
    private fun getColorOsAutoStartIntents(): List<Intent> {
        return listOf(
            // ColorOS 15+
            Intent().apply {
                component = ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                )
            },
            // ColorOS 13-14
            Intent().apply {
                component = ComponentName(
                    "com.oppo.safe",
                    "com.oppo.safe.permission.startup.StartupAppListActivity"
                )
            },
            // ColorOS 11-12
            Intent().apply {
                component = ComponentName(
                    "com.coloros.oppoguardelf",
                    "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"
                )
            },
            // 旧版ColorOS
            Intent().apply {
                component = ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startupapp.StartupAppListActivity"
                )
            },
            // 打开安全中心
            Intent().apply {
                component = ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.MainActivity"
                )
            },
        )
    }

    /**
     * vivo自启动设置
     */
    private fun getVivoAutoStartIntents(): List<Intent> {
        return listOf(
            // OriginOS
            Intent().apply {
                component = ComponentName(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.SoftPermissionDetailActivity"
                )
                putExtra("packagename", "com.qiaoqiao.qiaoqiao_companion")
            },
            // FuntouchOS
            Intent().apply {
                component = ComponentName(
                    "com.ivivo.permissionmanager",
                    "com.ivivo.permissionmanager.activity.PureBackgroundPermissionActivity"
                )
            },
            // 旧版
            Intent().apply {
                action = "com.vivo.permissionmanager"
                putExtra("packagename", "com.qiaoqiao.qiaoqiao_companion")
            },
        )
    }

    /**
     * 三星One UI自启动设置
     */
    private fun getSamsungAutoStartIntents(): List<Intent> {
        return listOf(
            // 打开电池设置
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", "com.qiaoqiao.qiaoqiao_companion", null)
            },
        )
    }

    /**
     * 魅族Flyme自启动设置
     */
    private fun getFlymeAutoStartIntents(): List<Intent> {
        return listOf(
            Intent().apply {
                action = "com.meizu.safe.security.SHOW_APPSEC"
                putExtra("packageName", "com.qiaoqiao.qiaoqiao_companion")
            },
            Intent().apply {
                component = ComponentName(
                    "com.meizu.safe",
                    "com.meizu.safe.permission.SmartBackgroundActivity"
                )
            },
        )
    }

    /**
     * 锤子Smartisan OS自启动设置
     */
    private fun getSmartisanAutoStartIntents(): List<Intent> {
        return listOf(
            Intent().apply {
                action = "com.smartisanos.security.ACTION_APPLICATION_SETTINGS"
            },
        )
    }

    // ==================== 电池优化和省电设置 ====================

    /**
     * 检查应用是否在电池优化白名单中
     */
    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(context.packageName)
        } else {
            true // Android 6.0以下不需要此权限
        }
    }

    /**
     * 获取电池优化设置Intent
     */
    fun getBatteryOptimizationIntent(context: Context): Intent? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
            }
        } else {
            null
        }
    }

    /**
     * 获取省电设置Intent（厂商特定）
     */
    fun getPowerSavingSettingIntent(context: Context): Intent? {
        val romType = getRomType(context)
        val intents = when (romType) {
            RomType.MIUI -> getMiuiPowerSavingIntents(context)
            RomType.EMUI, RomType.HARMONY -> getHuaweiPowerSavingIntents()
            RomType.COLOR_OS -> getColorOsPowerSavingIntents()
            RomType.FUNTOUCH_OS, RomType.ORIGIN_OS -> getVivoPowerSavingIntents()
            RomType.ONE_UI -> getSamsungPowerSavingIntents()
            else -> listOf(getAppDetailSettingIntent(context))
        }

        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.resolveActivity(context.packageManager) != null) {
                    return intent
                }
            } catch (e: Exception) {
                Log.d(TAG, "Power saving intent not available: ${e.message}")
            }
        }
        return getAppDetailSettingIntent(context)
    }

    /**
     * 小米MIUI省电设置
     */
    private fun getMiuiPowerSavingIntents(context: Context): List<Intent> {
        return listOf(
            // MIUI 12+ 省电策略
            Intent().apply {
                action = "miui.intent.action.APP_PERM_EDITOR"
                putExtra("extra_pkgname", context.packageName)
            },
            // 电池优化设置
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", context.packageName, null)
            },
        )
    }

    /**
     * 华为省电设置
     */
    private fun getHuaweiPowerSavingIntents(): List<Intent> {
        return listOf(
            Intent().apply {
                component = ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.power.ui.HwPowerManagerActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity"
                )
            },
        )
    }

    /**
     * OPPO省电设置
     */
    private fun getColorOsPowerSavingIntents(): List<Intent> {
        return listOf(
            Intent().apply {
                component = ComponentName(
                    "com.coloros.oppoguardelf",
                    "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.MainActivity"
                )
            },
        )
    }

    /**
     * vivo省电设置
     */
    private fun getVivoPowerSavingIntents(): List<Intent> {
        return listOf(
            Intent().apply {
                component = ComponentName(
                    "com.vivo.abe",
                    "com.vivo.abe.ui.ExcessivePowerActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.i.vivo.permissionmanager",
                    "com.i.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                )
            },
        )
    }

    /**
     * 三星省电设置
     */
    private fun getSamsungPowerSavingIntents(): List<Intent> {
        return listOf(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", "com.qiaoqiao.qiaoqiao_companion", null)
            },
        )
    }

    // ==================== 工具方法 ====================

    /**
     * 获取系统属性
     */
    @SuppressLint("PrivateApi")
    private fun getSystemProperty(propName: String): String {
        val line: String
        var input: BufferedReader? = null
        try {
            val p = Runtime.getRuntime().exec("getprop $propName")
            input = BufferedReader(InputStreamReader(p.inputStream), 1024)
            line = input.readLine()
            input.close()
        } catch (e: IOException) {
            Log.e(TAG, "Failed to get system property: $propName", e)
            return ""
        } finally {
            try {
                input?.close()
            } catch (e: IOException) {
                Log.e(TAG, "Error closing stream", e)
            }
        }
        return line ?: ""
    }
}
