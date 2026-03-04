# OpenClaw Plug-and-Play Install

One-command install for OpenClaw Gateway on a VPS (or local), with Telegram and optional Mission Control. Clients get a single script, one token input, and a running stack.

## Quick start (client)

1. Get a Telegram bot token from [@BotFather](https://t.me/botfather).
2. On your VPS, run **one command** (no git, no GitHub login):

   ```bash
   curl -fsSL https://raw.githubusercontent.com/dewhammer/openclaw-install/main/scripts/bootstrap.sh | bash
   ```

   When prompted, paste your Telegram token. Save the gateway token the script prints.

3. Open the Control UI at `http://<your-ip>:18789` and paste the gateway token in Settings.

**Note:** This repo must be **public** so the bootstrap can download it without a password. If you use a fork, make the repo public or clients will need to clone with a [Personal Access Token](https://github.com/settings/tokens).

Full steps: [docs/CLIENT-SETUP.md](docs/CLIENT-SETUP.md).

## Product variants

You can ship different “products” (preconfigured state + workspace) so clients choose a variant:

```bash
./install.sh --product default
./install.sh --product sales-assistant
```

Each product lives under `products/<name>/` with either:

- `state-template/` — directory copied into the client’s state dir (minimal config + workspace), or  
- `state.tgz` — tarball of a prepared state (e.g. built with `products/default/build-state-tgz.sh`).

Add new products by adding a `products/<name>/` directory and optionally a `state.tgz` from your prepared OpenClaw state.

## Layout

- `install.sh` — entrypoint: Docker check, prompts (Telegram token, optional Mission Control), `.env` creation, state unpack, `docker compose up -d`.
- `compose.yml` — OpenClaw Gateway + CLI (for one-off commands like `channels add`).
- `.env.example` — template; installer writes `.env` from it.
- `products/` — one dir per product (`default`, etc.) with `state-template/` or `state.tgz`.
- `docs/CLIENT-SETUP.md` — client-facing setup (Botfather, one command, URLs, restart, backups).

## Developer: preparing a product

1. Run OpenClaw locally, configure agents/channels/workspace as you want.
2. Build a state tarball: `products/default/build-state-tgz.sh ~/.openclaw` (or for another product, copy the script and run from that product dir).
3. Place `state.tgz` in the product dir (and add `products/<name>/state.tgz` to `.gitignore` if it contains secrets; or ship a sanitized template only).
4. Tag a release so clients can install a specific version: `git tag v1.0 && git push --tags`.

## License

Same as OpenClaw / your choice.
