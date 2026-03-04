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
TARBALL="${INSTALL_DIR}/repo.tar.gz"
if ! curl -fsSL "$ARCHIVE_URL" -o "$TARBALL"; then
  echo "Download failed. If the repo is private, make it public or use: git clone then ./install.sh"
  rm -rf "$INSTALL_DIR"
  exit 1
fi
if ! tar -xzf "$TARBALL" -C "$INSTALL_DIR"; then
  echo "Extract failed."
  rm -rf "$INSTALL_DIR"
  exit 1
fi
rm -f "$TARBALL"

# GitHub tarball extracts to <repo-name>-<branch> (e.g. openclaw-install-main)
REPO_NAME="${REPO##*/}"
EXTRACTED="$INSTALL_DIR/${REPO_NAME}-${BRANCH}"
if [[ ! -d "$EXTRACTED" ]]; then
  EXTRACTED=$(find "$INSTALL_DIR" -maxdepth 1 -type d ! -path "$INSTALL_DIR" 2>/dev/null | head -1)
fi
if [[ -z "$EXTRACTED" ]] || [[ ! -f "$EXTRACTED/install.sh" ]]; then
  echo "Unexpected archive layout (no install.sh). Contents of $INSTALL_DIR:"
  ls -la "$INSTALL_DIR"
  rm -rf "$INSTALL_DIR"
  exit 1
fi

cd "$EXTRACTED"
chmod +x install.sh
echo "Running installer..."
exec ./install.sh "$@"
