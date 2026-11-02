#!/usr/bin/env bash
# Launch the Godot 4 Card Wars project
# NOTE: Never silence or suppress any warnings or errors (e.g. X11/XIM input warnings, engine logs).
# Full diagnostic and debug output must always remain visible in terminal for debugging.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/home/verivi/.local/bin/godot}"

if [ ! -x "$GODOT_BIN" ]; then
    GODOT_BIN="$(command -v godot || true)"
fi

if [ -z "$GODOT_BIN" ] || [ ! -x "$GODOT_BIN" ]; then
    echo "Error: Godot 4 binary not found!"
    exit 1
fi

echo "==> Launching Card Wars in Godot 4 ($GODOT_BIN)..."
exec "$GODOT_BIN" --path "$ROOT_DIR/godot" "$@"
