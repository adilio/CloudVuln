#!/usr/bin/env bash
# CloudVuln unified test runner
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load test helpers
if [ -f "${REPO_ROOT}/tests/helpers/test_helpers.sh" ]; then
  source "${REPO_ROOT}/tests/helpers/test_helpers.sh"
fi

# Test categories
RUN_UNIT=false
RUN_INTEGRATION=false
RUN_VALIDATION=false
RUN_ALL=false
VERBOSE=false

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

CloudVuln Test Runner - Execute test suites individually or all at once

OPTIONS:
  -u, --unit              Run unit tests (requires bats)
  -i, --integration       Run integration tests (Terraform validation)
  -v, --validation        Run validation tests (requires deployed infrastructure)
  -a, --all               Run all test suites
  -V, --verbose           Verbose output
  -h, --help              Show this help message

EXAMPLES:
  $0 --unit                    Run only unit tests
  $0 --integration             Run only integration tests
  $0 --all                     Run all tests
  $0 -u -i                     Run unit and integration tests
  $0 --all --verbose           Run all tests with verbose output

TEST SUITES:
  Unit Tests        - Fast, no AWS required, test bash functions
  Integration Tests - Terraform validation, no actual deployment
  Validation Tests  - Verify deployed infrastructure has expected misconfigurations

REQUIREMENTS:
  Unit:        bats, bash
  Integration: terraform, bash
  Validation:  aws cli, jq, deployed CloudVuln scenarios

EOF
  exit 0
}

parse_args() {
  if [ $# -eq 0 ]; then
    usage
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      -u|--unit)
        RUN_UNIT=true
        shift
        ;;
      -i|--integration)
        RUN_INTEGRATION=true
        shift
        ;;
      -v|--validation)
        RUN_VALIDATION=true
        shift
        ;;
      -a|--all)
        RUN_ALL=true
        RUN_UNIT=true
        RUN_INTEGRATION=true
        RUN_VALIDATION=true
        shift
        ;;
      -V|--verbose)
        VERBOSE=true
        shift
        ;;
      -h|--help)
        usage
        ;;
      *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
  done
}

run_unit_tests() {
  test_header "Running Unit Tests"

  if ! command -v bats >/dev/null 2>&1; then
    test_error "Bats not installed"
    test_info "Install: brew install bats-core (macOS) or sudo apt-get install bats (Linux)"
    ((TEST_FAILED++))
    return 1
  fi

  if [ ! -d "${REPO_ROOT}/tests/unit" ]; then
    test_warning "No unit tests directory found"
    ((TEST_SKIPPED++))
    return 0
  fi

  local bats_args=""
  if [ "$VERBOSE" = true ]; then
    bats_args="-t"
  fi

  test_info "Running bats tests in tests/unit/"
  if bats $bats_args "${REPO_ROOT}/tests/unit/"; then
    test_success "Unit tests passed"
    ((TEST_PASSED++))
    return 0
  else
    test_error "Unit tests failed"
    ((TEST_FAILED++))
    return 1
  fi
}

run_integration_tests() {
  test_header "Running Integration Tests"

  if ! command -v terraform >/dev/null 2>&1; then
    test_warning "Terraform not installed - skipping some integration tests"
    test_info "Install: https://developer.hashicorp.com/terraform/downloads"
  fi

  # Run Terraform syntax validation
  if [ -x "${REPO_ROOT}/tests/integration/terraform_syntax_test.sh" ]; then
    test_info "Running Terraform syntax validation..."
    if "${REPO_ROOT}/tests/integration/terraform_syntax_test.sh"; then
      test_success "Integration tests passed"
      return 0
    else
      test_error "Integration tests failed"
      return 1
    fi
  else
    test_error "Integration test script not found or not executable"
    test_info "Expected: ${REPO_ROOT}/tests/integration/terraform_syntax_test.sh"
    ((TEST_FAILED++))
    return 1
  fi
}

run_validation_tests() {
  test_header "Running Validation Tests"

  test_warning "Validation tests require deployed CloudVuln infrastructure"
  test_info "These tests verify that security misconfigurations are present"

  if ! command -v aws >/dev/null 2>&1; then
    test_error "AWS CLI not installed"
    test_info "Install: https://aws.amazon.com/cli/"
    ((TEST_FAILED++))
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    test_error "jq not installed"
    test_info "Install: sudo apt-get install jq"
    ((TEST_FAILED++))
    return 1
  fi

  # Check AWS credentials
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    test_error "AWS credentials not configured"
    test_info "Run: aws configure"
    ((TEST_FAILED++))
    return 1
  fi

  local validation_tests_run=0
  local validation_tests_passed=0

  # Run IAM validation if available
  if [ -x "${REPO_ROOT}/tests/validation/validate_iam_risks.sh" ]; then
    test_info "Running IAM risk validation..."
    if "${REPO_ROOT}/tests/validation/validate_iam_risks.sh"; then
      ((validation_tests_passed++))
    fi
    ((validation_tests_run++))
  fi

  # Run CSPM validation if available
  if [ -x "${REPO_ROOT}/tests/validation/validate_cspm.sh" ]; then
    test_info "Running CSPM validation..."
    if "${REPO_ROOT}/tests/validation/validate_cspm.sh"; then
      ((validation_tests_passed++))
    fi
    ((validation_tests_run++))
  fi

  if [ $validation_tests_run -eq 0 ]; then
    test_warning "No validation tests found"
    ((TEST_SKIPPED++))
    return 0
  fi

  if [ $validation_tests_passed -eq $validation_tests_run ]; then
    test_success "All validation tests passed ($validation_tests_passed/$validation_tests_run)"
    ((TEST_PASSED++))
    return 0
  else
    test_warning "Some validation tests failed ($validation_tests_passed/$validation_tests_run passed)"
    test_info "This may be expected if scenarios are not deployed"
    ((TEST_PASSED++))
    return 0
  fi
}

main() {
  parse_args "$@"

  cd "$REPO_ROOT"

  test_header "CloudVuln Test Runner"
  test_info "Repository: $REPO_ROOT"
  test_info "Test suites: Unit=$RUN_UNIT, Integration=$RUN_INTEGRATION, Validation=$RUN_VALIDATION"
  echo

  local start_time
  start_time=$(date +%s)

  # Run selected test suites
  if [ "$RUN_UNIT" = true ]; then
    run_unit_tests || true
    echo
  fi

  if [ "$RUN_INTEGRATION" = true ]; then
    run_integration_tests || true
    echo
  fi

  if [ "$RUN_VALIDATION" = true ]; then
    run_validation_tests || true
    echo
  fi

  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # Print summary
  test_header "Test Execution Summary"
  echo "Duration: ${duration}s"
  echo

  test_summary
}

main "$@"
