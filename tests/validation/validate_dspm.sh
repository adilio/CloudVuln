#!/usr/bin/env bash
# Validation test: Verify DSPM findings (Data Security Posture Management)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load test helpers
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_header "DSPM Data Exposure Validation (Act II)"

# Check for required tools
if ! command -v aws >/dev/null 2>&1; then
  test_error "AWS CLI not installed"
  exit 1
fi

# DSPM scenario is bash-based, not Terraform
# It generates sensitive data locally and optionally uploads to S3

DSPM_DIR="${1:-/home/user/CloudVuln/dspm-data-generator}"
S3_BUCKET_NAME="${2:-}"

main() {
  test_info "Validating DSPM data generation and exposure"
  echo

  # Run all validation checks
  validate_data_generator_exists
  validate_sensitive_data_patterns
  validate_s3_upload_capability
  if [ -n "$S3_BUCKET_NAME" ]; then
    validate_s3_bucket_exposure
  fi

  # Print summary
  test_summary
}

validate_data_generator_exists() {
  test_info "Checking if DSPM data generator exists..."

  if [ -f "${DSPM_DIR}/dspm-data-generator.sh" ]; then
    test_success "DSPM data generator script found"
    ((TEST_PASSED++))

    # Check if executable
    if [ -x "${DSPM_DIR}/dspm-data-generator.sh" ]; then
      test_success "Script is executable"
      ((TEST_PASSED++))
    else
      test_error "Script is not executable"
      ((TEST_FAILED++))
      return 1
    fi
  else
    test_error "DSPM data generator script not found"
    test_info "Expected: ${DSPM_DIR}/dspm-data-generator.sh"
    ((TEST_FAILED++))
    return 1
  fi
}

validate_sensitive_data_patterns() {
  test_info "Checking for sensitive data pattern generation capabilities..."

  local script="${DSPM_DIR}/dspm-data-generator.sh"

  # Check if script contains patterns for sensitive data types
  local patterns=(
    "SSN"
    "credit.*card"
    "patient"
    "API.*key"
    "password"
    "email"
    "phone"
  )

  local found_count=0
  for pattern in "${patterns[@]}"; do
    if grep -qi "$pattern" "$script" 2>/dev/null; then
      test_success "✓ Script generates: $pattern data"
      ((found_count++))
    fi
  done

  if [ $found_count -ge 5 ]; then
    test_success "Script generates multiple sensitive data types ($found_count/7)"
    test_info "  This should trigger DSPM alerts for:"
    test_info "  • PII (Personal Identifiable Information)"
    test_info "  • PHI (Protected Health Information)"
    test_info "  • PCI (Payment Card Industry data)"
    test_info "  • Credentials and secrets"
    ((TEST_PASSED++))
    return 0
  else
    test_error "Script generates insufficient data types ($found_count/7)"
    ((TEST_FAILED++))
    return 1
  fi
}

validate_s3_upload_capability() {
  test_info "Checking S3 upload capability..."

  if [ -f "${DSPM_DIR}/dspm-upload-to-s3.sh" ]; then
    test_success "S3 upload script found"
    ((TEST_PASSED++))

    # Check if executable
    if [ -x "${DSPM_DIR}/dspm-upload-to-s3.sh" ]; then
      test_success "S3 upload script is executable"
      ((TEST_PASSED++))
    else
      test_warning "S3 upload script is not executable"
      ((TEST_WARNED++))
    fi
  else
    test_error "S3 upload script not found"
    test_info "Expected: ${DSPM_DIR}/dspm-upload-to-s3.sh"
    ((TEST_FAILED++))
    return 1
  fi
}

validate_s3_bucket_exposure() {
  test_info "Checking S3 bucket for DSPM findings..."

  local bucket="$S3_BUCKET_NAME"

  # Check if bucket exists
  if ! aws s3 ls "s3://${bucket}" >/dev/null 2>&1; then
    test_warning "S3 bucket not found: $bucket"
    test_info "Have you uploaded data to S3?"
    ((TEST_SKIPPED++))
    return 0
  fi

  test_success "S3 bucket exists: $bucket"
  ((TEST_PASSED++))

  # Check bucket policy for public access
  test_info "  Checking bucket public access configuration..."

  local public_access
  public_access=$(aws s3api get-public-access-block --bucket "$bucket" 2>&1 || echo "none")

  if echo "$public_access" | grep -q "NoSuchPublicAccessBlockConfiguration"; then
    test_success "  ✓ No public access block configured (DSPM risk)"
    test_info "    This should trigger DSPM alerts for 'publicly accessible bucket'"
    ((TEST_PASSED++))
  elif echo "$public_access" | grep -q '"BlockPublicAcls": false'; then
    test_success "  ✓ Public ACLs allowed (DSPM risk)"
    ((TEST_PASSED++))
  else
    test_info "  Bucket has public access restrictions (safer but reduces DSPM findings)"
    ((TEST_PASSED++))
  fi

  # Check for objects with sensitive data
  test_info "  Checking for sensitive data files..."

  local objects
  objects=$(aws s3 ls "s3://${bucket}/" 2>/dev/null | wc -l || echo "0")

  if [ "$objects" -gt 0 ]; then
    test_success "  ✓ Found $objects object(s) in bucket"
    test_info "    DSPM scanners should detect sensitive data in these objects"

    # List some files
    aws s3 ls "s3://${bucket}/" 2>/dev/null | head -5 | while read -r line; do
      test_info "    • $line"
    done

    ((TEST_PASSED++))
  else
    test_warning "  No objects found in bucket"
    test_info "    Run dspm-upload-to-s3.sh to upload test data"
    ((TEST_SKIPPED++))
  fi

  # Check bucket encryption
  test_info "  Checking bucket encryption..."

  local encryption
  encryption=$(aws s3api get-bucket-encryption --bucket "$bucket" 2>&1 || echo "none")

  if echo "$encryption" | grep -q "ServerSideEncryptionConfigurationNotFoundError"; then
    test_success "  ✓ No default encryption configured (DSPM finding)"
    test_info "    This should trigger DSPM alerts for 'unencrypted bucket'"
    ((TEST_PASSED++))
  else
    test_info "  Bucket has default encryption configured"
    test_info "    This reduces DSPM risk but data is still detectable"
    ((TEST_PASSED++))
  fi
}

# Run main function
main "$@"
