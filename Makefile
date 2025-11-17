.PHONY: help install test test-unit test-integration test-validation lint format clean validate-all deploy-all teardown-all cost-estimate docs check-deps

# Default target
.DEFAULT_GOAL := help

# Color output
BOLD := $(shell tput bold 2>/dev/null)
GREEN := $(shell tput setaf 2 2>/dev/null)
YELLOW := $(shell tput setaf 3 2>/dev/null)
RED := $(shell tput setaf 1 2>/dev/null)
RESET := $(shell tput sgr0 2>/dev/null)

# Variables
SCENARIOS := iam-user-risk dspm-data-generator linux-misconfig-web windows-vuln-iis docker-container-host
TF_VERSION := 1.5.0
OWNER ?= $(shell whoami)
REGION ?= us-east-1

##@ Help

help: ## Display this help message
	@echo "$(BOLD)CloudVuln - Makefile Commands$(RESET)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make $(GREEN)<target>$(RESET)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BOLD)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Installation & Setup

install: check-deps ## Install all dependencies (Terraform, AWS CLI, bats)
	@echo "$(GREEN)Installing dependencies...$(RESET)"
	@command -v terraform >/dev/null 2>&1 || (echo "$(YELLOW)Installing Terraform $(TF_VERSION)...$(RESET)" && curl -fsSL https://releases.hashicorp.com/terraform/$(TF_VERSION)/terraform_$(TF_VERSION)_linux_amd64.zip -o /tmp/terraform.zip && unzip -q /tmp/terraform.zip -d /tmp && sudo mv /tmp/terraform /usr/local/bin/)
	@command -v aws >/dev/null 2>&1 || (echo "$(YELLOW)Please install AWS CLI: https://aws.amazon.com/cli/$(RESET)")
	@command -v bats >/dev/null 2>&1 || (echo "$(YELLOW)Installing bats...$(RESET)" && sudo apt-get update && sudo apt-get install -y bats)
	@command -v jq >/dev/null 2>&1 || (echo "$(YELLOW)Installing jq...$(RESET)" && sudo apt-get install -y jq)
	@echo "$(GREEN)✅ Dependencies installed$(RESET)"

check-deps: ## Check if required dependencies are installed
	@echo "$(BOLD)Checking dependencies...$(RESET)"
	@command -v terraform >/dev/null 2>&1 && echo "$(GREEN)✅ Terraform:$(RESET) $$(terraform version | head -n1)" || echo "$(RED)❌ Terraform not found$(RESET)"
	@command -v aws >/dev/null 2>&1 && echo "$(GREEN)✅ AWS CLI:$(RESET) $$(aws --version)" || echo "$(RED)❌ AWS CLI not found$(RESET)"
	@command -v bats >/dev/null 2>&1 && echo "$(GREEN)✅ Bats:$(RESET) $$(bats --version)" || echo "$(YELLOW)⚠️  Bats not found (needed for unit tests)$(RESET)"
	@command -v jq >/dev/null 2>&1 && echo "$(GREEN)✅ jq:$(RESET) $$(jq --version)" || echo "$(YELLOW)⚠️  jq not found$(RESET)"
	@command -v shellcheck >/dev/null 2>&1 && echo "$(GREEN)✅ shellcheck:$(RESET) $$(shellcheck --version | head -n2 | tail -n1)" || echo "$(YELLOW)⚠️  shellcheck not found (recommended for linting)$(RESET)"

setup: ## Setup CloudVuln environment and make scripts executable
	@echo "$(GREEN)Setting up CloudVuln...$(RESET)"
	@find . -name "*.sh" -type f -exec chmod +x {} \;
	@mkdir -p logs
	@mkdir -p tests/logs
	@echo "$(GREEN)✅ Setup complete$(RESET)"

##@ Testing

test: test-unit test-integration test-validation ## Run all tests
	@echo "$(GREEN)✅ All tests completed$(RESET)"

test-unit: ## Run unit tests with bats
	@echo "$(BOLD)Running unit tests...$(RESET)"
	@if command -v bats >/dev/null 2>&1; then \
		if [ -d tests/unit ]; then \
			bats tests/unit/ -t; \
		else \
			echo "$(YELLOW)⚠️  No unit tests found$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ Bats not installed. Run: make install$(RESET)"; \
		exit 1; \
	fi

test-integration: ## Run integration tests (Terraform validation)
	@echo "$(BOLD)Running integration tests...$(RESET)"
	@if [ -x tests/integration/terraform_syntax_test.sh ]; then \
		./tests/integration/terraform_syntax_test.sh; \
	else \
		echo "$(RED)❌ Integration test script not found or not executable$(RESET)"; \
		exit 1; \
	fi

test-validation: ## Run validation tests (requires deployed infrastructure)
	@echo "$(BOLD)Running validation tests...$(RESET)"
	@echo "$(YELLOW)⚠️  These tests require deployed infrastructure$(RESET)"
	@if [ -x tests/validation/validate_iam_risks.sh ]; then \
		./tests/validation/validate_iam_risks.sh || true; \
	fi
	@if [ -x tests/validation/validate_cspm.sh ]; then \
		./tests/validation/validate_cspm.sh || true; \
	fi

##@ Linting & Formatting

lint: ## Lint all bash scripts with shellcheck
	@echo "$(BOLD)Linting bash scripts...$(RESET)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name "*.sh" -type f -exec shellcheck -x {} + && echo "$(GREEN)✅ All scripts passed shellcheck$(RESET)"; \
	else \
		echo "$(YELLOW)⚠️  shellcheck not installed$(RESET)"; \
		echo "Install: sudo apt-get install shellcheck"; \
	fi

format: ## Format all Terraform files
	@echo "$(BOLD)Formatting Terraform files...$(RESET)"
	@for scenario in $(SCENARIOS); do \
		echo "Formatting $$scenario..."; \
		terraform -chdir=$$scenario fmt -recursive; \
	done
	@echo "$(GREEN)✅ Formatting complete$(RESET)"

##@ Validation

validate-all: ## Validate all Terraform configurations
	@echo "$(BOLD)Validating all scenarios...$(RESET)"
	@for scenario in $(SCENARIOS); do \
		echo "$(YELLOW)Validating $$scenario...$(RESET)"; \
		cd $$scenario && terraform init -backend=false >/dev/null && terraform validate && cd ..; \
	done
	@echo "$(GREEN)✅ All scenarios validated$(RESET)"

validate-%: ## Validate specific scenario (e.g., make validate-iam-user-risk)
	@scenario=$$(echo $* | tr '-' '-'); \
	echo "$(BOLD)Validating $$scenario...$(RESET)"; \
	cd $$scenario && terraform init -backend=false && terraform validate

##@ Deployment

deploy-%: ## Deploy specific scenario (e.g., make deploy-iam-user-risk)
	@scenario=$*; \
	echo "$(BOLD)Deploying $$scenario...$(RESET)"; \
	export TF_VAR_owner=$(OWNER) TF_VAR_region=$(REGION); \
	./menu.sh --run $$scenario deploy

teardown-%: ## Teardown specific scenario (e.g., make teardown-iam-user-risk)
	@scenario=$*; \
	echo "$(BOLD)Tearing down $$scenario...$(RESET)"; \
	./menu.sh --run $$scenario teardown

plan-%: ## Show Terraform plan for specific scenario
	@scenario=$*; \
	echo "$(BOLD)Planning $$scenario...$(RESET)"; \
	export TF_VAR_owner=$(OWNER) TF_VAR_region=$(REGION); \
	cd $$scenario && terraform init -backend=false && terraform plan

deploy-all: ## Deploy all scenarios (WARNING: expensive!)
	@echo "$(BOLD)$(RED)⚠️  WARNING: This will deploy ALL scenarios!$(RESET)"
	@echo "$(YELLOW)This may incur significant AWS costs.$(RESET)"
	@read -p "Are you sure? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	@for scenario in $(SCENARIOS); do \
		echo "$(BOLD)Deploying $$scenario...$(RESET)"; \
		export TF_VAR_owner=$(OWNER) TF_VAR_region=$(REGION); \
		./menu.sh --run $$scenario deploy || exit 1; \
	done

teardown-all: ## Teardown all scenarios
	@echo "$(BOLD)Tearing down all scenarios...$(RESET)"
	@./cleanup-all.sh

##@ Cost Management

cost-estimate: ## Estimate infrastructure costs
	@echo "$(BOLD)Estimating costs for all scenarios...$(RESET)"
	@if [ -x tools/cost-estimate.sh ]; then \
		./tools/cost-estimate.sh; \
	else \
		echo "$(YELLOW)⚠️  Cost estimation tool not found$(RESET)"; \
		echo "Manual cost estimation:"; \
		echo "  - IAM User: $$0.00/month"; \
		echo "  - DSPM Data Generator: $$0.00/month (EC2 not deployed)"; \
		echo "  - Linux Web Server: ~$$15-25/month (t3.medium)"; \
		echo "  - Windows IIS: ~$$25-35/month (t3.medium + Windows)"; \
		echo "  - Docker Host: ~$$15-25/month (t3.medium)"; \
		echo "$(YELLOW)Total estimated: $$55-85/month for all scenarios$(RESET)"; \
	fi

##@ Documentation

docs: ## Generate and view documentation
	@echo "$(BOLD)CloudVuln Documentation$(RESET)"
	@echo ""
	@echo "Main documentation files:"
	@echo "  - $(GREEN)README.md$(RESET) - Main project overview"
	@echo "  - $(GREEN)docs/ARCHITECTURE.md$(RESET) - Architecture and design"
	@echo "  - $(GREEN)docs/QUICKSTART.md$(RESET) - Quick start guide"
	@echo "  - $(GREEN)tests/README.md$(RESET) - Testing documentation"
	@echo ""
	@echo "Scenario documentation:"
	@for scenario in $(SCENARIOS); do \
		echo "  - $(GREEN)$$scenario/README.md$(RESET)"; \
	done

docs-serve: ## Serve documentation locally (requires mdbook or similar)
	@echo "$(YELLOW)Documentation serving not yet configured$(RESET)"
	@echo "View documentation files directly or use 'make docs' for file list"

##@ Cleanup

clean: ## Clean up temporary files and Terraform state
	@echo "$(BOLD)Cleaning up temporary files...$(RESET)"
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "terraform.tfstate*" -type f -delete 2>/dev/null || true
	@find . -name ".terraform.lock.hcl" -type f -delete 2>/dev/null || true
	@rm -rf logs/*.log 2>/dev/null || true
	@rm -rf tests/logs/*.log 2>/dev/null || true
	@echo "$(GREEN)✅ Cleanup complete$(RESET)"

clean-all: clean teardown-all ## Clean everything (teardown + clean files)
	@echo "$(GREEN)✅ Complete cleanup finished$(RESET)"

##@ Utilities

info: ## Display CloudVuln information
	@echo "$(BOLD)CloudVuln - Cloud Security Simulation Lab$(RESET)"
	@echo ""
	@echo "$(BOLD)Configuration:$(RESET)"
	@echo "  Owner:  $(GREEN)$(OWNER)$(RESET)"
	@echo "  Region: $(GREEN)$(REGION)$(RESET)"
	@echo ""
	@echo "$(BOLD)Available Scenarios:$(RESET)"
	@for scenario in $(SCENARIOS); do \
		echo "  - $$scenario"; \
	done
	@echo ""
	@echo "$(BOLD)Quick Commands:$(RESET)"
	@echo "  make help           - Show all commands"
	@echo "  make check-deps     - Check dependencies"
	@echo "  make test           - Run all tests"
	@echo "  make deploy-<name>  - Deploy a scenario"
	@echo "  make teardown-<name> - Teardown a scenario"

menu: ## Launch interactive TUI menu
	@./menu.sh

status: ## Show deployment status for all scenarios
	@echo "$(BOLD)Deployment Status$(RESET)"
	@echo ""
	@for scenario in $(SCENARIOS); do \
		if [ -f "$$scenario/terraform.tfstate" ]; then \
			resources=$$(grep -c '"mode":' "$$scenario/terraform.tfstate" 2>/dev/null || echo "0"); \
			if [ "$$resources" -gt "0" ]; then \
				echo "$(GREEN)✅ $$scenario$(RESET) - $$resources resources"; \
			else \
				echo "$(YELLOW)⚠️  $$scenario$(RESET) - No resources"; \
			fi; \
		else \
			echo "$(RED)❌ $$scenario$(RESET) - Not deployed"; \
		fi; \
	done

##@ Development

pre-commit: lint test-unit validate-all ## Run pre-commit checks
	@echo "$(GREEN)✅ Pre-commit checks passed$(RESET)"

ci: lint test-unit test-integration validate-all ## Run CI pipeline locally
	@echo "$(GREEN)✅ CI pipeline completed successfully$(RESET)"
