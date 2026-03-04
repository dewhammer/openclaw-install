#!/usr/bin/env bash
# OpenClaw Plug-and-Play: one-command install (no git, no GitHub login).
# Usage: curl -fsSL https://raw.githubusercontent.com/dewhammer/openclaw-install/main/scripts/bootstrap.sh | bash
# Or:    curl -fsSL ... | bash -s -- --product sales-assistant
set -e

REPO="${OPENCLAW_INSTALL_REPO:-dewhammer/openclaw-install}"
BRANCH="${OPENCLAW_INSTALL_BRANCH:-main}"
INSTALL_DIR="/tmp/openclaw-install-$$"
ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"

echo "OpenClaw Plug-and-Play bootstrap"
echo "Downloading installer from GitHub (${REPO} ${BRANCH})..."
mkdir -p "$INSTALL_DIR"
if ! curl -fsSL "$ARCHIVE_URL" | tar -xzf - -C "$INSTALL_DIR"; then
  echo "Download failed. If the repo is private, make it public or use: git clone then ./install.sh"
  rm -rf "$INSTALL_DIR"
  exit 1
fi

# GitHub tarball extracts to openclaw-install-<branch>
EXTRACTED=$(find "$INSTALL_DIR" -maxdepth 1 -type d -name 'openclaw-install-*' | head -1)
if [[ -z "$EXTRACTED" ]] || [[ ! -f "$EXTRACTED/install.sh" ]]; then
  echo "Unexpected archive layout."
  rm -rf "$INSTALL_DIR"
  exit 1
fi

cd "$EXTRACTED"
chmod +x install.sh
echo "Running installer..."
exec ./install.sh "$@"
