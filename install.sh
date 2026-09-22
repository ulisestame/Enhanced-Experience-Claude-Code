#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SETTINGS_FILE=~/.claude/settings.json

INSTALL_SOUNDS=true
INSTALL_STATUSLINE=true

while [ $# -gt 0 ]; do
  case "$1" in
    --sounds-only)
      INSTALL_STATUSLINE=false
      ;;
    --statusline-only)
      INSTALL_SOUNDS=false
      ;;
    -h|--help)
      echo "Usage: install.sh [--sounds-only | --statusline-only]"
      echo ""
      echo "  (no flags)          Install sounds and the status line"
      echo "  --sounds-only       Install only the sound hooks"
      echo "  --statusline-only   Install only the status line"
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "   Run 'install.sh --help' for usage."
      exit 1
      ;;
  esac
  shift
done

echo "🎨 Installing Claude Code config..."

mkdir -p ~/.claude

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "{}" > "$SETTINGS_FILE"
fi

if [ "$INSTALL_SOUNDS" = true ]; then
  echo "📁 Copying sound files..."
  mkdir -p ~/.claude/sounds
  cp "$SCRIPT_DIR"/*.wav ~/.claude/sounds/
fi

if [ "$INSTALL_STATUSLINE" = true ]; then
  echo "📊 Copying status line script..."
  cp "$SCRIPT_DIR/statusline.sh" ~/.claude/statusline.sh
  chmod +x ~/.claude/statusline.sh

  if ! command -v jq > /dev/null 2>&1; then
    echo "⚠️  'jq' is not installed — the status line needs it to parse session data."
    echo "   Install it with: brew install jq"
  fi
fi

echo "⚙️  Merging configuration into settings.json..."

SETTINGS_FILE="$SETTINGS_FILE" \
HOOKS_FILE="$SCRIPT_DIR/hooks.json" \
INSTALL_SOUNDS="$INSTALL_SOUNDS" \
INSTALL_STATUSLINE="$INSTALL_STATUSLINE" \
python3 << 'PYTHON_SCRIPT'
import json
import os

settings_file = os.environ["SETTINGS_FILE"]
hooks_file = os.environ["HOOKS_FILE"]

with open(settings_file) as f:
    settings = json.load(f)

if os.environ["INSTALL_SOUNDS"] == "true":
    with open(hooks_file) as f:
        new_config = json.load(f)
    settings.setdefault("hooks", {}).update(new_config["hooks"])
    print("✅ Sound hooks merged")

if os.environ["INSTALL_STATUSLINE"] == "true":
    settings["statusLine"] = {
        "type": "command",
        "command": "~/.claude/statusline.sh",
        "padding": 1,
        # Re-run every second: the status line only redraws on events, so
        # without this the spinner freezes and the elapsed time and reset
        # countdowns go stale between turns.
        "refreshInterval": 1,
    }
    print("✅ Status line configured")

with open(settings_file, "w") as f:
    json.dump(settings, f, indent=2)
PYTHON_SCRIPT

echo ""
echo "✨ Installation complete!"
echo "🔄 Restart Claude Code to pick up your new setup."
