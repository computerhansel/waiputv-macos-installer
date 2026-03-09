#!/bin/bash
# ============================================================
# WaipuTV.app Installer für macOS v2.3 (Safari-Branch)
# WKWebView – kein Browser-Chrome, immer im Vordergrund
# Login-Session wird persistent gespeichert (wie Safari)
# ============================================================

APP_NAME="WaipuTV"
INSTALL_DIR="$HOME/Applications"
APP_PATH="$INSTALL_DIR/$APP_NAME.app"
CONTENTS="$APP_PATH/Contents"
MACOS="$CONTENTS/MacOS"

echo "🎬 WaipuTV.app wird installiert..."
mkdir -p "$MACOS"

# ── swiftc prüfen ────────────────────────────────────────────
if ! command -v swiftc &>/dev/null; then
  echo ""
  echo "❌ Xcode Command Line Tools fehlen."
  echo "   Bitte installieren und danach erneut ausführen:"
  echo "   xcode-select --install"
  exit 1
fi

# ── Bildschirmgröße einmalig ermitteln ───────────────────────
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
  <key>CFBundleExecutable</key>         <string>WaipuTV</string>
  <key>CFBundleIdentifier</key>         <string>de.waipu.launcher</string>
  <key>CFBundleName</key>               <string>WaipuTV</string>
  <key>CFBundleVersion</key>            <string>2.3</string>
  <key>CFBundlePackageType</key>        <string>APPL</string>
  <key>LSMinimumSystemVersion</key>     <string>12.0</string>
  <key>NSHighResolutionCapable</key>    <true/>
  <key>NSAppTransportSecurity</key>
    <dict><key>NSAllowsArbitraryLoads</key><true/></dict>
</dict>
</plist>
PLIST

# ── Swift-Quelle generieren (Position als Konstanten einbacken) ──
SWIFT_SRC=$(mktemp /tmp/waiputv_XXXXXX.swift)

# Kein 'SWIFT' (unquoted) → Shell expandiert ${WIN_X} etc. jetzt
cat > "$SWIFT_SRC" << SWIFT
import AppKit
import WebKit

// Position eingebacken beim Install – kein Overhead beim Start
let fixedX: CGFloat    = ${WIN_X}
let fixedYTop: CGFloat = ${WIN_Y}   // von oben (CSS/Chrome-Koordinaten)
let fixedW: CGFloat    = ${WIN_W}
let fixedH: CGFloat    = ${WIN_H}
let screenH: CGFloat   = ${SCREEN_H}

func makeAppIcon() -> NSImage {
    let size: CGFloat = 256
    let icon = NSImage(size: NSSize(width: size, height: size))
    icon.lockFocus()

    // Blauer abgerundeter Hintergrund
    NSColor(red: 0.04, green: 0.40, blue: 0.90, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                 xRadius: 50, yRadius: 50).fill()

    // TV-Symbol (SF Symbol) weiß zentriert
    if let sym = NSImage(systemSymbolName: "tv.fill", accessibilityDescription: nil) {
        let cfg = NSImage.SymbolConfiguration(pointSize: 130, weight: .medium)
        let s   = sym.withSymbolConfiguration(cfg) ?? sym
        NSColor.white.set()
        let sw = s.size.width, sh = s.size.height
        s.draw(in: NSRect(x: (size - sw) / 2, y: (size - sh) / 2, width: sw, height: sh),
               from: .zero, operation: .sourceOver, fraction: 1)
    }
    icon.unlockFocus()
    return icon
}

class WaipuDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!

    func applicationDidFinishLaunching(_ n: Notification) {
        // App-Icon setzen (Dock + App-Switcher)
        NSApp.applicationIconImage = makeAppIcon()

        // NSWindow: Ursprung unten-links → umrechnen
        let actualScreenH = NSScreen.main?.frame.height ?? screenH
        let nsY = actualScreenH - fixedYTop - fixedH

        window = NSWindow(
            contentRect: NSRect(x: fixedX, y: nsY, width: fixedW, height: fixedH),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "WaipuTV"
        window.level = .floating                              // immer im Vordergrund
        window.collectionBehavior = [.canJoinAllSpaces,       // alle Spaces
                                     .fullScreenAuxiliary]    // über Vollbild-Apps

        let cfg = WKWebViewConfiguration()
        // Gleiche persistente Session wie Safari (Login bleibt erhalten)
        cfg.websiteDataStore = WKWebsiteDataStore.default()

        webView = WKWebView(frame: NSRect(origin: .zero,
                                         size: NSSize(width: fixedW, height: fixedH)),
                            configuration: cfg)
        webView.autoresizingMask         = [.width, .height]
        webView.navigationDelegate       = self
        // Safari-UserAgent → waipu.tv erkennt uns als Safari
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6.1 Safari/605.1.15"
        webView.load(URLRequest(url: URL(string: "https://play.waipu.tv/rtl")!))

        window.contentView!.addSubview(webView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

let app      = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = WaipuDelegate()
app.delegate = delegate
app.run()
SWIFT

# ── Kompilieren ──────────────────────────────────────────────
echo "⚙️  Kompiliere WaipuTV (einmalig, ~10–30s auf älteren Macs)..."
if swiftc -O -o "$MACOS/WaipuTV" "$SWIFT_SRC" 2>/tmp/waiputv_err.txt; then
  strip "$MACOS/WaipuTV" 2>/dev/null || true
  echo "✅ Kompilierung erfolgreich"
else
  echo "❌ Kompilierung fehlgeschlagen:"
  cat /tmp/waiputv_err.txt
  rm -f "$SWIFT_SRC" /tmp/waiputv_err.txt
  exit 1
fi
rm -f "$SWIFT_SRC" /tmp/waiputv_err.txt

# ── Launch Services registrieren ────────────────────────────
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$LSREG" -f "$APP_PATH" 2>/dev/null || true

# Quarantine-Flag entfernen
xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true

echo ""
echo "✅ WaipuTV.app installiert:"
echo "   $APP_PATH"
echo ""
echo "ℹ️  Beim ersten Start bitte bei waipu.tv einloggen – Session wird gespeichert."
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
