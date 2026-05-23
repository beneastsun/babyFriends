# 同步应用名称配置到 strings.xml
# 从 local.properties 读取 app.appName 并更新 strings.xml

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$localPropertiesPath = Join-Path $projectRoot "android\local.properties"
$stringsXmlPath = Join-Path $projectRoot "android\app\src\main\res\values\strings.xml"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "同步应用名称配置" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 读取 local.properties
if (Test-Path $localPropertiesPath) {
    $properties = Get-Content $localPropertiesPath -Encoding UTF8
    $appNameLine = $properties | Where-Object { $_ -match "^app\.appName=(.+)$" }
    
    if ($appNameLine) {
        $appName = $matches[1].Trim()
        Write-Host "从 local.properties 读取到应用名称: $appName" -ForegroundColor Green
        
        # 读取 strings.xml
        if (Test-Path $stringsXmlPath) {
            $stringsContent = Get-Content $stringsXmlPath -Encoding UTF8 -Raw
            
            # 使用正则表达式替换 app_name 的值
            $newContent = $stringsContent -replace '(<string name="app_name">).+?(</string>)', "`$1$appName`$2"
            
            # 写回文件
            Set-Content -Path $stringsXmlPath -Value $newContent -Encoding UTF8 -NoNewline
            Write-Host "已更新 strings.xml" -ForegroundColor Green
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "同步完成！" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Cyan
        } else {
            Write-Host "错误: 找不到 strings.xml 文件" -ForegroundColor Red
        }
    } else {
        Write-Host "警告: 在 local.properties 中未找到 app.appName 配置" -ForegroundColor Yellow
        Write-Host "将使用 strings.xml 中的默认值" -ForegroundColor Yellow
    }
} else {
    Write-Host "错误: 找不到 local.properties 文件" -ForegroundColor Red
}

Write-Host ""
Write-Host "按任意键继续..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
