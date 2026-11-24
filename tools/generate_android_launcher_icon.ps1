param(
    [string]$Source = "mobile/assets/images/logo_marker.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $root $Source
$resPath = Join-Path $root "mobile/android/app/src/main/res"
$brandGreen = [System.Drawing.Color]::FromArgb(255, 30, 183, 77)

function New-LauncherBitmap {
    param(
        [int]$Size
    )

    $canvas = New-Object System.Drawing.Bitmap($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $brush = New-Object System.Drawing.SolidBrush($brandGreen)
    # Keep the full branded background. Android applies the device-specific
    # circle/squircle mask to both adaptive and round launcher variants.
    $graphics.FillRectangle($brush, 0, 0, $Size, $Size)

    $logo = [System.Drawing.Image]::FromFile($sourcePath)
    $logoSize = [int]($Size * 0.76)
    $offset = [int](($Size - $logoSize) / 2)
    $graphics.DrawImage($logo, $offset, $offset, $logoSize, $logoSize)

    $logo.Dispose()
    $brush.Dispose()
    $graphics.Dispose()
    return $canvas
}

$densities = [ordered]@{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

foreach ($entry in $densities.GetEnumerator()) {
    $directory = Join-Path $resPath $entry.Key
    New-Item -ItemType Directory -Force -Path $directory | Out-Null

    $square = New-LauncherBitmap -Size $entry.Value
    $square.Save(
        (Join-Path $directory "ic_launcher.png"),
        [System.Drawing.Imaging.ImageFormat]::Png
    )
    $square.Dispose()

    $round = New-LauncherBitmap -Size $entry.Value
    $round.Save(
        (Join-Path $directory "ic_launcher_round.png"),
        [System.Drawing.Imaging.ImageFormat]::Png
    )
    $round.Dispose()
}

$foregroundPath = Join-Path $resPath "drawable-nodpi"
New-Item -ItemType Directory -Force -Path $foregroundPath | Out-Null
$foreground = New-Object System.Drawing.Bitmap(432, 432)
$foregroundGraphics = [System.Drawing.Graphics]::FromImage($foreground)
$foregroundGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$foregroundGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$foregroundGraphics.Clear([System.Drawing.Color]::Transparent)
$foregroundLogo = [System.Drawing.Image]::FromFile($sourcePath)
$foregroundGraphics.DrawImage($foregroundLogo, 86, 86, 260, 260)
$foreground.Save(
    (Join-Path $foregroundPath "ic_launcher_foreground.png"),
    [System.Drawing.Imaging.ImageFormat]::Png
)
$foregroundLogo.Dispose()
$foregroundGraphics.Dispose()
$foreground.Dispose()

Write-Host "Android launcher icons generated from $Source"
