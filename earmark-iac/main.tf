# ============================================================
# Earmark on Fly.io — Terraform
#
# Provisions: app · shared IPv4 + IPv6 · persistent volume ·
# one machine running the Earmark image · optional custom-domain cert.
#
# The app image must exist in a registry the machine can pull from.
# Simplest flow (uses Fly's own registry):
#   fly auth docker
#   docker build -t registry.fly.io/<app_name>:v1 ../earmark-app
#   docker push registry.fly.io/<app_name>:v1
# then set var.image = "registry.fly.io/<app_name>:v1"
# ============================================================

resource "fly_app" "earmark" {
  name = var.app_name
  org  = var.org
}

# Anycast IPs so the app is reachable at <app_name>.fly.dev
resource "fly_ip" "v4" {
  app  = fly_app.earmark.name
  type = "v4"
}

resource "fly_ip" "v6" {
  app  = fly_app.earmark.name
  type = "v6"
}

# Persistent volume backing /data (SQLite workspace store).
# NOTE: volumes pin a machine to one region/host. Snapshots are taken
# daily by Fly; for production consider Fly Postgres / LiteFS instead.
resource "fly_volume" "data" {
  app    = fly_app.earmark.name
  name   = var.volume_name
  region = var.primary_region
  size   = var.volume_size_gb
}

resource "fly_machine" "web" {
  app    = fly_app.earmark.name
  region = var.primary_region
  name   = "${var.app_name}-web"
  image  = var.image

  cputype  = "shared"
  cpus     = var.cpus
  memorymb = var.memory_mb

  env = {
    DATA_DIR = "/data"
  }

  mounts = [
    {
      volume = fly_volume.data.id
      path   = "/data"
    }
  ]

  services = [
    {
      protocol      = "tcp"
      internal_port = 8080
      ports = [
        {
          port     = 80
          handlers = ["http"]
        },
        {
          port     = 443
          handlers = ["tls", "http"]
        }
      ]
    }
  ]

  depends_on = [fly_ip.v4, fly_ip.v6]
}

# Optional: custom domain certificate. After apply, create the DNS
# records shown in `terraform output cert_validation` at your DNS host.
resource "fly_cert" "custom" {
  count    = var.custom_domain == "" ? 0 : 1
  app      = fly_app.earmark.name
  hostname = var.custom_domain
}
