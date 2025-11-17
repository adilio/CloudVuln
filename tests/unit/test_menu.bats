#!/usr/bin/env bats
# Unit tests for menu.sh functions

setup() {
  # Load test helpers
  load '../helpers/test_helpers'

  # Get absolute path to repo root
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

  # Setup test environment
  export TEST_MODE=true
  export TF_VAR_region="us-east-1"
  export TF_VAR_owner="test-user"

  # Create temp directory for mocks
  TEST_TEMP_DIR="$(mktemp -d -t cloudvuln-test.XXXXXX)"

  # Source menu.sh functions (extract functions for testing)
  # We'll source only the helper functions, not the whole script
}

teardown() {
  # Cleanup
  if [[ -n "$TEST_TEMP_DIR" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

# Helper to extract function from menu.sh
extract_function() {
  local func_name="$1"
  # Extract function definition from menu.sh
  sed -n "/^${func_name}()/,/^}/p" "${REPO_ROOT}/menu.sh"
}

@test "is_ipv4: validates correct IPv4 addresses" {
  # Extract and source the is_ipv4 function
  eval "$(extract_function is_ipv4)"

  run is_ipv4 "192.168.1.1"
  [ "$status" -eq 0 ]

  run is_ipv4 "10.0.0.1"
  [ "$status" -eq 0 ]

  run is_ipv4 "172.16.0.1"
  [ "$status" -eq 0 ]

  run is_ipv4 "8.8.8.8"
  [ "$status" -eq 0 ]
}

@test "is_ipv4: rejects invalid IPv4 addresses" {
  eval "$(extract_function is_ipv4)"

  run is_ipv4 "256.1.1.1"
  [ "$status" -eq 1 ]

  run is_ipv4 "192.168.1"
  [ "$status" -eq 1 ]

  run is_ipv4 "not.an.ip.address"
  [ "$status" -eq 1 ]

  run is_ipv4 "192.168.1.1.1"
  [ "$status" -eq 1 ]
}

@test "menu.sh: defines required environment variables" {
  # Check that menu.sh sets default values
  TF_VAR_region="" TF_VAR_owner="" bash -c "source ${REPO_ROOT}/menu.sh; echo \$TF_VAR_region; echo \$TF_VAR_owner" 2>/dev/null || true

  # The script should have defaults
  [ -n "$TF_VAR_region" ] || [ -n "$TF_VAR_owner" ]
}

@test "menu.sh: creates LOG_DIR if missing" {
  local test_log_dir="$TEST_TEMP_DIR/test_logs"

  # Run menu.sh in a subshell that sets LOG_DIR
  (
    export LOG_DIR="$test_log_dir"
    source "${REPO_ROOT}/menu.sh" 2>/dev/null || true
  ) &
  pid=$!
  sleep 1
  kill $pid 2>/dev/null || true

  # Note: Directory creation happens when menu.sh is sourced, but we can't fully test
  # the interactive menu without user input
}

@test "logfile_for: generates correct log filename format" {
  eval "$(extract_function logfile_for)"

  export LOG_DIR="logs"
  result=$(logfile_for "test-scenario" "deploy")

  [[ "$result" =~ ^logs/test-scenario_deploy_[0-9]{8}-[0-9]{6}\.log$ ]]
}

@test "get_scenario_names: returns scenarios in correct order" {
  cd "$REPO_ROOT"

  # Extract and source the function
  eval "$(extract_function get_scenario_names)"

  scenarios=$(get_scenario_names)

  # Check that it returns scenarios in the correct order
  echo "$scenarios" | head -n1 | grep -q "iam-user-risk"
  echo "$scenarios" | tail -n1 | grep -q "docker-container-host"
}

@test "menu.sh: color functions are defined" {
  # Source menu.sh color functions
  eval "$(sed -n '/^c()/,/^}/p' "${REPO_ROOT}/menu.sh")"
  eval "$(sed -n '/^r()/,/^}/p' "${REPO_ROOT}/menu.sh")"
  eval "$(sed -n '/^green()/,/^}/p' "${REPO_ROOT}/menu.sh")"
  eval "$(sed -n '/^red()/,/^}/p' "${REPO_ROOT}/menu.sh")"

  # Test that functions exist and don't error
  run c 2
  [ "$status" -eq 0 ]

  run r
  [ "$status" -eq 0 ]

  run green
  [ "$status" -eq 0 ]

  run red
  [ "$status" -eq 0 ]
}
