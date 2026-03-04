# VPS walkthrough: install OpenClaw step by step

Follow these in order.

---

## Part A: Get the installer onto the VPS (one command, no login)

On the **VPS**, run this single line. It downloads and runs the installer — **no git and no GitHub username/password**:

```bash
curl -fsSL https://raw.githubusercontent.com/dewhammer/openclaw-install/main/scripts/bootstrap.sh | bash
```

**Requirement:** The GitHub repo must be **public**. If it's private, GitHub will not allow the download without a token.

Optional: use a different product (e.g. `sales-assistant`):

```bash
curl -fsSL https://raw.githubusercontent.com/dewhammer/openclaw-install/main/scripts/bootstrap.sh | bash -s -- --product sales-assistant
```

---

### Alternative: clone with git (needs repo public or a token)

If you prefer to clone first (e.g. to inspect files): **Public repo** = no login. **Private repo** = use a [Personal Access Token](https://github.com/settings/tokens) as the password (GitHub no longer accepts account passwords).

### Option 1: Copy from your Mac (no GitHub)

From your **Mac** (in a terminal), copy the whole `openclaw` folder to the VPS:

```bash
cd /Users/fidelis
scp -i /Users/fidelis/billion/.ssh-keys/cursor_hostinger -o StrictHostKeyChecking=no -r openclaw root@45.93.137.107:~/
```

Then on the **VPS** you’ll have `~/openclaw` with `install.sh`, `compose.yml`, etc.

### Option 2: Use GitHub (after you push the repo)

1. On your **Mac**: create a new repo on GitHub (e.g. `your-username/openclaw-install`), then:

   ```bash
   cd /Users/fidelis/openclaw
   git init
   git add .
   git commit -m "Initial plug-and-play installer"
   git remote add origin https://github.com/YOUR-USERNAME/openclaw-install.git
   git branch -M main
   git push -u origin main
   ```

2. On the **VPS**: clone that repo:

   ```bash
   ssh -i /Users/fidelis/billion/.ssh-keys/cursor_hostinger -o StrictHostKeyChecking=no root@45.93.137.107
   git clone https://github.com/YOUR-USERNAME/openclaw-install.git
   cd openclaw-install
   ```

Use **Option 1** if you haven’t pushed to GitHub yet.

---

## Part B: Get the Telegram bot token

1. On your phone or computer, open **Telegram** (install it if needed: https://telegram.org).
2. Search for **@BotFather** (official Telegram bot).
3. Start a chat and send: **`/newbot`**.
4. BotFather will ask:
   - **Name** — e.g. “My OpenClaw Bot” (any name users see).
   - **Username** — must end in `bot`, e.g. `my_openclaw_bot`.
5. When you’re done, BotFather sends a message with a **token** that looks like:
   - `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`
6. **Copy that token** and keep it somewhere safe (you’ll paste it once in the installer).

You don’t need to do anything else in Telegram with that token; the installer will use it to connect OpenClaw to your bot.

---

## Part C: On the VPS — run the installer and use the token

1. **SSH into the VPS** (from your Mac):

   ```bash
   ssh -i /Users/fidelis/billion/.ssh-keys/cursor_hostinger -o StrictHostKeyChecking=no root@45.93.137.107
   ```

2. **Run the one-command installer** (no need to cd anywhere):

   ```bash
   curl -fsSL https://raw.githubusercontent.com/dewhammer/openclaw-install/main/scripts/bootstrap.sh | bash
   ```

3. When it asks **“Telegram bot token”**, paste the token you got from BotFather and press Enter.

4. It will then show a **gateway token** (save it), ask whether to enable Mission Control (press Enter for no), create `.env`, set up the state dir, add the Telegram channel, and start the gateway.

5. When it finishes, it will print something like:
   - Control UI: `http://127.0.0.1:18789`
   - Gateway token: `...`
   - On the VPS you’d open: **`http://45.93.137.107:18789`** (your VPS IP + port).

6. **In your browser** open `http://45.93.137.107:18789`, go to **Settings**, and paste the **gateway token** so the UI can talk to the gateway.

7. **In Telegram**, find your bot by its username and send it a message. OpenClaw should now be connected to that bot.

---

## Summary

| Step | Where | What you do |
|------|--------|-------------|
| 1 | VPS | Run the one-liner (curl … \| bash) — no git, no GitHub login. |
| 2 | Telegram | Message @BotFather → `/newbot` → get **token**. |
| 3 | VPS | When the script asks, paste **token** → save the **gateway token**. |
| 4 | Browser | Open `http://<VPS-IP>:18789` → Settings → paste **gateway token**. |
| 5 | Telegram | Open your bot and chat; OpenClaw is connected. |

If anything fails (e.g. “channels add” or port not reachable), see [CLIENT-SETUP.md](CLIENT-SETUP.md) for troubleshooting and the manual “add Telegram” command.
