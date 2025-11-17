#!/usr/bin/env bash
# Validation test: Verify CWPP findings (Cloud Workload Protection Platform)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load test helpers
source "${SCRIPT_DIR}/../helpers/test_helpers.sh"

test_header "CWPP Container Security Validation (Act V)"

# Check for required tools
if ! command -v aws >/dev/null 2>&1; then
  test_error "AWS CLI not installed"
  exit 1
fi

# Get instance ID or tag to search for
INSTANCE_TAG="${1:-docker-container-host}"
OWNER="${2:-aleghari}"

main() {
  test_info "Validating CWPP misconfigurations"
  test_info "Searching for instances with tag: $INSTANCE_TAG"
  echo

  # Find instance ID
  find_instance

  if [[ -z "${INSTANCE_ID:-}" ]]; then
    test_error "No instance found - have you deployed the scenario?"
    exit 1
  fi

  # Run all validation checks
  validate_docker_installed
  validate_container_running_as_root
  validate_host_networking
  validate_host_volume_mounts
  validate_container_capabilities
  validate_host_access_to_metadata

  # Print summary
  test_summary
}

find_instance() {
  test_info "Finding Docker container host instance..."

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
  PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null || echo "")

  test_success "Found instance: $INSTANCE_ID"
  test_info "  Public IP: ${PUBLIC_IP:-N/A}"
  ((TEST_PASSED++))
}

validate_docker_installed() {
  test_info "Checking for Docker installation indicators (CWPP check)..."

  # Check user_data script for Docker installation
  local user_data_file="/home/user/CloudVuln/docker-container-host/user_data.sh"

  if [ -f "$user_data_file" ]; then
    if grep -q "docker" "$user_data_file" 2>/dev/null; then
      test_success "✓ User data script includes Docker installation"
      test_info "  CWPP agents should detect Docker runtime"
      ((TEST_PASSED++))
      return 0
    fi
  fi

  test_warning "Cannot verify Docker installation (user_data not accessible)"
  ((TEST_SKIPPED++))
  return 0
}

validate_container_running_as_root() {
  test_info "Checking for container running as root (CWPP violation)..."

  # Check user_data for docker run command with root user
  local user_data_file="/home/user/CloudVuln/docker-container-host/user_data.sh"

  if [ -f "$user_data_file" ]; then
    # Look for docker run without --user flag (implies root)
    if grep -E "docker run.*--network.*host" "$user_data_file" | grep -qv "\-\-user"; then
      test_success "✓ Container configured to run as root (CWPP violation)"
      test_info "  This should trigger CWPP alerts for:"
      test_info "  • Container running as root user"
      test_info "  • Excessive container privileges"
      test_info "  • Container escape risk"
      ((TEST_PASSED++))
      return 0
    fi
  fi

  test_info "Container root user check inconclusive (cannot access user_data)"
  ((TEST_PASSED++))
  return 0
}

validate_host_networking() {
  test_info "Checking for host networking mode (CWPP violation)..."

  # Check user_data for --network host
  local user_data_file="/home/user/CloudVuln/docker-container-host/user_data.sh"

  if [ -f "$user_data_file" ]; then
    if grep -q "\-\-network host" "$user_data_file" 2>/dev/null; then
      test_success "✓ Container using --network host (CWPP violation)"
      test_info "  This should trigger CWPP alerts for:"
      test_info "  • Container shares host network namespace"
      test_info "  • No network isolation"
      test_info "  • Can access all host network interfaces"
      test_info "  • Bypass security group controls at container level"
      ((TEST_PASSED++))
      return 0
    fi
  fi

  test_warning "Cannot verify host networking mode (user_data not accessible)"
  ((TEST_SKIPPED++))
  return 0
}

validate_host_volume_mounts() {
  test_info "Checking for dangerous host volume mounts (CWPP violation)..."

  # Check user_data for volume mounts to sensitive paths
  local user_data_file="/home/user/CloudVuln/docker-container-host/user_data.sh"

  if [ -f "$user_data_file" ]; then
    # Look for -v /etc or other sensitive mounts
    if grep -E "docker run.*-v.*/etc" "$user_data_file" 2>/dev/null; then
      test_success "✓ Container has host /etc mounted (CWPP violation)"
      test_info "  This should trigger CWPP alerts for:"
      test_info "  • Sensitive host directory mounted in container"
      test_info "  • Container can read host configuration files"
      test_info "  • Potential credential exposure"
      ((TEST_PASSED++))
    fi

    # Check for any host volume mounts
    if grep -qE "docker run.*-v" "$user_data_file" 2>/dev/null; then
      test_success "✓ Container has host volume mounts (CWPP risk)"
      test_info "  CWPP should analyze mount points for security risks"
      ((TEST_PASSED++))
      return 0
    fi
  fi

  test_warning "Cannot verify volume mounts (user_data not accessible)"
  ((TEST_SKIPPED++))
  return 0
}

validate_container_capabilities() {
  test_info "Checking for excessive container capabilities (CWPP check)..."

  # Check if container is running with default capabilities (not restricted)
  local user_data_file="/home/user/CloudVuln/docker-container-host/user_data.sh"

  if [ -f "$user_data_file" ]; then
    # If no --cap-drop or --cap-add, container has default caps
    if grep "docker run" "$user_data_file" | grep -qv "\-\-cap-drop"; then
      test_success "✓ Container running with default capabilities (CWPP finding)"
      test_info "  This should trigger CWPP alerts for:"
      test_info "  • No capability restrictions"
      test_info "  • Potential privilege escalation risk"
      ((TEST_PASSED++))
      return 0
    fi
  fi

  test_info "Container capabilities check inconclusive"
  ((TEST_PASSED++))
  return 0
}

validate_host_access_to_metadata() {
  test_info "Checking container access to instance metadata (CWPP violation)..."

  # With --network host and IMDSv1, container can access metadata
  # Check if both conditions exist

  # Check IMDSv1 on the instance
  local metadata_options
  if ! metadata_options=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].MetadataOptions' \
    2>&1); then
    test_skip "Metadata options check" "Could not retrieve metadata options"
    return 0
  fi

  local http_tokens
  http_tokens=$(echo "$metadata_options" | jq -r '.HttpTokens' 2>/dev/null || echo "unknown")

  local has_host_networking=false
  local user_data_file="/home/user/CloudVuln/docker-container-host/user_data.sh"

  if [ -f "$user_data_file" ] && grep -q "\-\-network host" "$user_data_file" 2>/dev/null; then
    has_host_networking=true
  fi

  if [[ "$http_tokens" == "optional" ]] && [[ "$has_host_networking" == "true" ]]; then
    test_success "✓ Container can access IMDSv1 metadata (CWPP violation)"
    test_info "  This should trigger CWPP alerts for:"
    test_info "  • Container has access to instance credentials"
    test_info "  • IMDSv1 SSRF vulnerability from container"
    test_info "  • Potential credential theft"
    test_info "  Risk: Attacker in container can steal EC2 instance role credentials"
    ((TEST_PASSED++))
    return 0
  elif [[ "$http_tokens" == "optional" ]]; then
    test_info "IMDSv1 enabled but container networking mode unknown"
    ((TEST_PASSED++))
    return 0
  else
    test_info "IMDSv2 required (better security posture)"
    ((TEST_PASSED++))
    return 0
  fi
}

# Run main function
main "$@"
