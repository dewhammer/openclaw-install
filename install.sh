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

# When stdin is piped (curl | bash), read from the terminal instead
prompt_read() { if [[ -t 0 ]]; then read "$@"; else read "$@" </dev/tty; fi; }

# --- Detect public IP for controlUi.allowedOrigins ---
detect_ip() {
  local ip=""
  ip=$(curl -fsSL --max-time 5 https://ifconfig.me 2>/dev/null) || \
  ip=$(curl -fsSL --max-time 5 https://api.ipify.org 2>/dev/null) || \
  ip=$(hostname -I 2>/dev/null | awk '{print $1}') || \
  ip="127.0.0.1"
  echo "$ip"
}

# --- Prompts ---
echo ""
echo "=========================================="
echo "  OpenClaw Plug-and-Play Installer"
echo "  Product: $PRODUCT"
echo "=========================================="
echo ""

prompt_read -r -p "Telegram bot token (from https://t.me/botfather): " TELEGRAM_BOT_TOKEN
if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
  echo "Telegram token is required."
  exit 1
fi

OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-$(openssl rand -hex 24)}"

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
  echo "No state-template or state.tgz for product '$PRODUCT'; using empty state."
fi

mkdir -p "$OPENCLAW_STATE_DIR/workspace"

# --- Write openclaw.json with correct controlUi settings ---
echo "Detecting server IP..."
SERVER_IP=$(detect_ip)
echo "Server IP: $SERVER_IP"

cat > "$OPENCLAW_STATE_DIR/openclaw.json" <<OCEOF
{
  "gateway": {
    "bind": "lan",
    "mode": "local",
    "controlUi": {
      "allowedOrigins": [
        "http://${SERVER_IP}:${GATEWAY_PORT}",
        "http://127.0.0.1:${GATEWAY_PORT}",
        "http://localhost:${GATEWAY_PORT}"
      ],
      "allowInsecureAuth": true
    }
  },
  "agents": {
    "defaults": {
      "workspace": "~/.openclaw/workspace"
    }
  }
}
OCEOF

# --- Fix permissions for container (runs as uid 1000 / node) ---
chown -R 1000:1000 "$OPENCLAW_STATE_DIR" 2>/dev/null || true

# --- Pull image first ---
echo "Pulling OpenClaw image (this may take a minute)..."
$COMPOSE_CMD pull openclaw-gateway

# --- Start gateway ---
echo "Starting OpenClaw Gateway..."
$COMPOSE_CMD up -d openclaw-gateway

# Wait for gateway to be ready
echo "Waiting for gateway to start..."
for i in $(seq 1 30); do
  if curl -fsSL -o /dev/null "http://127.0.0.1:${GATEWAY_PORT}/healthz" 2>/dev/null; then
    echo "Gateway is healthy."
    break
  fi
  sleep 2
done

# --- Add Telegram channel ---
echo "Adding Telegram channel..."
$COMPOSE_CMD --profile tools run --rm -T openclaw-cli channels add --channel telegram --token "$TELEGRAM_BOT_TOKEN" 2>/dev/null || true

# --- Done ---
# Write a clickable-url.txt so the user can always find the URL
DASHBOARD_URL="http://${SERVER_IP}:${GATEWAY_PORT}/#token=${OPENCLAW_GATEWAY_TOKEN}"
echo "$DASHBOARD_URL" > "$SCRIPT_DIR/dashboard-url.txt"

cat <<DONE

==========================================
  OpenClaw is running!
==========================================

  STEP 1: Copy this entire line (triple-click to select the whole line):

$DASHBOARD_URL

  STEP 2: Paste it into your browser ADDRESS BAR (not the search box).

  If that does not work, open this in two steps:
    1. Go to:  http://${SERVER_IP}:${GATEWAY_PORT}
    2. In the Gateway Token field, paste:  ${OPENCLAW_GATEWAY_TOKEN}
    3. Click Connect.

  This URL is also saved to: $(pwd)/dashboard-url.txt

------------------------------------------
  Gateway token: $OPENCLAW_GATEWAY_TOKEN
  State dir:     $OPENCLAW_STATE_DIR
------------------------------------------

  Useful commands:
    Restart:  cd $(pwd) && $COMPOSE_CMD restart openclaw-gateway
    Stop:     cd $(pwd) && $COMPOSE_CMD down
    Update:   cd $(pwd) && $COMPOSE_CMD pull && $COMPOSE_CMD up -d

  If Telegram was not added:
    cd $(pwd)
    $COMPOSE_CMD --profile tools run --rm openclaw-cli channels add --channel telegram --token YOUR_TOKEN

DONE
