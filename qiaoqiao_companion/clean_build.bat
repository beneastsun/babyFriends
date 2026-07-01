@echo off
chcp 65001 >nul
echo ========================================
echo 清理 Flutter 和 Gradle 构建缓存
echo ========================================
echo.

cd /d "%~dp0"

echo [1/4] 清理 Flutter 构建...
call flutter clean
echo.

echo [2/4] 删除 Android 构建目录...
if exist "android\app\build" rmdir /s /q "android\app\build"
if exist "android\build" rmdir /s /q "android\build"
echo.

echo [3/4] 删除 .dart_tool 目录...
if exist ".dart_tool" rmdir /s /q ".dart_tool"
echo.

echo [4/4] 重新获取依赖...
call flutter pub get
echo.

echo ========================================
echo 清理完成！现在可以运行 flutter run
echo ========================================
pause
