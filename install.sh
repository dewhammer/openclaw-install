#!/usr/bin/env bash
set -e

# OpenClaw Plug-and-Play Installer
# Run from repo root: ./install.sh [--product PRODUCT]

PRODUCT="${1:-default}"
if [[ "$1" == "--product" ]]; then
  PRODUCT="${2:-default}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ ! -f compose.yml ]] || [[ ! -f .env.example ]]; then
  echo "Error: Run this script from the openclaw-install repo root (where compose.yml and .env.example are)."
  exit 1
fi

# --- Docker check ---
if ! command -v docker &>/dev/null; then
  echo "Docker is not installed or not in PATH."
  echo "Install Docker: https://docs.docker.com/get-docker/"
  exit 1
fi

if ! docker compose version &>/dev/null && ! docker-compose version &>/dev/null; then
  echo "Docker Compose v2 is required. Install it or use Docker Desktop."
  exit 1
fi

COMPOSE_CMD="docker compose"
if ! docker compose version &>/dev/null; then
  COMPOSE_CMD="docker-compose"
fi

# --- Prompts ---
echo "OpenClaw Plug-and-Play Installer (product: $PRODUCT)"
echo ""

# When stdin is piped (curl | bash), read from the terminal instead
prompt_read() { if [[ -t 0 ]]; then read "$@"; else read "$@" </dev/tty; fi; }

prompt_read -r -p "Telegram bot token (from https://t.me/botfather): " TELEGRAM_BOT_TOKEN
if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
  echo "Telegram token is required."
  exit 1
fi

# Generate gateway token if not set
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-$(openssl rand -hex 24)}"
echo "Generated OPENCLAW_GATEWAY_TOKEN (save it to access the Control UI)."

prompt_read -r -p "Enable Mission Control dashboard? (0=no, 1=yes) [0]: " ENABLE_MC
ENABLE_MISSION_CONTROL="${ENABLE_MC:-0}"

LOCAL_AUTH_TOKEN=""
if [[ "$ENABLE_MISSION_CONTROL" == "1" ]]; then
  prompt_read -r -p "Mission Control auth token (min 50 chars, or press Enter to generate): " LOCAL_AUTH_TOKEN
  if [[ -z "$LOCAL_AUTH_TOKEN" ]] || [[ ${#LOCAL_AUTH_TOKEN} -lt 50 ]]; then
    LOCAL_AUTH_TOKEN="$(openssl rand -base64 48)"
    echo "Generated LOCAL_AUTH_TOKEN for Mission Control."
  fi
fi

# --- .env ---
OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-$(pwd)/openclaw-state}"
GATEWAY_PORT="${GATEWAY_PORT:-18789}"

# Build .env: write vars we set, then append rest from .env.example (skip lines we wrote)
{
  echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN"
  echo "OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN"
  echo "OPENCLAW_STATE_DIR=$OPENCLAW_STATE_DIR"
  echo "ENABLE_MISSION_CONTROL=$ENABLE_MISSION_CONTROL"
  [[ -n "$LOCAL_AUTH_TOKEN" ]] && echo "LOCAL_AUTH_TOKEN=$LOCAL_AUTH_TOKEN"
  if [[ "$ENABLE_MISSION_CONTROL" == "1" ]]; then
    echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(openssl rand -base64 24)}"
  fi
  grep -v -e '^TELEGRAM_BOT_TOKEN=' -e '^OPENCLAW_GATEWAY_TOKEN=' -e '^OPENCLAW_STATE_DIR=' \
    -e '^ENABLE_MISSION_CONTROL=' -e '^LOCAL_AUTH_TOKEN=' -e '^POSTGRES_PASSWORD=' .env.example || true
} > .env
export TELEGRAM_BOT_TOKEN OPENCLAW_GATEWAY_TOKEN OPENCLAW_STATE_DIR

# --- State dir + product template ---
mkdir -p "$OPENCLAW_STATE_DIR"
PRODUCT_DIR="products/$PRODUCT"
if [[ -d "$PRODUCT_DIR/state-template" ]]; then
  echo "Unpacking product state template..."
  cp -R "$PRODUCT_DIR"/state-template/* "$OPENCLAW_STATE_DIR/"
elif [[ -f "$PRODUCT_DIR/state.tgz" ]]; then
  echo "Unpacking product state.tgz..."
  tar -xzf "$PRODUCT_DIR/state.tgz" -C "$OPENCLAW_STATE_DIR"
else
  echo "No state-template or state.tgz for product '$PRODUCT'; using empty state (onboarding may be required)."
fi

# Ensure workspace exists
mkdir -p "$OPENCLAW_STATE_DIR/workspace"

# --- Add Telegram channel via CLI ---
echo "Adding Telegram channel..."
$COMPOSE_CMD run --rm -T openclaw-cli channels add --channel telegram --token "$TELEGRAM_BOT_TOKEN" || true
# Allow failure if CLI expects gateway; channel can be added after first start

# --- Start stack ---
echo "Starting OpenClaw Gateway..."
$COMPOSE_CMD up -d openclaw-gateway

echo ""
echo "Done. Gateway is running."
echo "  Control UI: http://127.0.0.1:${GATEWAY_PORT}"
echo "  Gateway token: $OPENCLAW_GATEWAY_TOKEN"
echo "  State dir: $OPENCLAW_STATE_DIR"
echo ""
echo "If Telegram was not added, run: $COMPOSE_CMD run --rm openclaw-cli channels add --channel telegram --token YOUR_TOKEN"
echo "Then open the Control UI, go to Settings, and paste the gateway token."
