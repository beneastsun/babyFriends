param(
    [Parameter(Mandatory=$true)]
    [string]$Name,
    [string]$ProjectDir = (Get-Location).Path
)

$iconsDir = Join-Path $ProjectDir "assets\images\icons"
$targetIcon = Join-Path $ProjectDir "assets\images\app_icon.png"
$sourceIcon = Join-Path $iconsDir "$Name.png"

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
