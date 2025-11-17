#!/usr/bin/env bash
# Validation test: Verify IAM misconfigurations are present
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load test helpers
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_header "IAM Risk Validation (Act I)"

# Check for required tools
if ! command -v aws >/dev/null 2>&1; then
  test_error "AWS CLI not installed"
  exit 1
fi

# Get IAM user name from scenario
IAM_USER_NAME="${1:-aleghari-iam-user-risk}"

main() {
  test_info "Validating IAM misconfigurations for user: $IAM_USER_NAME"
  echo

  # Run all validation checks
  validate_user_exists
  validate_multiple_access_keys
  validate_no_mfa
  validate_overly_permissive_policy
  validate_weak_password_policy

  # Print summary
  test_summary
}

validate_user_exists() {
  test_info "Checking if IAM user exists..."

  if aws iam get-user --user-name "$IAM_USER_NAME" >/dev/null 2>&1; then
    test_success "IAM user exists: $IAM_USER_NAME"
    ((TEST_PASSED++))
    return 0
  else
    test_error "IAM user not found: $IAM_USER_NAME"
    test_warning "Have you deployed the iam-user-risk scenario?"
    ((TEST_FAILED++))
    return 1
  fi
}

validate_multiple_access_keys() {
  test_info "Checking for multiple access keys (CIEM violation)..."

  local keys_output
  if ! keys_output=$(aws iam list-access-keys --user-name "$IAM_USER_NAME" 2>&1); then
    test_skip "Multiple access keys check" "User not found"
    return 0
  fi

  local key_count
  key_count=$(echo "$keys_output" | jq -r '.AccessKeyMetadata | length' 2>/dev/null || echo "0")

  if [[ $key_count -ge 2 ]]; then
    test_success "✓ Multiple access keys detected: $key_count keys (CIEM violation)"
    test_info "  This should trigger CIEM alerts for 'multiple active access keys'"
    ((TEST_PASSED++))
    return 0
  else
    test_error "Expected 2+ access keys, found: $key_count"
    ((TEST_FAILED++))
    return 1
  fi
}

validate_no_mfa() {
  test_info "Checking for missing MFA (CIEM violation)..."

  local mfa_devices
  if ! mfa_devices=$(aws iam list-mfa-devices --user-name "$IAM_USER_NAME" 2>&1); then
    test_skip "MFA check" "User not found"
    return 0
  fi

  local mfa_count
  mfa_count=$(echo "$mfa_devices" | jq -r '.MFADevices | length' 2>/dev/null || echo "0")

  if [[ $mfa_count -eq 0 ]]; then
    test_success "✓ No MFA enabled (CIEM violation)"
    test_info "  This should trigger CIEM alerts for 'IAM user without MFA'"
    ((TEST_PASSED++))
    return 0
  else
    test_error "MFA is enabled (expected no MFA for this test)"
    ((TEST_FAILED++))
    return 1
  fi
}

validate_overly_permissive_policy() {
  test_info "Checking for overly permissive inline policy (CIEM violation)..."

  local policies
  if ! policies=$(aws iam list-user-policies --user-name "$IAM_USER_NAME" 2>&1); then
    test_skip "Policy check" "User not found"
    return 0
  fi

  local policy_count
  policy_count=$(echo "$policies" | jq -r '.PolicyNames | length' 2>/dev/null || echo "0")

  if [[ $policy_count -eq 0 ]]; then
    test_error "No inline policies found (expected at least one)"
    ((TEST_FAILED++))
    return 1
  fi

  test_success "Found $policy_count inline policy/policies"

  # Get the first policy
  local policy_name
  policy_name=$(echo "$policies" | jq -r '.PolicyNames[0]' 2>/dev/null)

  if [[ -z "$policy_name" ]] || [[ "$policy_name" == "null" ]]; then
    test_error "Could not extract policy name"
    ((TEST_FAILED++))
    return 1
  fi

  # Get policy document
  local policy_doc
  if ! policy_doc=$(aws iam get-user-policy --user-name "$IAM_USER_NAME" --policy-name "$policy_name" 2>&1); then
    test_error "Could not retrieve policy document"
    ((TEST_FAILED++))
    return 1
  fi

  # Check if policy contains wildcard permissions
  if echo "$policy_doc" | jq -r '.PolicyDocument.Statement[].Action' 2>/dev/null | grep -q '"\*"'; then
    test_success "✓ Overly permissive policy detected: Action='*' (CIEM violation)"
    test_info "  Policy: $policy_name"
    test_info "  This should trigger CIEM alerts for 'excessive permissions'"
    ((TEST_PASSED++))
    return 0
  else
    test_error "Policy does not contain wildcard Action (expected Action='*')"
    ((TEST_FAILED++))
    return 1
  fi
}

validate_weak_password_policy() {
  test_info "Checking account password policy (CIEM violation)..."

  local password_policy
  if ! password_policy=$(aws iam get-account-password-policy 2>&1); then
    # Password policy might not be set, which is also a finding
    if echo "$password_policy" | grep -q "NoSuchEntity"; then
      test_success "✓ No password policy set (CIEM violation)"
      test_info "  This should trigger CIEM alerts for 'no password policy'"
      ((TEST_PASSED++))
      return 0
    else
      test_skip "Password policy check" "Could not retrieve policy"
      return 0
    fi
  fi

  # Check for weak password requirements
  local min_length
  min_length=$(echo "$password_policy" | jq -r '.PasswordPolicy.MinimumPasswordLength' 2>/dev/null || echo "0")

  local require_symbols
  require_symbols=$(echo "$password_policy" | jq -r '.PasswordPolicy.RequireSymbols' 2>/dev/null || echo "false")

  local require_numbers
  require_numbers=$(echo "$password_policy" | jq -r '.PasswordPolicy.RequireNumbers' 2>/dev/null || echo "false")

  if [[ $min_length -le 8 ]] || [[ "$require_symbols" == "false" ]] || [[ "$require_numbers" == "false" ]]; then
    test_success "✓ Weak password policy detected (CIEM violation)"
    test_info "  Minimum length: $min_length (weak if ≤8)"
    test_info "  Requires symbols: $require_symbols"
    test_info "  Requires numbers: $require_numbers"
    test_info "  This should trigger CIEM alerts for 'weak password policy'"
    ((TEST_PASSED++))
    return 0
  else
    test_warning "Password policy appears strong (unexpected for this test)"
    test_info "  Minimum length: $min_length"
    test_info "  Requires symbols: $require_symbols"
    test_info "  Requires numbers: $require_numbers"
    ((TEST_PASSED++))
    return 0
  fi
}

# Run main function
main "$@"
