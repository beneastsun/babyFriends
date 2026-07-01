param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    [string]$ProjectDir = (Get-Location).Path
)

$iconsDir = Join-Path $ProjectDir "assets\images\icons"
$targetIcon = Join-Path $ProjectDir "assets\images\app_icon.png"
$sourceIcon = Join-Path $iconsDir "$Name.png"
$resDir = Join-Path $ProjectDir "android\app\src\main\res"
$themeResDir = Join-Path (Join-Path (Join-Path $ProjectDir "android\app\src\icons") $Name) "res"

if (-not (Test-Path $sourceIcon)) {
    Write-Error "Icon not found: $sourceIcon"
    Write-Output "Available icons:"
    Get-ChildItem $iconsDir -Filter "*.png" | ForEach-Object { "  - $($_.BaseName)" }
    exit 1
}

Copy-Item -Path $sourceIcon -Destination $targetIcon -Force
Write-Output "Switched to icon: $Name"

Push-Location $ProjectDir
try {
    dart run flutter_launcher_icons
} finally {
    Pop-Location
}

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
Write-Output "Updated notification icons: $Name"

if (Test-Path $themeResDir) {
    $themeFiles = @(
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
        'drawable-mdpi\ic_notification.png',
        'drawable-hdpi\ic_notification.png',
        'drawable-xhdpi\ic_notification.png',
        'drawable-xxhdpi\ic_notification.png',
        'drawable-xxxhdpi\ic_notification.png',
        'values\colors.xml'
    )

    foreach ($f in $themeFiles) {
        $src = Join-Path $themeResDir $f
        $dest = Join-Path $resDir $f
        if (Test-Path $src) {
            $parent = Split-Path $dest -Parent
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
            Copy-Item -Path $src -Destination $dest -Force
        }
    }
    Write-Output "Copied theme resources to main res: $Name"
}
