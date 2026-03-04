# Client setup: OpenClaw plug-and-play

One-command install on your VPS (or local machine). You need a Telegram bot token and Docker.

## 1. Get a Telegram bot token

1. Open [Telegram](https://telegram.org) and message [@BotFather](https://t.me/botfather).
2. Send `/newbot` and follow the prompts (name and username).
3. Copy the **token** BotFather returns (e.g. `123456789:ABCdefGHI...`). You will paste it into the installer.

## 2. Install on the server

On your VPS or machine (Linux/macOS with Docker):

```bash
git clone https://github.com/your-org/openclaw-install.git
cd openclaw-install
./install.sh
```

Or with a specific product:

```bash
./install.sh --product default
```

The script will:

- Check for Docker and Docker Compose (exit with instructions if missing).
- Ask for your **Telegram bot token** (from step 1).
- Generate a **gateway token** (save it to open the Control UI).
- Optionally enable Mission Control dashboard (extra prompts).
- Create `.env` and unpack the product state.
- Add the Telegram channel and start the gateway.

## 3. Open the Control UI

- **URL:** `http://<your-server-ip>:18789` (or `http://127.0.0.1:18789` if local).
- In the UI, go to **Settings** and paste the **gateway token** the installer printed.

After that you can use the gateway (sessions, agents) and the Telegram bot will be connected.

## 4. Restart / update

```bash
cd openclaw-install
docker compose down
docker compose up -d
```

To pull newer images and restart:

```bash
docker compose pull
docker compose up -d
```

## 5. If Telegram was not added

If the installer could not add the Telegram channel (e.g. gateway not ready yet), run:

```bash
docker compose run --rm openclaw-cli channels add --channel telegram --token "YOUR_BOT_TOKEN"
```

Then restart the gateway: `docker compose restart openclaw-gateway`.

## 6. Optional: Mission Control dashboard

To run [OpenClaw Mission Control](https://github.com/abhi1693/openclaw-mission-control) on the same host:

1. Clone Mission Control and start it (see its README).
2. Use a different compose project or port (e.g. frontend on 3000, backend on 8000).
3. Point Mission Control at your gateway URL (e.g. `http://<vps-ip>:18789`).

This repo’s `install.sh` can set `ENABLE_MISSION_CONTROL=1` and generate `LOCAL_AUTH_TOKEN`; a future version may include Mission Control in the same stack.

## 7. Backups

Back up the OpenClaw state directory (default: `./openclaw-state`) and optionally the workspace inside it. See [OpenClaw migration guide](https://docs.openclaw.ai/install/migrating) for what to copy when moving to another machine.

## Troubleshooting

- **Docker not found:** Install [Docker](https://docs.docker.com/get-docker/) and Docker Compose v2.
- **Permission errors on state dir:** On Linux, ensure the state dir is writable by the user running Docker (or uid 1000 if the container runs as `node`).
- **Gateway not reachable:** Ensure port 18789 is open on the host/firewall and that `OPENCLAW_GATEWAY_BIND` is `lan` (or appropriate for your network).
