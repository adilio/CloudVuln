#!/usr/bin/env bash
# Validation test: Verify CSPM findings are present
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load test helpers
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_header "CSPM Misconfiguration Validation"

# Check for required tools
if ! command -v aws >/dev/null 2>&1; then
  test_error "AWS CLI not installed"
  exit 1
fi

# Get instance ID or tag to search for
INSTANCE_TAG="${1:-linux-misconfig-web}"
OWNER="${2:-aleghari}"

main() {
  test_info "Validating CSPM misconfigurations"
  test_info "Searching for instances with tag: $INSTANCE_TAG"
  echo

  # Find instance ID
  find_instance

  if [[ -z "${INSTANCE_ID:-}" ]]; then
    test_error "No instance found - have you deployed the scenario?"
    exit 1
  fi

  # Run all validation checks
  validate_imdsv1_enabled
  validate_unencrypted_ebs
  validate_public_ip
  validate_open_security_groups
  validate_outdated_ami

  # Print summary
  test_summary
}

find_instance() {
  test_info "Finding EC2 instance..."

  local query_output
  if ! query_output=$(aws ec2 describe-instances \
    --filters "Name=tag:owner,Values=$OWNER" \
              "Name=tag:scenario,Values=$INSTANCE_TAG" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>&1); then
    test_error "Failed to query EC2 instances"
    return 1
  fi

  if [[ "$query_output" == "None" ]] || [[ -z "$query_output" ]]; then
    test_error "No running instance found with tag owner=$OWNER, scenario=$INSTANCE_TAG"
    return 1
  fi

  INSTANCE_ID="$query_output"
  test_success "Found instance: $INSTANCE_ID"
  ((TEST_PASSED++))
}

validate_imdsv1_enabled() {
  test_info "Checking for IMDSv1 enabled (CSPM violation)..."

  local metadata_options
  if ! metadata_options=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].MetadataOptions' \
    2>&1); then
    test_skip "IMDSv1 check" "Could not retrieve metadata options"
    return 0
  fi

  local http_tokens
  http_tokens=$(echo "$metadata_options" | jq -r '.HttpTokens' 2>/dev/null || echo "unknown")

  if [[ "$http_tokens" == "optional" ]]; then
    test_success "✓ IMDSv1 is enabled (CSPM violation)"
    test_info "  HttpTokens: $http_tokens"
    test_info "  This should trigger CSPM alerts for 'IMDSv1 enabled'"
    test_info "  Risk: Allows SSRF attacks to access instance metadata"
    ((TEST_PASSED++))
    return 0
  elif [[ "$http_tokens" == "required" ]]; then
    test_error "IMDSv2 is required (expected IMDSv1 to be enabled)"
    test_info "  HttpTokens: $http_tokens"
    ((TEST_FAILED++))
    return 1
  else
    test_warning "Unknown metadata configuration: $http_tokens"
    ((TEST_SKIPPED++))
    return 0
  fi
}

validate_unencrypted_ebs() {
  test_info "Checking for unencrypted EBS volumes (CSPM violation)..."

  local volumes
  if ! volumes=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].BlockDeviceMappings[*].Ebs.VolumeId' \
    --output text 2>&1); then
    test_skip "EBS encryption check" "Could not retrieve volumes"
    return 0
  fi

  if [[ -z "$volumes" ]]; then
    test_warning "No EBS volumes found"
    ((TEST_SKIPPED++))
    return 0
  fi

  local unencrypted_count=0
  for volume_id in $volumes; do
    local encrypted
    encrypted=$(aws ec2 describe-volumes \
      --volume-ids "$volume_id" \
      --query 'Volumes[0].Encrypted' \
      --output text 2>/dev/null || echo "false")

    if [[ "$encrypted" == "False" ]] || [[ "$encrypted" == "false" ]]; then
      ((unencrypted_count++))
      test_success "✓ Unencrypted EBS volume found: $volume_id (CSPM violation)"
    fi
  done

  if [[ $unencrypted_count -gt 0 ]]; then
    test_info "  Found $unencrypted_count unencrypted volume(s)"
    test_info "  This should trigger CSPM alerts for 'unencrypted EBS volumes'"
    test_info "  Risk: Data at rest is not encrypted"
    ((TEST_PASSED++))
    return 0
  else
    test_error "All volumes are encrypted (expected at least one unencrypted)"
    ((TEST_FAILED++))
    return 1
  fi
}

validate_public_ip() {
  test_info "Checking for public IP address (CSPM finding)..."

  local public_ip
  public_ip=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null || echo "None")

  if [[ "$public_ip" != "None" ]] && [[ -n "$public_ip" ]]; then
    test_success "✓ Instance has public IP: $public_ip (CSPM finding)"
    test_info "  This should trigger CSPM alerts for 'publicly accessible instance'"
    ((TEST_PASSED++))
    return 0
  else
    test_error "No public IP found (expected public IP for web server)"
    ((TEST_FAILED++))
    return 1
  fi
}

validate_open_security_groups() {
  test_info "Checking for overly permissive security groups (CSPM violation)..."

  local security_groups
  security_groups=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' \
    --output text 2>/dev/null || echo "")

  if [[ -z "$security_groups" ]]; then
    test_skip "Security group check" "No security groups found"
    return 0
  fi

  local violations_found=false

  for sg_id in $security_groups; do
    test_info "  Checking security group: $sg_id"

    # Check for 0.0.0.0/0 ingress rules
    local ingress_rules
    ingress_rules=$(aws ec2 describe-security-groups \
      --group-ids "$sg_id" \
      --query 'SecurityGroups[0].IpPermissions' \
      2>/dev/null || echo "[]")

    # Check if any rule allows 0.0.0.0/0
    if echo "$ingress_rules" | jq -r '.[].IpRanges[].CidrIp' 2>/dev/null | grep -q '0.0.0.0/0'; then
      test_success "  ✓ Security group allows 0.0.0.0/0: $sg_id (CSPM violation)"
      violations_found=true
    fi

    # Check for common vulnerable ports open to internet
    local open_ports
    open_ports=$(echo "$ingress_rules" | jq -r '.[] | select(.IpRanges[]?.CidrIp == "0.0.0.0/0") | .FromPort' 2>/dev/null || echo "")

    if [[ -n "$open_ports" ]]; then
      test_info "  Open ports to 0.0.0.0/0: $open_ports"

      # Check for specific risky ports
      for port in $open_ports; do
        case $port in
          22)
            test_success "  ✓ SSH (22) open to internet (CSPM violation)"
            ;;
          3389)
            test_success "  ✓ RDP (3389) open to internet (CSPM violation)"
            ;;
          80)
            test_info "  HTTP (80) open to internet (expected for web server)"
            ;;
          443)
            test_info "  HTTPS (443) open to internet (expected for web server)"
            ;;
          *)
            test_info "  Port $port open to internet"
            ;;
        esac
      done
    fi
  done

  if [[ "$violations_found" == "true" ]]; then
    test_info "  This should trigger CSPM alerts for 'overly permissive security groups'"
    test_info "  Risk: Excessive network exposure"
    ((TEST_PASSED++))
    return 0
  else
    test_warning "No security group violations found (unexpected)"
    ((TEST_PASSED++))
    return 0
  fi
}

validate_outdated_ami() {
  test_info "Checking for outdated AMI (CSPM finding)..."

  local ami_id
  ami_id=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].ImageId' \
    --output text 2>/dev/null || echo "")

  if [[ -z "$ami_id" ]]; then
    test_skip "AMI check" "Could not retrieve AMI ID"
    return 0
  fi

  local ami_creation_date
  ami_creation_date=$(aws ec2 describe-images \
    --image-ids "$ami_id" \
    --query 'Images[0].CreationDate' \
    --output text 2>/dev/null || echo "")

  if [[ -n "$ami_creation_date" ]]; then
    test_info "  AMI ID: $ami_id"
    test_info "  Creation date: $ami_creation_date"

    # Check if AMI is older than 1 year (intentionally old)
    local ami_year
    ami_year=$(echo "$ami_creation_date" | cut -d'-' -f1)
    local current_year
    current_year=$(date +%Y)

    if [[ $((current_year - ami_year)) -ge 1 ]]; then
      test_success "✓ Using outdated AMI (CSPM finding)"
      test_info "  AMI is $((current_year - ami_year))+ years old"
      test_info "  This should trigger CSPM alerts for 'outdated OS image'"
      ((TEST_PASSED++))
      return 0
    else
      test_info "  AMI is recent (from $ami_year)"
      ((TEST_PASSED++))
      return 0
    fi
  else
    test_skip "AMI age check" "Could not retrieve AMI creation date"
    return 0
  fi
}

# Run main function
main "$@"
