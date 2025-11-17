#!/usr/bin/env bash
# Test helper functions for CloudVuln test suite

# Colors for test output
setup_colors() {
  if [[ -t 1 ]]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
  else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    BOLD=""
    RESET=""
  fi
}

setup_colors

# Test output functions
test_info() {
  echo "${CYAN}ℹ️  $*${RESET}"
}

test_success() {
  echo "${GREEN}✅ $*${RESET}"
}

test_warning() {
  echo "${YELLOW}⚠️  $*${RESET}"
}

test_error() {
  echo "${RED}❌ $*${RESET}"
}

test_header() {
  echo
  echo "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo "${BOLD}${BLUE}  $*${RESET}"
  echo "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo
}

# Assert functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Values not equal}"

  if [[ "$expected" != "$actual" ]]; then
    test_error "$message"
    test_error "  Expected: $expected"
    test_error "  Actual:   $actual"
    return 1
  fi
  return 0
}

assert_not_equals() {
  local not_expected="$1"
  local actual="$2"
  local message="${3:-Values should not be equal}"

  if [[ "$not_expected" == "$actual" ]]; then
    test_error "$message"
    test_error "  Not expected: $not_expected"
    test_error "  Actual:       $actual"
    return 1
  fi
  return 0
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-String not found}"

  if [[ ! "$haystack" =~ $needle ]]; then
    test_error "$message"
    test_error "  Looking for: $needle"
    test_error "  In:          $haystack"
    return 1
  fi
  return 0
}

assert_file_exists() {
  local file="$1"
  local message="${2:-File does not exist: $file}"

  if [[ ! -f "$file" ]]; then
    test_error "$message"
    return 1
  fi
  return 0
}

assert_dir_exists() {
  local dir="$1"
  local message="${2:-Directory does not exist: $dir}"

  if [[ ! -d "$dir" ]]; then
    test_error "$message"
    return 1
  fi
  return 0
}

assert_command_exists() {
  local cmd="$1"
  local message="${2:-Command not found: $cmd}"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    test_error "$message"
    return 1
  fi
  return 0
}

assert_exit_code() {
  local expected_code="$1"
  local actual_code="$2"
  local message="${3:-Exit code mismatch}"

  if [[ "$expected_code" != "$actual_code" ]]; then
    test_error "$message"
    test_error "  Expected exit code: $expected_code"
    test_error "  Actual exit code:   $actual_code"
    return 1
  fi
  return 0
}

# Test environment setup
setup_test_env() {
  export TEST_MODE=true
  export TF_VAR_owner="test-user"
  export TF_VAR_region="us-east-1"
  export SKIP_CHECKS=true
}

cleanup_test_env() {
  unset TEST_MODE
  unset SKIP_CHECKS
}

# Mock helpers
create_mock_terraform() {
  local mock_dir="$1"
  mkdir -p "$mock_dir"

  cat > "$mock_dir/terraform" <<'EOF'
#!/usr/bin/env bash
# Mock terraform for testing
case "$1" in
  --version)
    echo "Terraform v1.5.0"
    ;;
  init)
    echo "Terraform initialized"
    ;;
  validate)
    echo "Success! The configuration is valid."
    ;;
  plan)
    echo "Plan: 5 to add, 0 to change, 0 to destroy."
    ;;
  apply)
    echo "Apply complete! Resources: 5 added, 0 changed, 0 destroyed."
    ;;
  destroy)
    echo "Destroy complete! Resources: 5 destroyed."
    ;;
  output)
    if [[ "$2" == "-json" ]]; then
      echo '{"public_ip":{"value":"1.2.3.4"}}'
    else
      echo "1.2.3.4"
    fi
    ;;
  *)
    echo "Mock terraform: $*"
    ;;
esac
EOF
  chmod +x "$mock_dir/terraform"
}

create_mock_aws() {
  local mock_dir="$1"
  mkdir -p "$mock_dir"

  cat > "$mock_dir/aws" <<'EOF'
#!/usr/bin/env bash
# Mock aws CLI for testing
case "$1" in
  sts)
    if [[ "$2" == "get-caller-identity" ]]; then
      echo '{"UserId":"AIDAEXAMPLE","Account":"123456789012","Arn":"arn:aws:iam::123456789012:user/testuser"}'
    fi
    ;;
  ec2)
    case "$2" in
      describe-regions)
        echo '{"Regions":[{"RegionName":"us-east-1"},{"RegionName":"us-west-2"}]}'
        ;;
      describe-instances)
        echo '{"Reservations":[{"Instances":[{"InstanceId":"i-1234567890abcdef0","State":{"Name":"running"},"PublicIpAddress":"1.2.3.4"}]}]}'
        ;;
      *)
        echo '{"Result":"mock-ec2-response"}'
        ;;
    esac
    ;;
  iam)
    case "$2" in
      get-user)
        echo '{"User":{"UserName":"test-user","UserId":"AIDATEST","Arn":"arn:aws:iam::123456789012:user/test-user"}}'
        ;;
      list-access-keys)
        echo '{"AccessKeyMetadata":[{"AccessKeyId":"AKIAIOSFODNN7EXAMPLE","Status":"Active"},{"AccessKeyId":"AKIAI44QH8DHBEXAMPLE","Status":"Active"}]}'
        ;;
      *)
        echo '{"Result":"mock-iam-response"}'
        ;;
    esac
    ;;
  *)
    echo '{"Result":"mock-aws-response"}'
    ;;
esac
EOF
  chmod +x "$mock_dir/aws"
}

# Temporary directory management
create_temp_test_dir() {
  local temp_dir
  temp_dir=$(mktemp -d -t cloudvuln-test.XXXXXX)
  echo "$temp_dir"
}

cleanup_temp_dir() {
  local temp_dir="$1"
  if [[ -n "$temp_dir" ]] && [[ -d "$temp_dir" ]]; then
    rm -rf "$temp_dir"
  fi
}

# Terraform helpers
terraform_syntax_check() {
  local scenario_dir="$1"

  if [[ ! -d "$scenario_dir" ]]; then
    test_error "Scenario directory does not exist: $scenario_dir"
    return 1
  fi

  test_info "Checking Terraform syntax in $scenario_dir"

  # Check for required files
  local required_files=("main.tf" "vars.tf")
  for file in "${required_files[@]}"; do
    if [[ ! -f "$scenario_dir/$file" ]]; then
      test_error "Required file missing: $file"
      return 1
    fi
  done

  # Basic syntax validation (without terraform installed)
  # Check for common syntax errors
  local tf_files
  tf_files=$(find "$scenario_dir" -name "*.tf")

  for tf_file in $tf_files; do
    # Check for balanced braces
    local open_braces
    local close_braces
    open_braces=$(grep -o '{' "$tf_file" | wc -l)
    close_braces=$(grep -o '}' "$tf_file" | wc -l)

    if [[ "$open_braces" != "$close_braces" ]]; then
      test_error "Unbalanced braces in $tf_file"
      test_error "  Open braces: $open_braces"
      test_error "  Close braces: $close_braces"
      return 1
    fi

    # Check for basic HCL2 syntax
    if grep -q '^\s*resource\s\+"\w\+"\s\+"\w\+"\s\+{' "$tf_file"; then
      test_success "Valid resource syntax in $(basename "$tf_file")"
    fi
  done

  return 0
}

# Scenario validation helpers
validate_scenario_structure() {
  local scenario_dir="$1"
  local scenario_name
  scenario_name=$(basename "$scenario_dir")

  test_header "Validating structure: $scenario_name"

  local required_files=(
    "main.tf"
    "vars.tf"
    "deploy.sh"
    "teardown.sh"
    "README.md"
  )

  local all_present=true
  for file in "${required_files[@]}"; do
    if [[ -f "$scenario_dir/$file" ]]; then
      test_success "$file present"
    else
      test_error "$file missing"
      all_present=false
    fi
  done

  # Check if shell scripts are executable
  if [[ -f "$scenario_dir/deploy.sh" ]]; then
    if [[ -x "$scenario_dir/deploy.sh" ]]; then
      test_success "deploy.sh is executable"
    else
      test_warning "deploy.sh is not executable"
    fi
  fi

  if [[ -f "$scenario_dir/teardown.sh" ]]; then
    if [[ -x "$scenario_dir/teardown.sh" ]]; then
      test_success "teardown.sh is executable"
    else
      test_warning "teardown.sh is not executable"
    fi
  fi

  if [[ "$all_present" == "true" ]]; then
    test_success "All required files present for $scenario_name"
    return 0
  else
    test_error "Some required files missing for $scenario_name"
    return 1
  fi
}

# Test counter
declare -g TEST_PASSED=0
declare -g TEST_FAILED=0
declare -g TEST_SKIPPED=0

test_run() {
  local test_name="$1"
  local test_function="$2"

  test_info "Running: $test_name"

  if $test_function; then
    ((TEST_PASSED++))
    test_success "PASSED: $test_name"
    return 0
  else
    ((TEST_FAILED++))
    test_error "FAILED: $test_name"
    return 1
  fi
}

test_skip() {
  local test_name="$1"
  local reason="$2"

  ((TEST_SKIPPED++))
  test_warning "SKIPPED: $test_name ($reason)"
}

test_summary() {
  echo
  test_header "Test Summary"

  local total=$((TEST_PASSED + TEST_FAILED + TEST_SKIPPED))

  echo "${GREEN}✅ Passed:  $TEST_PASSED${RESET}"
  echo "${RED}❌ Failed:  $TEST_FAILED${RESET}"
  echo "${YELLOW}⏭️  Skipped: $TEST_SKIPPED${RESET}"
  echo "${BOLD}Total:    $total${RESET}"
  echo

  if [[ $TEST_FAILED -gt 0 ]]; then
    test_error "Some tests failed!"
    return 1
  else
    test_success "All tests passed!"
    return 0
  fi
}

# Export functions for use in tests
export -f setup_colors
export -f test_info test_success test_warning test_error test_header
export -f assert_equals assert_not_equals assert_contains
export -f assert_file_exists assert_dir_exists assert_command_exists assert_exit_code
export -f setup_test_env cleanup_test_env
export -f create_mock_terraform create_mock_aws
export -f create_temp_test_dir cleanup_temp_dir
export -f terraform_syntax_check validate_scenario_structure
export -f test_run test_skip test_summary
