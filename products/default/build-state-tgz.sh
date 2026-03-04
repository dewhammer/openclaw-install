#!/usr/bin/env bash
# Build products/default/state.tgz from a prepared state dir.
# Usage: ./build-state-tgz.sh /path/to/.openclaw
# Or run from a machine where you've run OpenClaw and have ~/.openclaw configured.
set -e
SOURCE="${1:-$HOME/.openclaw}"
if [[ ! -d "$SOURCE" ]]; then
  echo "Usage: $0 /path/to/.openclaw"
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
tar -czf state.tgz -C "$SOURCE" .
echo "Wrote $SCRIPT_DIR/state.tgz (exclude from git if it contains secrets)."
