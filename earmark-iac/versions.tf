terraform {
  required_version = ">= 1.5"

  required_providers {
    # ------------------------------------------------------------------
    # PROVIDER MAINTENANCE NOTE (important):
    # Fly.io no longer maintains a first-party Terraform provider. The
    # last official releases live at fly-apps/fly (archived); the most
    # active community fork is andrewbaxter/fly. Both drive the same
    # Fly APIs. This config pins the archived-but-stable official
    # provider; to switch to the community fork, change source/version
    # below — the resource schemas are compatible for what we use here.
    # Re-evaluate this pin before production use.
    # ------------------------------------------------------------------
    fly = {
      source  = "fly-apps/fly"
      version = "0.0.23"
      # community fork alternative:
      # source  = "andrewbaxter/fly"
      # version = ">= 0.1.0"
    }
  }

  # State: local by default (mount ./state into the container — see
  # Makefile). For teams, configure a remote backend instead, e.g.:
  # backend "s3" { ... }   or   Terraform Cloud.
}

provider "fly" {
  # Auth: export FLY_API_TOKEN (from `fly tokens create deploy` or
  # `fly auth token`). Older provider versions tunneled through
  # `fly machines api-proxy`; 0.0.23 talks to the public Machines API.
}
