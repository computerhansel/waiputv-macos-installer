#!/bin/bash
# ============================================================
# WaipuTV.app Installer für macOS v2.2
# ============================================================

APP_NAME="WaipuTV"
INSTALL_DIR="$HOME/Applications"
APP_PATH="$INSTALL_DIR/$APP_NAME.app"
CONTENTS="$APP_PATH/Contents"
MACOS="$CONTENTS/MacOS"

echo "🎬 WaipuTV.app wird installiert..."
mkdir -p "$MACOS"

# ── Bildschirmgröße EINMALIG beim Installieren ermitteln ─────
# Wird direkt in den Launcher eingebacken → kein Overhead beim Start
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
  <key>CFBundleVersion</key>      <string>2.2</string>
  <key>CFBundlePackageType</key>  <string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# ── Haupt-Executable ────────────────────────────────────────
# Position wird als Konstante eingebacken (kein JXA/Python beim Start)
{
  echo "#!/bin/bash"
  echo "WIN_X=${WIN_X}"
  echo "WIN_Y=${WIN_Y}"
  echo "WIN_W=${WIN_W}"
  echo "WIN_H=${WIN_H}"
  cat << 'LAUNCHER'

LOG="$(dirname "$0")/../waipu.log"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
WAIPU_PROFILE="$HOME/.waiputv-profile"

if [[ ! -f "$CHROME" ]]; then
  osascript -e 'display alert "Google Chrome nicht gefunden" message "Bitte Chrome in /Applications installieren."'
  exit 1
fi

# Erster Start: Login-Setup
if [[ ! -f "$WAIPU_PROFILE/.waipu_setup_done" ]]; then
  mkdir -p "$WAIPU_PROFILE"
  echo "$(date): Erster Start – Setup" >> "$LOG"
  osascript -e 'display alert "WaipuTV – Ersteinrichtung" message "Bitte melde dich bei waipu.tv an und schließe dann das Fenster. Beim nächsten Start startet die App automatisch."'
  "$CHROME" \
    --user-data-dir="$WAIPU_PROFILE" \
    --no-first-run \
    "https://www.waipu.tv/login" >> "$LOG" 2>&1
  touch "$WAIPU_PROFILE/.waipu_setup_done"
  echo "$(date): Setup abgeschlossen" >> "$LOG"
  osascript -e 'display notification "WaipuTV ist jetzt eingerichtet!" with title "WaipuTV"'
fi

echo "$(date): Start WIN_X=$WIN_X WIN_Y=$WIN_Y" >> "$LOG"

"$CHROME" \
  --app="https://play.waipu.tv/rtl" \
  --window-size="${WIN_W},${WIN_H}" \
  --window-position="${WIN_X},${WIN_Y}" \
  --user-data-dir="$WAIPU_PROFILE" \
  --no-default-browser-check \
  --no-first-run \
  --disable-sync \
  --disable-background-networking \
  --disable-default-apps \
  --autoplay-policy=no-user-gesture-required \
  >> "$LOG" 2>&1
LAUNCHER
} > "$MACOS/WaipuTV"

chmod +x "$MACOS/WaipuTV"

# ── App bei Launch Services registrieren ────────────────────
# → App erscheint in Spotlight & Launchpad
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREG" -f "$APP_PATH" 2>/dev/null || true

# Quarantine-Flag entfernen (Gatekeeper-Warnung vermeiden)
xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true

echo ""
echo "✅ WaipuTV.app installiert:"
echo "   $APP_PATH"
echo ""

# ── Dock-Eintrag anbieten ────────────────────────────────────
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
