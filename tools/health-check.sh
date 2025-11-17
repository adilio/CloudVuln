#!/usr/bin/env bash
# CloudVuln health check - verify environment and deployments
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

print_header() {
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${BLUE}  $1${RESET}"
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo
}

check_pass() {
  echo -e "  ${GREEN}✅ $1${RESET}"
}

check_warn() {
  echo -e "  ${YELLOW}⚠️  $1${RESET}"
}

check_fail() {
  echo -e "  ${RED}❌ $1${RESET}"
}

check_info() {
  echo -e "  ${BLUE}ℹ️  $1${RESET}"
}

print_header "CloudVuln Health Check"

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

# Check dependencies
print_header "Dependency Check"

if command -v terraform >/dev/null 2>&1; then
  version=$(terraform version | head -n1)
  check_pass "Terraform installed: $version"
  ((CHECKS_PASSED++))
else
  check_fail "Terraform not installed"
  check_info "Install: https://developer.hashicorp.com/terraform/downloads"
  ((CHECKS_FAILED++))
fi

if command -v aws >/dev/null 2>&1; then
  version=$(aws --version 2>&1)
  check_pass "AWS CLI installed: $version"
  ((CHECKS_PASSED++))
else
  check_fail "AWS CLI not installed"
  check_info "Install: https://aws.amazon.com/cli/"
  ((CHECKS_FAILED++))
fi

if command -v jq >/dev/null 2>&1; then
  version=$(jq --version)
  check_pass "jq installed: $version"
  ((CHECKS_PASSED++))
else
  check_warn "jq not installed (recommended)"
  check_info "Install: sudo apt-get install jq"
  ((CHECKS_WARNED++))
fi

if command -v shellcheck >/dev/null 2>&1; then
  version=$(shellcheck --version | grep version: | awk '{print $2}')
  check_pass "shellcheck installed: $version"
  ((CHECKS_PASSED++))
else
  check_warn "shellcheck not installed (recommended for development)"
  ((CHECKS_WARNED++))
fi

if command -v bats >/dev/null 2>&1; then
  version=$(bats --version)
  check_pass "bats installed: $version"
  ((CHECKS_PASSED++))
else
  check_warn "bats not installed (required for unit tests)"
  ((CHECKS_WARNED++))
fi

echo

# Check AWS credentials
print_header "AWS Configuration"

if aws sts get-caller-identity >/dev/null 2>&1; then
  identity=$(aws sts get-caller-identity)
  account=$(echo "$identity" | jq -r '.Account')
  arn=$(echo "$identity" | jq -r '.Arn')
  check_pass "AWS credentials configured"
  check_info "Account: $account"
  check_info "Identity: $arn"
  ((CHECKS_PASSED++))
else
  check_fail "AWS credentials not configured or invalid"
  check_info "Run: aws configure"
  ((CHECKS_FAILED++))
fi

if [ -n "${AWS_REGION:-}" ]; then
  check_pass "AWS_REGION set: $AWS_REGION"
  ((CHECKS_PASSED++))
elif [ -n "${TF_VAR_region:-}" ]; then
  check_pass "TF_VAR_region set: $TF_VAR_region"
  ((CHECKS_PASSED++))
else
  check_warn "No AWS region environment variable set"
  check_info "Default will be used (us-east-1)"
  ((CHECKS_WARNED++))
fi

echo

# Check repository structure
print_header "Repository Structure"

required_files=(
  "README.md"
  "menu.sh"
  "cleanup-all.sh"
  "common_vars.tf"
  "lib/checks.sh"
  "docs/ARCHITECTURE.md"
  "docs/QUICKSTART.md"
  "Makefile"
)

for file in "${required_files[@]}"; do
  if [ -f "$REPO_ROOT/$file" ]; then
    check_pass "$file present"
    ((CHECKS_PASSED++))
  else
    check_fail "$file missing"
    ((CHECKS_FAILED++))
  fi
done

echo

# Check scenarios
print_header "Scenario Validation"

scenarios=("iam-user-risk" "dspm-data-generator" "linux-misconfig-web" "windows-vuln-iis" "docker-container-host")

for scenario in "${scenarios[@]}"; do
  if [ -d "$REPO_ROOT/$scenario" ]; then
    check_info "Checking $scenario..."

    required_scenario_files=("main.tf" "vars.tf" "deploy.sh" "teardown.sh" "README.md")
    scenario_ok=true

    for file in "${required_scenario_files[@]}"; do
      if [ ! -f "$REPO_ROOT/$scenario/$file" ]; then
        check_fail "  Missing $file"
        scenario_ok=false
        ((CHECKS_FAILED++))
      fi
    done

    if [ ! -x "$REPO_ROOT/$scenario/deploy.sh" ]; then
      check_warn "  deploy.sh not executable"
      ((CHECKS_WARNED++))
    fi

    if [ ! -x "$REPO_ROOT/$scenario/teardown.sh" ]; then
      check_warn "  teardown.sh not executable"
      ((CHECKS_WARNED++))
    fi

    if [ "$scenario_ok" = true ]; then
      check_pass "$scenario structure valid"
      ((CHECKS_PASSED++))
    fi
  else
    check_fail "$scenario directory missing"
    ((CHECKS_FAILED++))
  fi
done

echo

# Check deployments
print_header "Deployment Status"

deployed_count=0
for scenario in "${scenarios[@]}"; do
  if [ -f "$REPO_ROOT/$scenario/terraform.tfstate" ]; then
    resources=$(grep -c '"mode":' "$REPO_ROOT/$scenario/terraform.tfstate" 2>/dev/null || echo "0")
    if [ "$resources" -gt "0" ]; then
      check_info "$scenario: $resources resources deployed"
      ((deployed_count++))
    else
      check_info "$scenario: No resources (tfstate exists but empty)"
    fi
  else
    check_info "$scenario: Not deployed"
  fi
done

if [ $deployed_count -eq 0 ]; then
  check_pass "No active deployments (no ongoing costs)"
else
  check_warn "$deployed_count scenario(s) currently deployed"
  check_info "Remember to teardown when finished testing"
fi

echo

# Check test infrastructure
print_header "Test Infrastructure"

if [ -d "$REPO_ROOT/tests" ]; then
  check_pass "Test directory exists"
  ((CHECKS_PASSED++))

  if [ -d "$REPO_ROOT/tests/unit" ]; then
    unit_tests=$(find "$REPO_ROOT/tests/unit" -name "*.bats" | wc -l)
    check_pass "Unit tests: $unit_tests test files"
    ((CHECKS_PASSED++))
  else
    check_warn "No unit tests directory"
    ((CHECKS_WARNED++))
  fi

  if [ -d "$REPO_ROOT/tests/integration" ]; then
    integration_tests=$(find "$REPO_ROOT/tests/integration" -name "*.sh" | wc -l)
    check_pass "Integration tests: $integration_tests test scripts"
    ((CHECKS_PASSED++))
  else
    check_warn "No integration tests directory"
    ((CHECKS_WARNED++))
  fi

  if [ -d "$REPO_ROOT/tests/validation" ]; then
    validation_tests=$(find "$REPO_ROOT/tests/validation" -name "*.sh" | wc -l)
    check_pass "Validation tests: $validation_tests test scripts"
    ((CHECKS_PASSED++))
  else
    check_warn "No validation tests directory"
    ((CHECKS_WARNED++))
  fi
else
  check_fail "Test directory missing"
  ((CHECKS_FAILED++))
fi

echo

# Check GitHub Actions
print_header "CI/CD Configuration"

if [ -d "$REPO_ROOT/.github/workflows" ]; then
  workflows=$(find "$REPO_ROOT/.github/workflows" -name "*.yml" -o -name "*.yaml" | wc -l)
  check_pass "GitHub Actions: $workflows workflow(s) configured"
  ((CHECKS_PASSED++))
else
  check_warn "No GitHub Actions workflows found"
  ((CHECKS_WARNED++))
fi

if [ -f "$REPO_ROOT/.pre-commit-config.yaml" ]; then
  check_pass "Pre-commit hooks configured"
  ((CHECKS_PASSED++))
else
  check_warn "No pre-commit hooks configured"
  ((CHECKS_WARNED++))
fi

echo

# Summary
print_header "Health Check Summary"

total_checks=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNED))

echo -e "${BOLD}Results:${RESET}"
echo -e "  ${GREEN}✅ Passed:  $CHECKS_PASSED${RESET}"
echo -e "  ${YELLOW}⚠️  Warnings: $CHECKS_WARNED${RESET}"
echo -e "  ${RED}❌ Failed:  $CHECKS_FAILED${RESET}"
echo -e "${BOLD}  Total:    $total_checks${RESET}"
echo

if [ $CHECKS_FAILED -gt 0 ]; then
  echo -e "${RED}${BOLD}❌ Health check failed!${RESET}"
  echo -e "${YELLOW}Please address the failed checks above.${RESET}"
  exit 1
elif [ $CHECKS_WARNED -gt 0 ]; then
  echo -e "${YELLOW}${BOLD}⚠️  Health check passed with warnings${RESET}"
  echo -e "${YELLOW}Some optional components are missing.${RESET}"
  exit 0
else
  echo -e "${GREEN}${BOLD}✅ All health checks passed!${RESET}"
  echo -e "${GREEN}CloudVuln is ready to use.${RESET}"
  exit 0
fi
