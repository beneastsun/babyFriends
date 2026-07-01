param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    [string]$ProjectDir
)

if (-not $ProjectDir) { $ProjectDir = (Get-Location).Path }

$iconsDir = Join-Path $ProjectDir "assets\images\icons"
$sourceIcon = Join-Path $iconsDir "$Name.png"
$targetIcon = Join-Path $ProjectDir "assets\images\app_icon.png"
$resDir = Join-Path $ProjectDir "android\app\src\main\res"
$themeResDir = Join-Path (Join-Path $ProjectDir "android\app\src\icons") $Name
$themeResDir = Join-Path $themeResDir "res"

if (-not (Test-Path $sourceIcon)) {
    Write-Error "Icon not found: $sourceIcon"
    Write-Output "Available icons:"
    Get-ChildItem $iconsDir -Filter "*.png" | ForEach-Object { Write-Output ('  - ' + $_.BaseName) }
    exit 1
}

# ── 1. 生成启动器图标 ──
Copy-Item -Path $sourceIcon -Destination $targetIcon -Force
Write-Output "[1/3] Generating launcher icons for theme: $Name"

Push-Location $ProjectDir
try {
    dart run flutter_launcher_icons
} finally {
    Pop-Location
}

# ── 2. 生成通知栏图标（从源图缩小） ──
Write-Output "[2/3] Generating notification icons"

$notifSizes = @{
    "drawable-mdpi" = 24
    "drawable-hdpi" = 36
    "drawable-xhdpi" = 48
    "drawable-xxhdpi" = 72
    "drawable-xxxhdpi" = 96
}

Add-Type -AssemblyName System.Drawing
$sourceImg = [System.Drawing.Image]::FromFile($sourceIcon)
foreach ($dir in $notifSizes.Keys) {
    $size = $notifSizes[$dir]
    $destDir = Join-Path $resDir $dir
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null

    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($sourceImg, 0, 0, $size, $size)
    $graphics.Dispose()

    $notifDest = Join-Path $destDir "ic_notification.png"
    $bmp.Save($notifDest, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}
$sourceImg.Dispose()

# ── 3. 将生成的图标移动到主题目录 ──
Write-Output "[3/3] Moving icons to theme directory"

New-Item -ItemType Directory -Force -Path "$themeResDir\values" | Out-Null

# 启动器图标文件
$launcherFiles = @(
    'mipmap-mdpi\ic_launcher.png',
    'mipmap-hdpi\ic_launcher.png',
    'mipmap-xhdpi\ic_launcher.png',
    'mipmap-xxhdpi\ic_launcher.png',
    'mipmap-xxxhdpi\ic_launcher.png',
    'mipmap-anydpi-v26\ic_launcher.xml',
    'drawable-mdpi\ic_launcher_foreground.png',
    'drawable-hdpi\ic_launcher_foreground.png',
    'drawable-xhdpi\ic_launcher_foreground.png',
    'drawable-xxhdpi\ic_launcher_foreground.png',
    'drawable-xxxhdpi\ic_launcher_foreground.png',
    'values\colors.xml'
)

# 通知图标文件
$notifFiles = @(
    'drawable-mdpi\ic_notification.png',
    'drawable-hdpi\ic_notification.png',
    'drawable-xhdpi\ic_notification.png',
    'drawable-xxhdpi\ic_notification.png',
    'drawable-xxxhdpi\ic_notification.png'
)

$allFiles = $launcherFiles + $notifFiles

foreach ($f in $allFiles) {
    $src = Join-Path $resDir $f
    $dest = Join-Path $themeResDir $f
    if (Test-Path $src) {
        $parent = Split-Path $dest -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        Copy-Item -Path $src -Destination $dest -Force
    }
}

Write-Output ""
Write-Output "Done adding theme '$Name'"
Write-Output ""
Write-Output ("  <string name=""app_icon_theme"">" + $Name + "</string>")
Write-Output "Then rebuild: flutter build apk --release"
