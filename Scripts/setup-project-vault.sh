#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VAULT="$ROOT/project-docs/project-management"
CONFIG_SOURCE="$ROOT/Vendor/obsidian-config-layer"
CONFIG_DEST="$VAULT/.obsidian/plugins/config-layer"
CONFIG_DATA="$CONFIG_DEST/data.json"
COMMUNITY="$VAULT/.obsidian/community-plugins.json"
SHARED_CONFIG="${OBSIDIAN_SHARED_CONFIG_DIR:-$HOME/dotfiles/obsidian}"

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
}

require_command git
require_command npm
require_command python3

printf '\n[1/5] Initializing submodules...\n'
git -C "$ROOT" submodule update --init --recursive

printf '\n[2/5] Building Config Layer...\n'
(
  cd "$CONFIG_SOURCE"
  npm install --no-package-lock
  npm run build
)

if [[ ! -f "$CONFIG_SOURCE/manifest.json" || ! -f "$CONFIG_SOURCE/main.js" ]]; then
  echo "Config Layer build did not produce manifest.json and main.js" >&2
  exit 1
fi

printf '\n[3/5] Installing Config Layer into the project-management vault...\n'
mkdir -p "$CONFIG_DEST"
cp "$CONFIG_SOURCE/manifest.json" "$CONFIG_DEST/manifest.json"
cp "$CONFIG_SOURCE/main.js" "$CONFIG_DEST/main.js"

if [[ -f "$CONFIG_SOURCE/styles.css" ]]; then
  cp "$CONFIG_SOURCE/styles.css" "$CONFIG_DEST/styles.css"
else
  rm -f "$CONFIG_DEST/styles.css"
fi

printf '\n[4/5] Configuring shared Obsidian settings...\n'
if [[ -d "$SHARED_CONFIG" ]]; then
  python3 - "$CONFIG_DATA" "$SHARED_CONFIG" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
shared = Path(sys.argv[2]).expanduser()

try:
    current = json.loads(path.read_text()) if path.exists() else {}
except Exception:
    current = {}

if not isinstance(current, dict):
    current = {}

current.setdefault("enabledCssFiles", {})
current.setdefault("managedHotkeys", {})
current.setdefault("hotkeyBackups", {})
current.setdefault("watchExternalFiles", True)

if not str(current.get("cssFolder", "")).strip():
    current["cssFolder"] = str(shared / "css")
if not str(current.get("hotkeysFolder", "")).strip():
    current["hotkeysFolder"] = str(shared)
if "pluginsFolder" not in current:
    current["pluginsFolder"] = ""

path.write_text(json.dumps(current, ensure_ascii=False, indent=2) + "\n")
PY
  echo "Shared Config Layer path: $SHARED_CONFIG"
else
  echo "Shared Obsidian config directory not found: $SHARED_CONFIG" >&2
  echo "Config Layer was installed, but shared CSS/hotkeys/plugins were not configured." >&2
  echo "Set OBSIDIAN_SHARED_CONFIG_DIR and rerun this script if your dotfiles live elsewhere." >&2
fi

printf '\n[5/5] Enabling Config Layer in the vault...\n'
mkdir -p "$(dirname "$COMMUNITY")"
python3 - "$COMMUNITY" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    current = json.loads(path.read_text()) if path.exists() else []
except Exception:
    current = []

if "config-layer" not in current:
    current.append("config-layer")

path.write_text(json.dumps(current, ensure_ascii=False, indent=2) + "\n")
PY

printf '\nProject-management vault setup complete.\n'
echo "Restart Obsidian or reload the vault."
echo "On Config Layer startup, plugins listed in $SHARED_CONFIG/plugins.json are installed/enabled automatically."
