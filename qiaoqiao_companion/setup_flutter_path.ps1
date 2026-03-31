# 添加 Flutter 到系统 PATH 环境变量
$flutterPath = "C:\flutter\bin"

# 获取当前用户 PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

# 检查是否已存在
if ($currentPath -like "*$flutterPath*") {
    Write-Host "Flutter 已存在于 PATH 中，无需重复添加" -ForegroundColor Green
} else {
    # 添加到 PATH
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$flutterPath", "User")
    Write-Host "Flutter 已成功添加到用户 PATH 环境变量！" -ForegroundColor Green
}

# 验证
Write-Host "`n验证 Flutter 安装：" -ForegroundColor Yellow
& "$flutterPath\flutter.bat" --version

Write-Host "`n请关闭当前终端窗口，重新打开一个新的终端窗口使环境变量生效。" -ForegroundColor Cyan
Write-Host "设置完成后，可以在项目目录执行: flutter clean && flutter pub get && flutter build apk --release" -ForegroundColor Cyan
