#!/usr/bin/env bash
# Cost estimation tool for CloudVuln scenarios
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

print_header() {
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${BLUE}  $1${RESET}"
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo
}

print_cost() {
  local service="$1"
  local monthly="$2"
  local hourly="$3"
  local notes="$4"

  printf "  %-30s ${BOLD}$%-10s${RESET} ($%-8s) %s\n" \
    "$service" "$monthly" "$hourly/hr" "$notes"
}

print_header "CloudVuln Cost Estimation"

echo -e "${YELLOW}⚠️  This is an estimate based on us-east-1 pricing (Nov 2023)${RESET}"
echo -e "${YELLOW}⚠️  Actual costs may vary based on region, usage, and AWS pricing changes${RESET}"
echo

# Pricing constants (us-east-1)
EC2_T3_MEDIUM_HOURLY=0.0416
WINDOWS_EC2_T3_MEDIUM_HOURLY=0.0835
EBS_GP2_GB_MONTHLY=0.10
S3_STANDARD_GB_MONTHLY=0.023
IAM_FREE=0

# Storage sizes
EBS_ROOT_SIZE=30  # GB
S3_USAGE=1        # GB estimated

echo -e "${BOLD}Act I: IAM User Risk${RESET}"
print_cost "IAM User" "0.00" "0.00" "Free tier"
print_cost "IAM Access Keys (2x)" "0.00" "0.00" "Free tier"
echo -e "${GREEN}  Monthly Total: \$0.00${RESET}"
echo

echo -e "${BOLD}Act II: DSPM Data Generator${RESET}"
echo -e "${YELLOW}  This scenario generates data locally without EC2${RESET}"
s3_cost=$(echo "$S3_STANDARD_GB_MONTHLY * $S3_USAGE" | bc -l)
s3_cost_formatted=$(printf "%.2f" "$s3_cost")
print_cost "S3 Storage (if uploaded)" "$s3_cost_formatted" "0.00" "~1 GB"
print_cost "S3 Requests (PUT)" "0.01" "0.00" "~100 requests"
echo -e "${GREEN}  Monthly Total: \$${s3_cost_formatted} (optional)${RESET}"
echo

echo -e "${BOLD}Act III: Linux Misconfigured Web Server${RESET}"
ec2_monthly=$(echo "$EC2_T3_MEDIUM_HOURLY * 730" | bc -l)
ec2_hourly=$(printf "%.4f" "$EC2_T3_MEDIUM_HOURLY")
ec2_monthly_formatted=$(printf "%.2f" "$ec2_monthly")
ebs_cost=$(echo "$EBS_GP2_GB_MONTHLY * $EBS_ROOT_SIZE" | bc -l)
ebs_cost_formatted=$(printf "%.2f" "$ebs_cost")
linux_total=$(echo "$ec2_monthly + $ebs_cost" | bc -l)
linux_total_formatted=$(printf "%.2f" "$linux_total")

print_cost "EC2 t3.medium (Ubuntu)" "$ec2_monthly_formatted" "$ec2_hourly" "730 hrs/month"
print_cost "EBS gp2 ${EBS_ROOT_SIZE}GB" "$ebs_cost_formatted" "0.00" "Unencrypted"
print_cost "Data Transfer Out" "1.00" "0.00" "~10 GB estimated"
print_cost "Public IP" "3.60" "0.00" "If stopped/started"
echo -e "${GREEN}  Monthly Total: \$${linux_total_formatted} - \$$(echo "$linux_total + 4.60" | bc -l | xargs printf "%.2f")${RESET}"
echo

echo -e "${BOLD}Act IV: Windows Server with IIS${RESET}"
windows_monthly=$(echo "$WINDOWS_EC2_T3_MEDIUM_HOURLY * 730" | bc -l)
windows_hourly=$(printf "%.4f" "$WINDOWS_EC2_T3_MEDIUM_HOURLY")
windows_monthly_formatted=$(printf "%.2f" "$windows_monthly")
windows_total=$(echo "$windows_monthly + $ebs_cost" | bc -l)
windows_total_formatted=$(printf "%.2f" "$windows_total")

print_cost "EC2 t3.medium (Windows)" "$windows_monthly_formatted" "$windows_hourly" "730 hrs/month"
print_cost "EBS gp2 ${EBS_ROOT_SIZE}GB" "$ebs_cost_formatted" "0.00" "Unencrypted"
print_cost "Data Transfer Out" "1.00" "0.00" "~10 GB estimated"
print_cost "Public IP" "3.60" "0.00" "If stopped/started"
echo -e "${GREEN}  Monthly Total: \$${windows_total_formatted} - \$$(echo "$windows_total + 4.60" | bc -l | xargs printf "%.2f")${RESET}"
echo

echo -e "${BOLD}Act V: Docker Container Host${RESET}"
docker_total=$(echo "$ec2_monthly + $ebs_cost" | bc -l)
docker_total_formatted=$(printf "%.2f" "$docker_total")

print_cost "EC2 t3.medium (Ubuntu)" "$ec2_monthly_formatted" "$ec2_hourly" "730 hrs/month"
print_cost "EBS gp2 ${EBS_ROOT_SIZE}GB" "$ebs_cost_formatted" "0.00" "Unencrypted"
print_cost "Data Transfer Out" "1.00" "0.00" "~10 GB estimated"
print_cost "Public IP" "3.60" "0.00" "If stopped/started"
echo -e "${GREEN}  Monthly Total: \$${docker_total_formatted} - \$$(echo "$docker_total + 4.60" | bc -l | xargs printf "%.2f")${RESET}"
echo

print_header "Summary"

# Calculate totals
total_min=$(echo "0 + 0 + $linux_total + $windows_total + $docker_total" | bc -l)
total_max=$(echo "0 + 0.01 + ($linux_total + 4.60) + ($windows_total + 4.60) + ($docker_total + 4.60)" | bc -l)

total_min_formatted=$(printf "%.2f" "$total_min")
total_max_formatted=$(printf "%.2f" "$total_max")

echo -e "${BOLD}Per-Scenario Monthly Cost:${RESET}"
echo -e "  Act I (IAM):           ${GREEN}\$0.00${RESET}"
echo -e "  Act II (DSPM):         ${GREEN}\$0.00 - \$0.01${RESET}"
echo -e "  Act III (Linux):       ${YELLOW}\$$(echo "$linux_total" | bc -l | xargs printf "%.2f") - \$$(echo "$linux_total + 4.60" | bc -l | xargs printf "%.2f")${RESET}"
echo -e "  Act IV (Windows):      ${YELLOW}\$$(echo "$windows_total" | bc -l | xargs printf "%.2f") - \$$(echo "$windows_total + 4.60" | bc -l | xargs printf "%.2f")${RESET}"
echo -e "  Act V (Docker):        ${YELLOW}\$$(echo "$docker_total" | bc -l | xargs printf "%.2f") - \$$(echo "$docker_total + 4.60" | bc -l | xargs printf "%.2f")${RESET}"
echo
echo -e "${BOLD}${GREEN}Total Monthly (All Scenarios): \$${total_min_formatted} - \$${total_max_formatted}${RESET}"
echo

print_header "Cost Optimization Tips"

echo -e "${GREEN}1.${RESET} ${BOLD}Stop instances when not in use${RESET}"
echo "   - Stopping EC2 instances eliminates compute charges"
echo "   - You'll only pay for EBS storage (~\$3/instance)"
echo "   - Use: terraform destroy or ./teardown.sh"
echo

echo -e "${GREEN}2.${RESET} ${BOLD}Use t3.micro for testing${RESET}"
echo "   - Edit vars.tf to change instance_type to t3.micro"
echo "   - Reduces cost by ~75%"
echo "   - Sufficient for CNAPP detection testing"
echo

echo -e "${GREEN}3.${RESET} ${BOLD}Deploy selectively${RESET}"
echo "   - Only deploy scenarios you're actively testing"
echo "   - IAM and DSPM scenarios are nearly free"
echo "   - EC2 scenarios incur ongoing costs"
echo

echo -e "${GREEN}4.${RESET} ${BOLD}Set up AWS Budgets${RESET}"
echo "   - Create budget alerts in AWS Console"
echo "   - Get notified when costs exceed threshold"
echo "   - Recommended: Set budget alert at \$50/month"
echo

echo -e "${GREEN}5.${RESET} ${BOLD}Use ephemeral deployments${RESET}"
echo "   - Deploy → Test → Teardown in same session"
echo "   - Most testing can be done in < 1 hour"
echo "   - Hourly costs: \$0.04 (Linux), \$0.08 (Windows)"
echo

print_header "Hourly Cost (Active Testing)"

hourly_linux=$(printf "%.4f" "$EC2_T3_MEDIUM_HOURLY")
hourly_windows=$(printf "%.4f" "$WINDOWS_EC2_T3_MEDIUM_HOURLY")
hourly_total=$(echo "$EC2_T3_MEDIUM_HOURLY + $WINDOWS_EC2_T3_MEDIUM_HOURLY + $EC2_T3_MEDIUM_HOURLY" | bc -l)
hourly_total_formatted=$(printf "%.4f" "$hourly_total")

echo -e "  All EC2 Scenarios: ${YELLOW}\$${hourly_total_formatted}/hour${RESET}"
echo -e "  Testing for 2 hours: ${YELLOW}\$$(echo "$hourly_total * 2" | bc -l | xargs printf "%.2f")${RESET}"
echo -e "  Testing for 8 hours: ${YELLOW}\$$(echo "$hourly_total * 8" | bc -l | xargs printf "%.2f")${RESET}"
echo

echo -e "${BOLD}${BLUE}💡 Recommendation:${RESET} Deploy scenarios one at a time and teardown when finished"
echo -e "${BOLD}${BLUE}💡 For continuous testing:${RESET} Budget \$60-100/month for all scenarios"
echo

# Check for deployed resources
print_header "Current Deployment Status"

if command -v terraform >/dev/null 2>&1; then
  cd "$REPO_ROOT"
  scenarios=("iam-user-risk" "dspm-data-generator" "linux-misconfig-web" "windows-vuln-iis" "docker-container-host")

  deployed_count=0
  for scenario in "${scenarios[@]}"; do
    if [ -f "$scenario/terraform.tfstate" ]; then
      resources=$(grep -c '"mode":' "$scenario/terraform.tfstate" 2>/dev/null || echo "0")
      if [ "$resources" -gt "0" ]; then
        echo -e "  ${GREEN}✅ $scenario${RESET} - $resources resources deployed"
        ((deployed_count++))
      fi
    fi
  done

  if [ $deployed_count -eq 0 ]; then
    echo -e "  ${YELLOW}No scenarios currently deployed${RESET}"
    echo -e "  ${GREEN}Current monthly cost: \$0.00${RESET}"
  else
    echo
    echo -e "  ${YELLOW}⚠️  $deployed_count scenario(s) currently deployed${RESET}"
    echo -e "  ${YELLOW}⚠️  Remember to teardown when finished testing${RESET}"
  fi
else
  echo -e "  ${YELLOW}Terraform not installed - cannot check deployment status${RESET}"
fi

echo
