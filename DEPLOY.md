# Deploying Earmark to Fly.io — test-run runbook

Everything below runs on **your machine** (Fly needs your account + token).
Total time: ~10 minutes. Cost: one `shared-cpu-1x/512MB` machine + 1 GB
volume — pennies for a test, and `fly apps destroy` removes everything.

## 0. Prerequisites (one-time)
```bash
# install flyctl
curl -L https://fly.io/install.sh | sh        # macOS/Linux
# or: pwsh -Command "iwr https://fly.io/install.ps1 -useb | iex"   (Windows)

fly auth login                                # opens browser
```

## 1. Deploy (from this package's directory)
```bash

# creates the app from fly.toml — pick a globally-unique name when prompted,
# accept the suggested region (or choose one near you), and say NO to
# Postgres/Redis (not needed yet)
fly launch --copy-config --no-deploy

# the persistent volume the workspace snapshot lives on
# (name must stay `earmark_data` — it matches [mounts] in fly.toml)
fly volumes create earmark_data --size 1

# build remotely on Fly's builders (no local Docker needed) and deploy
fly deploy
```

> `fly launch` rewrites the `app = "..."` line in fly.toml with your chosen
> name — commit that change.

## 2. Verify
```bash
./scripts/smoke.sh https://<your-app>.fly.dev
```
Expect **12 PASS**, ending "SMOKE TEST PASS". The script writes a test
snapshot and deletes it, so run it **before** you start real work.

## 3. Feature-test checklist (in the browser)
Open `https://<your-app>.fly.dev` and walk the product:

1. **Sign in** with a work email → greeting shows your name.
2. **Phrases** → *Load starter library* → toggle one off, add a custom
   phrase with test sentences.
3. **Admin** → drop a file (any file — pipeline is simulated) → *Scan for
   new calls* → watch the progress pill.
4. **Queue** → bell badge + Attention card show new flags → *Review now*
   → open a call → play, click-to-seek, confirm one flag with a note.
5. **Theme** toggle → Noir.
6. **The real test — persistence:** hard-refresh (Cmd/Ctrl+Shift+R),
   then open the same URL in a private window. You should land signed-in,
   Noir, with every call/flag/phrase/decision intact — served from SQLite
   on the volume, not the browser.
7. **Restart survival:** `fly machine restart` then refresh — state holds.

## 4. Watching it run
```bash
fly logs               # live server logs (uvicorn access + errors)
fly status             # machine + health-check state
fly ssh console        # shell inside the machine
sqlite3 /data/earmark.db 'select id, bytes, datetime(updated_at, "unixepoch") from workspace;'
```

## 5. Teardown / reset
```bash
fly apps destroy <your-app>          # removes machine, volume, IPs
# or just wipe data, keep the deployment:
curl -X DELETE https://<your-app>.fly.dev/api/workspace
```

## Notes for this test deployment
- **It's a shared, unauthenticated workspace** — anyone with the URL can
  read/write it. Fine for feature testing; do not put real call data in it.
  Quick lock while testing: `fly apps update --auto-stop` + share the URL
  narrowly, or ask us to add a bearer-token gate (small change).
- `auto_stop_machines = "stop"` means the first request after idle takes
  ~1s to cold-start — that's normal.
- Terraform path: once you're happy, the `earmark-iac` package recreates
  this exact setup reproducibly (`make init/plan/apply`) — use it for the
  "real" environment and keep this flyctl app as a scratch/test space.
