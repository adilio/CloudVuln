#!/usr/bin/env bats
# Unit tests for lib/checks.sh

setup() {
  # Load test helpers
  load '../helpers/test_helpers'

  # Get absolute path to repo root
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

  # Source the checks library
  source "${REPO_ROOT}/lib/checks.sh"

  # Setup test environment
  export TEST_MODE=true
  export TF_VAR_region="us-east-1"
  export SKIP_CHECKS=false

  # Create temp directory for mocks
  TEST_TEMP_DIR="$(mktemp -d -t cloudvuln-test.XXXXXX)"

  # Create mock binaries
  create_mock_terraform "$TEST_TEMP_DIR"
  create_mock_aws "$TEST_TEMP_DIR"

  # Add mocks to PATH
  export PATH="$TEST_TEMP_DIR:$PATH"
}

teardown() {
  # Cleanup
  if [[ -n "$TEST_TEMP_DIR" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

@test "check_terraform: passes when terraform is installed" {
  run check_terraform
  [ "$status" -eq 0 ]
}

@test "check_awscli: passes when aws cli is installed" {
  run check_awscli
  [ "$status" -eq 0 ]
}

@test "check_awsauth: passes with valid credentials" {
  run check_awsauth
  [ "$status" -eq 0 ]
}

@test "check_region: passes with valid region" {
  run check_region "us-east-1"
  [ "$status" -eq 0 ]
}

@test "run_checks: skips checks when SKIP_CHECKS=true" {
  export SKIP_CHECKS=true
  run run_checks
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Skipping preflight checks" ]]
}

@test "run_checks: executes all checks when SKIP_CHECKS=false" {
  export SKIP_CHECKS=false
  run run_checks
  [ "$status" -eq 0 ]
  [[ "$output" =~ "All checks passed" ]]
}

@test "run_checks: skips checks with --skip-checks flag" {
  run run_checks --skip-checks
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Skipping preflight checks" ]]
}

@test "status: outputs success message with checkmark" {
  run status "Test message"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✅" ]]
  [[ "$output" =~ "Test message" ]]
}

@test "warn: outputs warning message" {
  run warn "Warning message"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "⚠️" ]]
  [[ "$output" =~ "Warning message" ]]
}

@test "info: outputs info message" {
  run info "Info message"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ℹ️" ]]
  [[ "$output" =~ "Info message" ]]
}

@test "print_banner: outputs formatted banner" {
  run print_banner "Test Banner"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test Banner" ]]
}

@test "color functions: do not error" {
  run green
  [ "$status" -eq 0 ]

  run yellow
  [ "$status" -eq 0 ]

  run red
  [ "$status" -eq 0 ]

  run resetc
  [ "$status" -eq 0 ]
}
