#!/bin/bash
# ============================================================
# WaipuTV.app Installer für macOS v1.0 (Safari)
# Kein Chrome benötigt – nutzt Safari via AppleScript
# ⚠️  Hinweis: waipu.tv verwendet Widevine-DRM für verschlüsselte
#    Sender. Safari nutzt FairPlay statt Widevine – manche Sender
#    könnten im Web-Player nicht verfügbar sein.
# ============================================================

APP_NAME="WaipuTV"
INSTALL_DIR="$HOME/Applications"
APP_PATH="$INSTALL_DIR/$APP_NAME.app"
CONTENTS="$APP_PATH/Contents"
MACOS="$CONTENTS/MacOS"

echo "🎬 WaipuTV.app (Safari) wird installiert..."
mkdir -p "$MACOS"

# ── Bildschirmgröße einmalig beim Installieren ermitteln ─────
SCREEN=$(osascript -l JavaScript -e '
  ObjC.import("AppKit");
  const f = $.NSScreen.mainScreen.frame;
  Math.round(f.size.width) + "," + Math.round(f.size.height);
' 2>/dev/null)

SCREEN_W=$(echo "$SCREEN" | cut -d',' -f1 | tr -d ' ')
SCREEN_H=$(echo "$SCREEN" | cut -d',' -f2 | tr -d ' ')
[[ -z "$SCREEN_W" || "$SCREEN_W" -lt 800 ]] && SCREEN_W=1440
[[ -z "$SCREEN_H" || "$SCREEN_H" -lt 600 ]] && SCREEN_H=900

WIN_W=400; WIN_H=300; MARGIN=20; DOCK_OFFSET=80
WIN_X=$(( SCREEN_W - WIN_W - MARGIN ))
WIN_Y=$(( SCREEN_H - WIN_H - DOCK_OFFSET ))
WIN_X2=$(( WIN_X + WIN_W ))
WIN_Y2=$(( WIN_Y + WIN_H ))

echo "📐 Fenster: ${WIN_W}x${WIN_H} @ (${WIN_X},${WIN_Y}) auf ${SCREEN_W}x${SCREEN_H}"

# ── Info.plist ───────────────────────────────────────────────
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>    <string>WaipuTV</string>
  <key>CFBundleIdentifier</key>   <string>de.waipu.launcher</string>
  <key>CFBundleName</key>         <string>WaipuTV</string>
  <key>CFBundleVersion</key>      <string>1.0</string>
  <key>CFBundlePackageType</key>  <string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# ── Haupt-Executable ────────────────────────────────────────
# Fensterposition als Konstanten einbacken → kein Overhead beim Start
{
  echo "#!/bin/bash"
  echo "WIN_X=${WIN_X}"
  echo "WIN_Y=${WIN_Y}"
  echo "WIN_X2=${WIN_X2}"
  echo "WIN_Y2=${WIN_Y2}"
  cat << 'LAUNCHER'

LOG="$(dirname "$0")/../waipu.log"
echo "$(date): Start" >> "$LOG"

# Safari öffnen, URL laden, Fenster positionieren
osascript \
  -e 'tell application "Safari"' \
  -e '  activate' \
  -e '  if (count of windows) is 0 then' \
  -e '    make new document with properties {URL:"https://play.waipu.tv/rtl"}' \
  -e '  else' \
  -e '    set URL of current tab of front window to "https://play.waipu.tv/rtl"' \
  -e '  end if' \
  -e "  set bounds of front window to {$WIN_X, $WIN_Y, $WIN_X2, $WIN_Y2}" \
  -e 'end tell' \
  >> "$LOG" 2>&1
LAUNCHER
} > "$MACOS/WaipuTV"

chmod +x "$MACOS/WaipuTV"

# ── Launch Services registrieren → Spotlight & Launchpad ─────
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREG" -f "$APP_PATH" 2>/dev/null || true

# Quarantine-Flag entfernen
xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true

echo ""
echo "✅ WaipuTV.app (Safari) installiert:"
echo "   $APP_PATH"
echo ""
echo "ℹ️  Safari-Login: Melde dich beim ersten Start im Fenster bei waipu.tv an."
echo "   Safari speichert die Session automatisch."
echo ""
echo "⚠️  DRM-Hinweis: Einige verschlüsselte Sender könnten in Safari"
echo "   nicht verfügbar sein (Widevine vs. FairPlay)."
echo ""

read -p "   Soll WaipuTV zum Dock hinzugefügt werden? (j/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Jj]$ ]]; then
  defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict>\
<key>_CFURLString</key><string>${APP_PATH}</string>\
<key>_CFURLStringType</key><integer>0</integer>\
</dict></dict></dict>"
  killall Dock
  echo "   ✅ Dock-Eintrag erstellt!"
  echo ""
fi

read -p "   Soll WaipuTV.app jetzt direkt geöffnet werden? (j/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Jj]$ ]]; then
  open "$APP_PATH"
fi
