SHELL := /bin/bash
.DEFAULT_GOAL := help

TF      ?= terraform
TF_DIRS := terraform/modules/network terraform/modules/aks terraform/modules/platform-identities \
           terraform/modules/tenant terraform/envs/prod terraform/bootstrap/github-oidc
TF_TEST := terraform/modules/tenant terraform/envs/prod

.PHONY: help terraform tftest tflint tenant tenants schemas render manifests policies alerts lint shell security check clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

terraform: ## fmt-check + init + validate every Terraform directory
	$(TF) fmt -check -recursive
	@set -e; for d in $(TF_DIRS); do \
		echo "==> $$d"; \
		$(TF) -chdir=$$d init -backend=false -input=false >/dev/null; \
		$(TF) -chdir=$$d validate; \
	done

tftest: ## terraform test with mocked providers (no Azure credentials needed)
	@set -e; for d in $(TF_TEST); do \
		echo "==> $$d"; \
		$(TF) -chdir=$$d init -backend=false -input=false >/dev/null; \
		$(TF) -chdir=$$d test; \
	done

tflint: ## tflint with the azurerm ruleset
	tflint --init --config=$(CURDIR)/.tflint.hcl
	@set -e; for d in $(TF_DIRS); do \
		echo "==> $$d"; \
		tflint --chdir=$$d --config=$(CURDIR)/.tflint.hcl; \
	done

tenant: ## Scaffold a tenant: make tenant NAME=returns GROUP=<entra-group-id> COST=CC-1234 HOSTS="returns.example.co.uk"
	./hack/new-tenant.sh "$(NAME)" "$(GROUP)" "$(COST)" $(HOSTS)

tenants: ## Cross-checks between tenant.yaml files, Flux variables and Terraform
	./hack/check-tenants.sh

schemas: ## Build JSON schemas from the pinned CRDs (hack/crds.txt)
	./hack/schemas.sh

render: ## helm template the tenant chart per tenant and every platform HelmRelease
	helm lint charts/tenant --values gitops/tenants/checkout/tenant.yaml \
		--set azure.tenantId=t,azure.workloadClientId=c
	./hack/render.sh
	./hack/render-platform.sh

manifests: schemas render ## kubeconform every manifest, rendered chart and tenant
	./hack/validate.sh

policies: ## gator verify the Gatekeeper policies
	./hack/test-policies.sh

alerts: ## promtool check + unit tests for the platform alert rules
	./hack/test-alerts.sh

lint: ## yamllint
	yamllint -s .

shell: ## shellcheck the scripts
	shellcheck hack/*.sh

check: terraform tftest tenants manifests policies alerts lint shell ## Everything CI runs (except tflint and trivy)

clean: ## Remove generated files and Terraform caches
	rm -rf .schemas .rendered
	find terraform -type d -name .terraform -prune -exec rm -rf {} +

security: ## trivy config scan (HIGH/CRITICAL)
	trivy config --severity HIGH,CRITICAL --exit-code 1 \
		--skip-dirs '**/.terraform' --skip-dirs .rendered --skip-dirs .schemas \
		--skip-dirs gitops/policies/tests .
