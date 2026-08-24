#!/usr/bin/env bash
# Render design/*.svg into every launcher icon under design/icons/.
#
# Headless Chrome is the renderer. The SVG goes into a wrapper page that pins
# it to the full viewport, and the size comes from --force-device-scale-factor
# rather than --window-size: Chrome rasterises the vector straight at the
# target resolution, so a 20px icon is drawn at 20px instead of being a
# downscale. Shooting the bare .svg is what put the old art in the top-left
# quarter of the canvas — the window was bigger than the SVG's own box.
#
# Nothing here runs on the build machine: apply_branding.sh only copies the
# PNGs this writes.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/design/icons"
work="$(mktemp -d)"
shots=0
trap 'rm -rf "$work"' EXIT

# ------------------------------------------------------------------ chrome
chrome=""
for c in \
  "${CHROME:-}" \
  "/c/Program Files/Google/Chrome/Application/chrome.exe" \
  "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "$(command -v google-chrome || true)" \
  "$(command -v chromium || true)"; do
  if [ -n "$c" ] && [ -x "$c" ]; then chrome="$c"; break; fi
done
[ -n "$chrome" ] || { echo "render_icons: no Chrome found; set CHROME=" >&2; exit 1; }

# Chrome on Windows wants Windows paths; everywhere else the path is the path.
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1"; fi; }

# page <svg-name> -- wrapper that fills the viewport with the artwork.
page() {
  cp "$root/design/$1" "$work/$1"
  cat > "$work/page-$1.html" <<HTML
<!doctype html><meta charset="utf-8">
<style>html,body{margin:0;padding:0;background:transparent;overflow:hidden}
img{display:block;width:100vw;height:100vw}</style>
<img src="$1">
HTML
}

# shot <svg-name> <size> <out-path> [background]
shot() {
  local svg=$1 size=$2 dest=$3 bg=${4:-00000000}
  local dsf
  dsf=$(awk -v s="$size" 'BEGIN{printf "%.10g", s/512}')
  mkdir -p "$(dirname "$dest")"
  shots=$((shots + 1))
  # A fresh profile per shot: Chrome locks the one it is given, so a reused
  # --user-data-dir makes every run after the first exit without writing.
  "$chrome" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
    --default-background-color="$bg" --virtual-time-budget=3000 \
    --user-data-dir="$(winpath "$work/profile-$shots")" \
    --force-device-scale-factor="$dsf" \
    --window-size=512,512 \
    --screenshot="$(winpath "$dest")" \
    "$(winpath "$work/page-$svg.html")" >/dev/null 2>&1
  [ -f "$dest" ] || { echo "render_icons: failed to write $dest" >&2; exit 1; }
  printf '  %s (%s)\n' "${dest#$root/}" "$size"
}

for f in logo.svg logo-square.svg logo-maskable.svg logo-favicon.svg; do page "$f"; done

# --------------------------------------------------------------------- web
echo "web:"
shot logo.svg 192 "$out/web/Icon-192.png"
shot logo.svg 512 "$out/web/Icon-512.png"
shot logo-maskable.svg 192 "$out/web/Icon-maskable-192.png"
shot logo-maskable.svg 512 "$out/web/Icon-maskable-512.png"
shot logo-favicon.svg 32 "$out/web/favicon.png"
# iOS masks the home-screen icon itself, so hand it the square opaque art at
# Apple's own 180px rather than the rounded tile.
shot logo-square.svg 180 "$out/web/apple-touch-icon.png" 0F1C22FF

# ----------------------------------------------------------------- android
echo "android:"
for pair in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  shot logo.svg "${pair#*:}" "$out/android/mipmap-${pair%:*}/ic_launcher.png"
done

# --------------------------------------------------------------------- ios
# Opaque background, and the alpha channel stripped below: App Store Connect
# rejects an app icon that carries one.
echo "ios:"
ios="20x20@1x:20 20x20@2x:40 20x20@3x:60 29x29@1x:29 29x29@2x:58 29x29@3x:87
     40x40@1x:40 40x40@2x:80 40x40@3x:120 60x60@2x:120 60x60@3x:180
     76x76@1x:76 76x76@2x:152 83.5x83.5@2x:167 1024x1024@1x:1024"
for pair in $ios; do
  shot logo-square.svg "${pair#*:}" "$out/ios/Icon-App-${pair%:*}.png" 0F1C22FF
done

echo "stripping alpha from the ios set..."
"$root/tool/strip_alpha.sh" "$out/ios"

echo "render_icons: $shots icons rendered"
