# Earmark — IaC container (Terraform → Fly.io)

Containerized Terraform that provisions everything Earmark needs on
Fly.io: the app, anycast IPv4/IPv6, a persistent volume, one machine
running your pushed image, and (optionally) a custom-domain certificate.

## Provider status — read this
Fly.io **dropped its first-party Terraform provider**; this config pins
the last stable release (`fly-apps/fly 0.0.23`, archived). The most
active community fork is `andrewbaxter/fly` — switching is a two-line
change in `versions.tf`. Re-evaluate the pin before production, or ask
us to generate a Machines-API/`flyctl`-based pipeline instead.

## Workflow
```bash
# 0) one-time
cp terraform.tfvars.example terraform.tfvars   # edit app_name + image
export FLY_API_TOKEN=$(fly tokens create deploy -x 999999h)

# 1) build the image ONCE (bakes providers in)
make build

# 2) push the app image the machine will run (from ../earmark-app)
fly auth docker
docker build -t registry.fly.io/<app-name>:v1 ../earmark-app
docker push registry.fly.io/<app-name>:v1

# 3) provision
make init
make plan
make apply
make output          # → app_url, IPs, machine/volume ids
```

State lives in `./state/terraform.tfstate` on your host (mounted into
the container). **Do not commit it.** For teams, configure a remote
backend in `versions.tf` and drop the `-state` flags from the Makefile.

## Custom domain
Set `custom_domain` in `terraform.tfvars`, re-apply, then create the DNS
records printed by `make output` (`cert_validation`) plus an
A/AAAA or CNAME to the app.

## What's intentionally out of scope
Image building/pushing (app package's job), secrets management
(`fly secrets` or your vault), and multi-region (volumes pin a machine
to one region — scale out by adding machines+volumes per region, or move
state to Postgres/LiteFS first).
