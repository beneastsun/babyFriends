# 测试辅助脚本

## 设备
DEVICE=8711b87c
ADB="C:\Users\chenjj\AppData\Local\Android\Sdk\platform-tools\adb.exe"

## 截图（按场景命名）
shot() {
  local name=$1
  "$ADB" -s $DEVICE exec-out screencap -p > "screenshots/${name}.png"
  echo "Saved: screenshots/${name}.png"
}

## 抓取日志
log() {
  "$ADB" -s $DEVICE logcat -d -v time | grep -E "flutter:|UsageMonitor|ContinuousUsage|OverlayState|Diag|RomUtils" > "logs/${1}.log"
  echo "Saved: logs/${1}.log"
}

## 清空当前会话（让 app 重新从 0 开始）
clear_session() {
  "$ADB" -s $DEVICE shell pm clear com.qiaoqiao.qiaoqiao_companion
}

## 启动 app
start_app() {
  "$ADB" -s $DEVICE shell am start -n com.qiaoqiao.qiaoqiao_companion/.MainActivity
}
