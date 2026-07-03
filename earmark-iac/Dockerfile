# ---------- Earmark IaC image: Terraform + Fly configuration ----------
# Runs terraform against the baked-in configuration. State and variables
# are mounted at runtime so the image stays stateless and secret-free.
FROM hashicorp/terraform:1.9

WORKDIR /iac
COPY versions.tf variables.tf main.tf outputs.tf ./

# Pre-warm the provider into the image so plan/apply work offline-ish
# and CI runs are fast. (Requires network at build time.)
RUN terraform init -backend=false -input=false && \
    rm -rf .terraform.lock.hcl.bak 2>/dev/null || true

# Runtime contract:
#   -e FLY_API_TOKEN=...                      (auth)
#   -v $(pwd)/state:/iac/state                (local state dir)
#   -v $(pwd)/terraform.tfvars:/iac/terraform.tfvars:ro
# Entry: any terraform subcommand (default shows help)
ENTRYPOINT ["terraform"]
CMD ["-help"]
