#!/bin/bash
# Builds Pigeonhole.app, signs it, installs it to /Applications and opens it.
# Safe to re-run whenever you pull changes. Set INSTALL_DIR to install
# somewhere else, or pass --no-install to stop after signing.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Pigeonhole"
PRODUCT_NAME="Pigeonhole"
BUNDLE_ID="com.silasns.Pigeonhole"
BUILD_DIR=".build/release"
STAGED_APP="dist/${APP_NAME}.app"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
INSTALLED_APP="${INSTALL_DIR}/${APP_NAME}.app"

INSTALL=1
for arg in "$@"; do
    case "$arg" in
        --no-install) INSTALL=0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

swift build -c release --product "$PRODUCT_NAME"

rm -rf "$STAGED_APP"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources/Fonts"
cp "$BUILD_DIR/$PRODUCT_NAME" "$STAGED_APP/Contents/MacOS/$APP_NAME"

# Picked up at launch through ATSApplicationFontsPath below, so the Modern
# Dev preset gets JetBrains Mono without any font-loading code.
find Resources/Fonts -name '*.ttf' -exec cp {} "$STAGED_APP/Contents/Resources/Fonts/" \;

cat > "$STAGED_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>ATSApplicationFontsPath</key>
    <string>Fonts</string>
</dict>
</plist>
PLIST
plutil -lint "$STAGED_APP/Contents/Info.plist" >/dev/null

# A stable identity keeps the signature the same between builds. Pigeonhole
# keeps nothing in the Keychain and needs no Accessibility grant, so today
# this only keeps the login item pointing at the same app; it's here so a
# permission added later survives rebuilds. Prefers a real Apple identity,
# then the self-signed one from Scripts/create-signing-cert.sh.
find_identity() {
    security find-identity -v -p codesigning \
        | awk -F'"' -v want="$1" '$0 ~ want {print $2; exit}'
}

SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
[ -z "$SIGN_IDENTITY" ] && SIGN_IDENTITY="$(find_identity 'Apple Development')"
[ -z "$SIGN_IDENTITY" ] && SIGN_IDENTITY="$(find_identity 'Pigeonhole Dev')"
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="-"
    echo "Note: no signing identity, falling back to ad-hoc signing."
    echo "      Run Scripts/create-signing-cert.sh once for a stable one."
fi

codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$STAGED_APP"
codesign --verify --strict "$STAGED_APP"

if [ "$INSTALL" -eq 0 ]; then
    echo "Built $STAGED_APP (not installed)."
    exit 0
fi

# Quit only after the build is signed, so a broken build leaves the working
# app running.
if pgrep -xq "$APP_NAME"; then
    echo "Quitting running ${APP_NAME}..."
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" || true
    for _ in $(seq 1 20); do pgrep -xq "$APP_NAME" || break; sleep 0.25; done
    pgrep -xq "$APP_NAME" && pkill -x "$APP_NAME"
fi

# This deletes a directory in $INSTALL_DIR, so make sure it's ours first.
# Assign only on success: plutil prints its errors to stdout.
if [ -e "$INSTALLED_APP" ]; then
    installed_id=""
    if id_read="$(plutil -extract CFBundleIdentifier raw "$INSTALLED_APP/Contents/Info.plist" 2>/dev/null)"; then
        installed_id="$id_read"
    fi
    if [ "$installed_id" != "$BUNDLE_ID" ]; then
        echo "Refusing to replace $INSTALLED_APP:" >&2
        echo "  expected $BUNDLE_ID, found \"${installed_id:-nothing readable}\"." >&2
        echo "  The build is waiting at $STAGED_APP." >&2
        exit 1
    fi
    rm -rf "$INSTALLED_APP"
fi

mkdir -p "$INSTALL_DIR"
# ditto rather than cp, which drops a bundle's extended attributes.
ditto "$STAGED_APP" "$INSTALLED_APP"
rm -rf "$STAGED_APP"
codesign --verify --strict "$INSTALLED_APP"

echo "Installed $INSTALLED_APP"
open "$INSTALLED_APP"
echo "Launched. Look for the cubbies in your menu bar."
