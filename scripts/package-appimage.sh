#!/usr/bin/env bash
set -euo pipefail

# Package a Unity StandaloneLinux64 build into an AppImage
# Usage: ./scripts/package-appimage.sh <build_dir> <output_appimage_path>

BUILD_DIR="${1:-Builds/StandaloneLinux64}"
OUTPUT_PATH="${2:-Builds/CardWars-x86_64.AppImage}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Packaging AppImage from: $BUILD_DIR"
echo "==> Target output: $OUTPUT_PATH"

if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: Build directory '$BUILD_DIR' not found!"
    exit 1
fi

# Find executable (CardWars.x86_64 or any *.x86_64)
EXE_NAME=""
if [ -f "$BUILD_DIR/CardWars.x86_64" ]; then
    EXE_NAME="CardWars.x86_64"
else
    EXE_FILE=$(find "$BUILD_DIR" -maxdepth 1 -name "*.x86_64" | head -n 1)
    if [ -n "$EXE_FILE" ]; then
        EXE_NAME=$(basename "$EXE_FILE")
    fi
fi

if [ -z "$EXE_NAME" ]; then
    echo "Error: No .x86_64 executable found in '$BUILD_DIR'!"
    exit 1
fi

APPDIR=$(mktemp -d -t cardwars-appdir-XXXXXX)
trap 'rm -rf "$APPDIR"' EXIT

echo "==> Preparing AppDir at $APPDIR..."
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/192x192/apps"

# Copy build contents
cp -r "$BUILD_DIR"/* "$APPDIR/usr/bin/"
chmod +x "$APPDIR/usr/bin/$EXE_NAME"

# Copy icon
ICON_SRC="$ROOT_DIR/Assets/Texture2D/app_icon.png"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APPDIR/usr/share/icons/hicolor/192x192/apps/cardwars.png"
    cp "$ICON_SRC" "$APPDIR/cardwars.png"
else
    echo "Warning: Icon '$ICON_SRC' not found, creating dummy icon"
    touch "$APPDIR/cardwars.png"
fi

# Desktop Entry
cat <<EOF > "$APPDIR/cardwars.desktop"
[Desktop Entry]
Type=Application
Name=Adventure Time: Card Wars
Exec=$EXE_NAME
Icon=cardwars
Comment=Adventure Time: Card Wars PC Port
Categories=Game;CardGame;
Terminal=false
EOF

cp "$APPDIR/cardwars.desktop" "$APPDIR/usr/share/applications/cardwars.desktop"

# AppRun script (sets working directory to usr/bin so Unity finds Data folder)
cat <<'EOF' > "$APPDIR/AppRun"
#!/bin/sh
set -e
HERE="$(dirname "$(readlink -f "$0")")"
cd "$HERE/usr/bin"
exec ./"$(grep '^Exec=' "$HERE/cardwars.desktop" | head -n1 | cut -d= -f2)" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Download appimagetool if not present
APPIMAGETOOL="${APPIMAGETOOL:-}"
if [ -z "$APPIMAGETOOL" ] || [ ! -x "$APPIMAGETOOL" ]; then
    if command -v appimagetool >/dev/null 2>&1; then
        APPIMAGETOOL="$(command -v appimagetool)"
    else
        echo "==> Downloading appimagetool..."
        TOOL_PATH="/tmp/appimagetool-x86_64.AppImage"
        if [ ! -f "$TOOL_PATH" ]; then
            curl -fsSL -o "$TOOL_PATH" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
            chmod +x "$TOOL_PATH"
        fi
        APPIMAGETOOL="$TOOL_PATH"
    fi
fi

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_PATH")"

echo "==> Running appimagetool..."
export ARCH=x86_64
if [[ "$APPIMAGETOOL" == *".AppImage" ]]; then
    "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" "$OUTPUT_PATH"
else
    "$APPIMAGETOOL" "$APPDIR" "$OUTPUT_PATH"
fi

chmod +x "$OUTPUT_PATH"
echo "==> Successfully created: $OUTPUT_PATH"
