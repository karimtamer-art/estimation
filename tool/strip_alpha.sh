#!/usr/bin/env bash
# Flatten every PNG in a directory to 24-bit RGB. App Store Connect rejects an
# app icon that carries an alpha channel, and Chrome always writes RGBA.
#
# ImageMagick if it is here, otherwise Windows' own GDI+ through PowerShell.
set -eu
dir=${1:?usage: strip_alpha.sh <dir>}

if command -v magick >/dev/null 2>&1; then
  for f in "$dir"/*.png; do
    magick "$f" -background '#0F1C22' -alpha remove -alpha off -define png:color-type=2 "$f"
  done
  echo "strip_alpha: flattened with ImageMagick"
elif command -v powershell.exe >/dev/null 2>&1; then
  win=$(command -v cygpath >/dev/null 2>&1 && cygpath -w "$dir" || printf '%s' "$dir")
  powershell.exe -NoProfile -NonInteractive -Command "
    Add-Type -AssemblyName System.Drawing
    Get-ChildItem -Path '$win\*.png' | ForEach-Object {
      \$src = [System.Drawing.Image]::FromFile(\$_.FullName)
      \$flat = New-Object System.Drawing.Bitmap \$src.Width, \$src.Height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
      \$g = [System.Drawing.Graphics]::FromImage(\$flat)
      \$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#0F1C22'))
      \$g.InterpolationMode = 'HighQualityBicubic'
      \$g.DrawImage(\$src, 0, 0, \$src.Width, \$src.Height)
      \$g.Dispose(); \$src.Dispose()
      \$flat.Save(\$_.FullName + '.tmp', [System.Drawing.Imaging.ImageFormat]::Png)
      \$flat.Dispose()
      Move-Item -Force (\$_.FullName + '.tmp') \$_.FullName
    }" >/dev/null
  echo "strip_alpha: flattened with GDI+"
else
  echo "strip_alpha: no ImageMagick and no PowerShell - ios icons still carry alpha" >&2
  exit 1
fi
