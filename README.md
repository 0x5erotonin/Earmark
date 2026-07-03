# Earmark

Call review & flag intelligence.

The **app lives at the repo root** (Dockerfile + `fly.toml` here — required
for Fly.io's dashboard/GitHub launch flow to detect it):
`server/` FastAPI backend · `static/` UI · `tests/` · `scripts/smoke.sh`.

`earmark-iac/` — containerized Terraform for reproducible provisioning.

Deploys: push to `main` → `.github/workflows/fly-deploy.yml` runs tests,
bootstraps app+volume on first run, deploys. Setup steps in `DEPLOY.md`.
