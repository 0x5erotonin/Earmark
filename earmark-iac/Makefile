# Earmark IaC — containerized Terraform workflow.
# Usage: make build && make init && make plan && make apply
IMAGE      ?= earmark-iac:latest
STATE_DIR  ?= $(PWD)/state
TFVARS     ?= $(PWD)/terraform.tfvars
RUN = docker run --rm -it \
  -e FLY_API_TOKEN \
  -v $(STATE_DIR):/iac/state \
  -v $(TFVARS):/iac/terraform.tfvars:ro \
  $(IMAGE)

build:
	docker build -t $(IMAGE) .

init:
	mkdir -p $(STATE_DIR)
	$(RUN) init -input=false -state=state/terraform.tfstate

plan:
	$(RUN) plan -input=false -state=state/terraform.tfstate

apply:
	$(RUN) apply -input=false -state=state/terraform.tfstate

destroy:
	$(RUN) destroy -state=state/terraform.tfstate

output:
	$(RUN) output -state=state/terraform.tfstate

fmt-check:
	docker run --rm -v $(PWD):/iac -w /iac $(IMAGE) fmt -check -diff

.PHONY: build init plan apply destroy output fmt-check
