# Default product

This is the default OpenClaw plug-and-play product. It includes:

- Minimal gateway config (bind: lan, mode: local)
- Empty workspace

The installer unpacks `state-template/` into the client's `OPENCLAW_STATE_DIR` and then adds the Telegram channel using the token provided at install time.

To build a custom product tarball from a prepared state dir:

```bash
tar -czf state.tgz -C /path/to/prepared/.openclaw .
```

Place `state.tgz` here and use `./install.sh --product default` (or the default product is used automatically).
