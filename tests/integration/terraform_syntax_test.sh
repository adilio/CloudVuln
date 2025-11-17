#!/usr/bin/env bash
# Integration test: Terraform syntax validation for all scenarios
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load test helpers
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_header "Terraform Syntax Validation"

# Scenarios to test
SCENARIOS=(
  "iam-user-risk"
  "dspm-data-generator"
  "linux-misconfig-web"
  "windows-vuln-iis"
  "docker-container-host"
)

main() {
  test_info "Starting Terraform syntax validation for all scenarios"
  test_info "Repository: $REPO_ROOT"
  echo

  # Check if Terraform is installed
  if command -v terraform >/dev/null 2>&1; then
    test_success "Terraform is installed: $(terraform version | head -n1)"
    TERRAFORM_AVAILABLE=true
  else
    test_warning "Terraform not installed - running basic syntax checks only"
    TERRAFORM_AVAILABLE=false
  fi
  echo

  # Test each scenario
  for scenario in "${SCENARIOS[@]}"; do
    test_scenario_syntax "$scenario"
  done

  # Print summary
  test_summary
}

test_scenario_syntax() {
  local scenario="$1"
  local scenario_dir="${REPO_ROOT}/${scenario}"

  test_header "Testing: $scenario"

  # Check if scenario directory exists
  if [[ ! -d "$scenario_dir" ]]; then
    test_error "Scenario directory not found: $scenario_dir"
    ((TEST_FAILED++))
    return 1
  fi
  test_success "Scenario directory exists"

  # Validate scenario structure
  if ! validate_scenario_structure "$scenario_dir"; then
    ((TEST_FAILED++))
    return 1
  fi
  ((TEST_PASSED++))

  # Check Terraform files exist
  local tf_files
  tf_files=$(find "$scenario_dir" -maxdepth 1 -name "*.tf" | wc -l)
  if [[ $tf_files -gt 0 ]]; then
    test_success "Found $tf_files Terraform file(s)"
  else
    test_error "No Terraform files found in $scenario"
    ((TEST_FAILED++))
    return 1
  fi
  ((TEST_PASSED++))

  # Basic syntax validation
  if terraform_syntax_check "$scenario_dir"; then
    test_success "Basic syntax validation passed"
    ((TEST_PASSED++))
  else
    test_error "Basic syntax validation failed"
    ((TEST_FAILED++))
    return 1
  fi

  # If Terraform is available, run terraform validate
  if [[ "$TERRAFORM_AVAILABLE" == "true" ]]; then
    test_terraform_validate "$scenario_dir"
  else
    test_skip "Terraform validate" "Terraform not installed"
  fi

  echo
  return 0
}

test_terraform_validate() {
  local scenario_dir="$1"

  test_info "Running: terraform init"
  if ! (cd "$scenario_dir" && terraform init -backend=false > /dev/null 2>&1); then
    test_warning "Terraform init failed (may need AWS provider)"
    ((TEST_SKIPPED++))
    return 0
  fi
  test_success "Terraform init completed"
  ((TEST_PASSED++))

  test_info "Running: terraform validate"
  local validate_output
  if validate_output=$(cd "$scenario_dir" && terraform validate 2>&1); then
    test_success "Terraform validate passed"
    ((TEST_PASSED++))

    # Check for success message
    if echo "$validate_output" | grep -q "Success"; then
      test_success "Configuration is valid"
    fi
  else
    test_error "Terraform validate failed"
    echo "$validate_output" | head -n20
    ((TEST_FAILED++))
    return 1
  fi
}

# Run main function
main "$@"
