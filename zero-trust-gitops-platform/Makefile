SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help
.SHELLFLAGS := -eu -o pipefail -c

# --- versioning (Phase 1) ---------------------------------------------------

APP_DIR := apps/demo-api
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
BUILD_DATE ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS := -s -w -X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.buildDate=$(BUILD_DATE)
IMAGE ?= demo-api:$(COMMIT)

# --- ground truth (Phase 0) -------------------------------------------------

.PHONY: help
help: ## Show this help
	@echo "zero-trust-gitops-platform — available targets:"
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

.PHONY: tools
tools: ## Install pinned CLI tools (mise if present, otherwise go install fallback)
	@if command -v mise >/dev/null 2>&1; then \
		mise install; \
	else \
		echo "mise not found; installing what's go-installable per docs/versions.md"; \
		GOBIN=$$(go env GOPATH)/bin go install github.com/kyverno/kyverno/cmd/cli/kubectl-kyverno@v1.19.1; \
	fi

.PHONY: lint
lint: ## Run pre-commit (fmt, lint, gitleaks, secret guard) across this project
	pre-commit run --all-files -c .pre-commit-config.yaml

.PHONY: lint-fast
lint-fast: ## Same as lint, but only against files changed from origin/main (used by the Stop hook)
	pre-commit run -c .pre-commit-config.yaml --from-ref origin/main --to-ref HEAD || true

.PHONY: build
build: ## Build the demo-api Go binary into apps/demo-api/bin/
	cd $(APP_DIR) && CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/demo-api .

.PHONY: test
test: ## Run demo-api's unit tests
	cd $(APP_DIR) && go vet ./... && go test ./... -v

.PHONY: image
image: ## Build the demo-api container image (needs a reachable Docker daemon)
	docker build \
		--build-arg VERSION=$(VERSION) --build-arg COMMIT=$(COMMIT) --build-arg BUILD_DATE=$(BUILD_DATE) \
		-t $(IMAGE) -f $(APP_DIR)/Dockerfile $(APP_DIR)

TF_DIR := infra/terraform

.PHONY: tf-fmt
tf-fmt: ## Check every .tf file is terraform fmt-clean
	terraform fmt -check -recursive $(TF_DIR)

.PHONY: tf-validate
tf-validate: ## terraform init -backend=false + validate, every module and env
	@for d in $(TF_DIR)/modules/*/ $(TF_DIR)/envs/dev; do \
		echo "== $$d =="; \
		(cd "$$d" && terraform init -input=false -backend=false >/dev/null && terraform validate) || exit 1; \
	done

.PHONY: tf-test
tf-test: ## terraform test (native .tftest.hcl, mocked provider — no AWS needed)
	cd $(TF_DIR)/tests && terraform init -input=false -backend=false >/dev/null && terraform test

.PHONY: policy-test
policy-test: ## Plan every conftest pass/fail fixture and assert the expected verdict
	bash $(TF_DIR)/policy/run-fixture-tests.sh

.PHONY: iac-scan
iac-scan: ## checkov (static) + tflint (core rules; no AWS-ruleset plugin — see docs/fidelity.md) across infra/terraform
	checkov -d $(TF_DIR) --config-file $(TF_DIR)/.checkov.yaml
	@for d in $(TF_DIR)/modules/*/ $(TF_DIR)/envs/dev; do (cd "$$d" && tflint) || exit 1; done

.PHONY: kyverno-test
kyverno-test: ## kyverno test policies/ + the generate-rule exclusion checks
	kyverno test policies/
	bash policies/tests/run-generate-exclusion-tests.sh

.PHONY: policy-catalog
policy-catalog: ## Regenerate docs/policy-catalog.md from policies/ annotations
	bash tools/gen-policy-catalog.sh
	@git diff --quiet docs/policy-catalog.md 2>/dev/null && echo "docs/policy-catalog.md is up to date" || { echo "docs/policy-catalog.md is out of date — commit the regenerated file"; exit 1; }

.PHONY: diagrams
diagrams: ## Render docs/diagrams/src/*.mmd to SVG (mermaid-cli)
	bash tools/render-diagrams.sh

.PHONY: docs
docs: ## Build the mkdocs-material site (fails on any warning, per BRIEF's own gate)
	mkdocs build --strict

IMAGE_REF ?= ghcr.io/beniaxcode/yahia-benabbou-portfolio/demo-api
CERT_IDENTITY_REGEXP := ^https://github.com/beniaXcode/yahia-benabbou-portfolio/.github/workflows/build-sign-attest.yml@refs/heads/main$$
CERT_OIDC_ISSUER := https://token.actions.githubusercontent.com

.PHONY: verify-chain
verify-chain: ## cosign verify + verify-attestation + Rekor lookup for a given DIGEST (make verify-chain DIGEST=sha256:...)
	@if [ -z "$(DIGEST)" ]; then echo "usage: make verify-chain DIGEST=sha256:..."; exit 1; fi
	cosign verify "$(IMAGE_REF)@$(DIGEST)" \
		--certificate-identity-regexp "$(CERT_IDENTITY_REGEXP)" \
		--certificate-oidc-issuer "$(CERT_OIDC_ISSUER)"
	cosign verify-attestation "$(IMAGE_REF)@$(DIGEST)" \
		--type https://slsa.dev/provenance/v1 \
		--certificate-identity-regexp "$(CERT_IDENTITY_REGEXP)" \
		--certificate-oidc-issuer "$(CERT_OIDC_ISSUER)"
	@echo "Rekor transparency log: search https://search.sigstore.dev for $(DIGEST) (exact query-parameter format not verified from this sandbox — see docs/fidelity.md)"

.PHONY: demo
demo: ## Bring up the full kind + Argo CD + Kyverno GitOps loop (needs Docker — see docs/fidelity.md)
	bash demo/up.sh

.PHONY: demo-attack
demo-attack: ## Run the six attack scenarios against the kind demo (needs `make demo` first)
	@fail=0; \
	for script in demo/attack/[0-9]*.sh; do \
		echo "=============================================================="; \
		echo "== $$script"; \
		echo "=============================================================="; \
		bash "$$script" || fail=1; \
	done; \
	exit $$fail

.PHONY: verify
verify: lint test kyverno-test policy-test iac-scan docs demo-attack ## Run every gate this repo claims passes, chained

.PHONY: clean
clean: ## Tear down the local kind cluster and remove generated artefacts
	bash demo/down.sh
