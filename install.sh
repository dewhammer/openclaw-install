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
  echo "Error: Run this script from the openclaw-install repo root."
  exit 1
fi

# --- Docker check ---
if ! command -v docker &>/dev/null; then
  echo "Docker is not installed. Install it: https://docs.docker.com/get-docker/"
  exit 1
fi

if ! docker compose version &>/dev/null && ! docker-compose version &>/dev/null; then
  echo "Docker Compose v2 is required."
  exit 1
fi

COMPOSE_CMD="docker compose"
if ! docker compose version &>/dev/null; then
  COMPOSE_CMD="docker-compose"
fi

# When stdin is piped (curl | bash), read from the terminal
prompt_read() { if [[ -t 0 ]]; then read "$@"; else read "$@" </dev/tty; fi; }

detect_ip() {
  local ip=""
  ip=$(curl -4 -fsSL --max-time 5 https://ifconfig.me 2>/dev/null) || \
  ip=$(curl -4 -fsSL --max-time 5 https://api.ipify.org 2>/dev/null) || \
  ip=$(curl -4 -fsSL --max-time 5 https://icanhazip.com 2>/dev/null) || \
  ip=$(hostname -I 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1) || \
  ip="127.0.0.1"
  echo "$ip" | tr -d '[:space:]'
}

echo ""
echo "=========================================="
echo "  OpenClaw Plug-and-Play Installer"
echo "  Product: $PRODUCT"
echo "=========================================="
echo ""

# --- Prompts ---
prompt_read -r -p "Telegram bot token (from https://t.me/botfather): " TELEGRAM_BOT_TOKEN
if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
  echo "Telegram token is required."
  exit 1
fi

OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-$(openssl rand -hex 24)}"

echo ""
echo "Domain setup (HTTPS with automatic SSL certificate)."
echo "Point a subdomain to this server's IP first (e.g. A record -> server IP)."
prompt_read -r -p "Domain for OpenClaw (e.g. openclaw.example.com, or leave empty for IP-only): " OPENCLAW_DOMAIN

prompt_read -r -p "Enable Mission Control dashboard? (0=no, 1=yes) [0]: " ENABLE_MC
ENABLE_MISSION_CONTROL="${ENABLE_MC:-0}"

LOCAL_AUTH_TOKEN=""
if [[ "$ENABLE_MISSION_CONTROL" == "1" ]]; then
  prompt_read -r -p "Mission Control auth token (min 50 chars, or Enter to generate): " LOCAL_AUTH_TOKEN
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
  echo "OPENCLAW_DOMAIN=$OPENCLAW_DOMAIN"
  echo "ENABLE_MISSION_CONTROL=$ENABLE_MISSION_CONTROL"
  [[ -n "$LOCAL_AUTH_TOKEN" ]] && echo "LOCAL_AUTH_TOKEN=$LOCAL_AUTH_TOKEN"
  if [[ "$ENABLE_MISSION_CONTROL" == "1" ]]; then
    echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(openssl rand -base64 24)}"
  fi
  grep -v -e '^TELEGRAM_BOT_TOKEN=' -e '^OPENCLAW_GATEWAY_TOKEN=' -e '^OPENCLAW_STATE_DIR=' \
    -e '^OPENCLAW_DOMAIN=' -e '^ENABLE_MISSION_CONTROL=' -e '^LOCAL_AUTH_TOKEN=' -e '^POSTGRES_PASSWORD=' .env.example || true
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
fi

mkdir -p "$OPENCLAW_STATE_DIR/workspace"

# --- Detect IP ---
echo "Detecting server IP..."
SERVER_IP=$(detect_ip)
echo "Server IP: $SERVER_IP"

# --- Build allowedOrigins and dashboard URL based on domain or IP ---
if [[ -n "$OPENCLAW_DOMAIN" ]]; then
  DASHBOARD_URL="https://${OPENCLAW_DOMAIN}/#token=${OPENCLAW_GATEWAY_TOKEN}"
  ALLOWED_ORIGINS="\"https://${OPENCLAW_DOMAIN}\", \"http://${SERVER_IP}:${GATEWAY_PORT}\", \"http://127.0.0.1:${GATEWAY_PORT}\""
else
  DASHBOARD_URL="http://${SERVER_IP}:${GATEWAY_PORT}/#token=${OPENCLAW_GATEWAY_TOKEN}"
  ALLOWED_ORIGINS="\"http://${SERVER_IP}:${GATEWAY_PORT}\", \"http://127.0.0.1:${GATEWAY_PORT}\", \"http://localhost:${GATEWAY_PORT}\""
fi

# --- Write openclaw.json ---
cat > "$OPENCLAW_STATE_DIR/openclaw.json" <<OCEOF
{
  "gateway": {
    "bind": "lan",
    "mode": "local",
    "port": ${GATEWAY_PORT},
    "trustedProxies": ["0.0.0.0/0"],
    "controlUi": {
      "enabled": true,
      "allowedOrigins": [${ALLOWED_ORIGINS}],
      "allowInsecureAuth": true
    },
    "auth": {
      "mode": "token",
      "token": "${OPENCLAW_GATEWAY_TOKEN}"
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

# --- HTTPS: create Traefik config if domain is set and Traefik is running ---
if [[ -n "$OPENCLAW_DOMAIN" ]]; then
  TRAEFIK_DYN_DIR=""
  if [[ -d /root/traefik-dynamic ]]; then
    TRAEFIK_DYN_DIR="/root/traefik-dynamic"
  elif [[ -d /etc/traefik/dynamic ]]; then
    TRAEFIK_DYN_DIR="/etc/traefik/dynamic"
  fi

  if [[ -n "$TRAEFIK_DYN_DIR" ]]; then
    echo "Setting up HTTPS via Traefik for ${OPENCLAW_DOMAIN}..."
    # Traefik runs in Docker; 127.0.0.1 is the container itself, not the host.
    # Use the Docker bridge gateway IP so Traefik can reach the host-published port.
    DOCKER_HOST_IP=$(docker network inspect bridge --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)
    if [[ -z "$DOCKER_HOST_IP" ]]; then
      DOCKER_HOST_IP="172.17.0.1"
    fi
    cat > "${TRAEFIK_DYN_DIR}/openclaw.yml" <<TRAEFIKEOF
http:
  routers:
    openclaw:
      rule: "Host(\`${OPENCLAW_DOMAIN}\`)"
      service: openclaw-service
      entryPoints:
        - websecure
      tls:
        certResolver: mytlschallenge
      middlewares:
        - openclaw-headers

  middlewares:
    openclaw-headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"

  services:
    openclaw-service:
      loadBalancer:
        servers:
          - url: "http://${DOCKER_HOST_IP}:${GATEWAY_PORT}"
TRAEFIKEOF
    echo "Traefik config written to ${TRAEFIK_DYN_DIR}/openclaw.yml"
    echo "SSL certificate will be provisioned automatically by Let's Encrypt."
  else
    echo "WARNING: No Traefik dynamic config directory found."
    echo "You'll need to set up HTTPS manually (nginx, caddy, etc.) for ${OPENCLAW_DOMAIN}."
  fi
fi

# --- Pull image ---
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

# --- Save URL ---
echo "$DASHBOARD_URL" > "$SCRIPT_DIR/dashboard-url.txt"

cat <<DONE

==========================================
  OpenClaw is running!
==========================================

  Open this in your browser:

$DASHBOARD_URL

  This URL is saved to: $(pwd)/dashboard-url.txt

------------------------------------------
  Gateway token: $OPENCLAW_GATEWAY_TOKEN
  State dir:     $OPENCLAW_STATE_DIR
------------------------------------------

  Useful commands:
    Restart:  cd $(pwd) && $COMPOSE_CMD restart openclaw-gateway
    Stop:     cd $(pwd) && $COMPOSE_CMD down
    Update:   cd $(pwd) && $COMPOSE_CMD pull && $COMPOSE_CMD up -d

DONE
