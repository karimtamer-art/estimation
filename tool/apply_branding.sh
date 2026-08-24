#!/usr/bin/env bash
# Paint the app's own icons over the ones `flutter create` just wrote.
#
# web/, android/ and ios/ are not in git (see .gitignore) — every clean build
# regenerates them from the Flutter template, Flutter's blue "F" icons and all.
# Run this straight after `flutter create .` and before any build. Every icon
# here is pre-rendered and committed under design/icons/, so this only ever
# copies: no image tooling is needed on the build machine.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/design/icons"
copied=0

# What the app calls itself. The short form is for anywhere a label sits under
# an icon; the long one is for titles, stores and the browser tab.
APP_NAME="Estimation Calculator"
APP_SHORT_NAME="Estimation"

copy() { # from to
  if [ -d "$(dirname "$2")" ]; then
    cp "$1" "$2"
    copied=$((copied + 1))
  fi
}

# ------------------------------------------------------------------- web
if [ -d "$root/web" ]; then
  copy "$src/web/favicon.png" "$root/web/favicon.png"
  copy "$src/web/apple-touch-icon.png" "$root/web/icons/apple-touch-icon.png"
  for f in Icon-192 Icon-512 Icon-maskable-192 Icon-maskable-512; do
    copy "$src/web/$f.png" "$root/web/icons/$f.png"
  done

  # The template's title, description and Flutter-blue theme colour, replaced
  # with the app's. Written via temp files: BSD and GNU sed disagree about -i.
  if [ -f "$root/web/index.html" ]; then
    # Long name in the title, short one in the iOS web-app title: that is the
    # label under the home-screen icon, and iOS clips it past a dozen or so
    # characters.
    # Matched on the tag, not on the template's value, so renaming the app and
    # re-running is enough — no need to regenerate web/ from scratch first.
    sed -e "s|<title>.*</title>|<title>$APP_NAME</title>|" \
        -e 's|href="icons/Icon-192.png"|href="icons/apple-touch-icon.png"|' \
        -e "s|\(name=\"apple-mobile-web-app-title\" content=\)\"[^\"]*\"|\1\"$APP_SHORT_NAME\"|" \
        -e 's|content="A new Flutter project."|content="Estimation scorekeeper — Pocket/Egyptian ruleset."|' \
        "$root/web/index.html" > "$root/web/index.html.tmp"
    mv "$root/web/index.html.tmp" "$root/web/index.html"
    # Browser chrome takes its colour from this; the template has no such tag.
    if ! grep -q 'name="theme-color"' "$root/web/index.html"; then
      sed -e 's|content="black">|content="black">\
  <meta name="theme-color" content="#0F1C22">|' \
          "$root/web/index.html" > "$root/web/index.html.tmp"
      mv "$root/web/index.html.tmp" "$root/web/index.html"
    fi
  fi
  if [ -f "$root/web/manifest.json" ]; then
    sed -e "s|^\([[:space:]]*\)\"name\": \"[^\"]*\"|\1\"name\": \"$APP_NAME\"|" \
        -e "s|\"short_name\": \"[^\"]*\"|\"short_name\": \"$APP_SHORT_NAME\"|" \
        -e 's|"background_color": "#0175C2"|"background_color": "#0F1C22"|' \
        -e 's|"theme_color": "#0175C2"|"theme_color": "#0F1C22"|' \
        -e 's|"description": "A new Flutter project."|"description": "Estimation scorekeeper — Pocket/Egyptian ruleset."|' \
        -e 's|"orientation": "portrait-primary"|"orientation": "landscape"|' \
        "$root/web/manifest.json" > "$root/web/manifest.json.tmp"
    mv "$root/web/manifest.json.tmp" "$root/web/manifest.json"
  fi
fi

# --------------------------------------------------------------- android
if [ -d "$root/android" ]; then
  for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    copy "$src/android/mipmap-$d/ic_launcher.png" \
         "$root/android/app/src/main/res/mipmap-$d/ic_launcher.png"
  done

  # flutter create labels the launcher with the raw project name.
  man="$root/android/app/src/main/AndroidManifest.xml"
  if [ -f "$man" ]; then
    sed -e "s|android:label=\"[^\"]*\"|android:label=\"$APP_SHORT_NAME\"|" \
        "$man" > "$man.tmp"
    mv "$man.tmp" "$man"
  fi
fi

# ------------------------------------------------------------------- ios
# Opaque and square on purpose — App Store Connect rejects an icon with alpha.
if [ -d "$root/ios" ]; then
  dest="$root/ios/Runner/Assets.xcassets/AppIcon.appiconset"
  for f in "$src/ios/"*.png; do
    copy "$f" "$dest/$(basename "$f")"
  done

  # CFBundleDisplayName is the label under the icon; CFBundleName is the short
  # name iOS falls back to. PlistBuddy is macOS only, which is where ios/ is.
  plist="$root/ios/Runner/Info.plist"
  if [ -f "$plist" ] && [ -x /usr/libexec/PlistBuddy ]; then
    /usr/libexec/PlistBuddy -c \
      "Set :CFBundleDisplayName $APP_SHORT_NAME" "$plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c \
      "Add :CFBundleDisplayName string $APP_SHORT_NAME" "$plist"
    /usr/libexec/PlistBuddy -c \
      "Set :CFBundleName $APP_SHORT_NAME" "$plist" 2>/dev/null || true
  fi
fi

echo "apply_branding: $copied icon files copied"
