# CNAPP Platform Integration Guide

This guide explains how to integrate CloudVuln with popular Cloud-Native Application Protection Platform (CNAPP) solutions to validate their detection capabilities.

## Overview

CloudVuln is designed to trigger detections across CNAPP platforms that provide:
- **CSPM** (Cloud Security Posture Management)
- **CDR** (Cloud Detection & Response)
- **CIEM** (Cloud Infrastructure Entitlement Management)
- **DSPM** (Data Security Posture Management)
- **CWPP** (Cloud Workload Protection Platform)

## Supported Platforms

This guide covers integration with:
1. Wiz
2. Prisma Cloud (Palo Alto Networks)
3. CrowdStrike Falcon Cloud Security
4. Lacework
5. Orca Security
6. Aqua Security
7. AWS Security Hub
8. Azure Defender for Cloud (for AWS)
9. Sysdig Secure

## General Integration Steps

### 1. Prerequisites

- CloudVuln deployed in AWS account
- CNAPP platform connected to same AWS account
- Appropriate IAM permissions for CNAPP platform
- Scanning enabled in CNAPP platform

### 2. Deployment Workflow

```bash
# 1. Deploy CloudVuln scenario
make deploy-linux-misconfig-web

# 2. Wait for CNAPP platform to scan (usually 5-30 minutes)
# 3. Check CNAPP dashboard for detections
# 4. Validate findings match expected misconfigurations
# 5. Clean up
make teardown-linux-misconfig-web
```

## Platform-Specific Guides

### Wiz

#### Setup

1. **Connect AWS Account**
   - Navigate to Settings → Cloud Accounts
   - Add AWS Account via CloudFormation stack
   - Grant read-only permissions

2. **Enable Scanning**
   - Enable Runtime Scan for CWPP
   - Enable CI/CD scanning (optional)
   - Configure scan frequency

#### Expected Detections

| Scenario | Expected Wiz Findings |
|----------|----------------------|
| iam-user-risk | IAM user without MFA, Multiple access keys, Overly permissive policy |
| linux-misconfig-web | IMDSv1 enabled, Unencrypted EBS, Public instance, Outdated packages |
| windows-vuln-iis | Public RDP, IMDSv1, Unencrypted EBS, Directory browsing |
| docker-container-host | Root container, Host networking, Sensitive mounts |

#### Validation

```bash
# Deploy and wait
make deploy-iam-user-risk
sleep 600  # Wait 10 minutes for scan

# Check Wiz dashboard:
# - Navigate to Security Graph
# - Filter by Tag: owner=your-name
# - Review Issues tab
```

#### Wiz-Specific Features to Test

- **Attack Paths**: Wiz should show attack paths to IAM credentials
- **Toxic Combinations**: Should flag combinations like IMDSv1 + public instance
- **Runtime Detection**: Should detect container misconfigurations

---

### Prisma Cloud (Palo Alto)

#### Setup

1. **Onboard AWS Account**
   - Settings → Cloud Accounts → Add AWS Account
   - Choose between CFT or Terraform deployment
   - Select Read-Only or Read-Write mode

2. **Enable Modules**
   - Enable CSPM, CWPP, CIEM, DSPM modules
   - Deploy Defenders for runtime protection (optional)

#### Expected Detections

| Policy | Scenario | Severity |
|--------|----------|----------|
| AWS EC2 instance not configured with IMDSv2 | Acts III, IV, V | High |
| AWS IAM policy allows full administrative privileges | Act I | Critical |
| AWS EBS volume not encrypted | Acts III, IV, V | High |
| AWS Security Group allows internet traffic to RDP | Act IV | Critical |
| Container running as root | Act V | Medium |

#### Validation

```bash
# Deploy scenarios
make deploy-all

# In Prisma Cloud console:
# - Inventory → Assets → Filter by Cloud Account
# - Compliance → CIS AWS Foundations Benchmark
# - Alerts → Filter by recent alerts
```

#### Prisma Cloud API Validation

```bash
# Get alerts via API
curl -X GET "https://api.prismacloud.io/alert" \
  -H "x-redlock-auth: YOUR_TOKEN" \
  | jq '.items[] | select(.resource.name | contains("cloudvuln"))'
```

---

### CrowdStrike Falcon Cloud Security

#### Setup

1. **Register AWS Account**
   - Cloud Security → Account Registration
   - Run CloudFormation template
   - Enable IOA (Indicator of Attack) detection

2. **Install Falcon Sensor** (for CWPP)
   - Add sensor installation to user_data scripts
   - Configure sensor for container visibility

#### Expected Detections

| Detection Type | Scenario | Category |
|---------------|----------|----------|
| Weak IAM Policy | Act I | CIEM |
| IMDSv1 Enabled | Acts III, IV, V | CSPM |
| Privileged Container | Act V | CWPP |
| Unencrypted Storage | Acts III, IV, V | CSPM |

#### Validation

```bash
# Check CrowdStrike console:
# - Cloud Security → Misconfigurations
# - Filter by Tag: owner:your-name
# - Review IOAs (Indicators of Attack)
```

---

### Lacework

#### Setup

1. **Integrate AWS**
   - Settings → Cloud Accounts → AWS
   - Deploy via CloudFormation or Terraform
   - Enable CloudTrail integration

2. **Agent Installation** (optional for CWPP)
   - Add Lacework agent to user_data
   - Configure agent for container monitoring

#### Expected Detections

| Scenario | Lacework Policy Violation |
|----------|---------------------------|
| iam-user-risk | LW_AWS_IAM_13 (No MFA), LW_AWS_IAM_6 (Multiple keys) |
| linux-misconfig-web | LW_AWS_EC2_1 (IMDSv1), LW_AWS_EC2_3 (Unencrypted EBS) |
| windows-vuln-iis | LW_AWS_NETWORKING_1 (Public RDP) |

#### Validation

```bash
# Lacework API check
curl -X POST "https://YOUR_ACCOUNT.lacework.net/api/v2/Compliance/AWS" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  | jq '.data[] | select(.tags.owner == "your-name")'
```

---

### Orca Security

#### Setup

1. **Connect Cloud Account**
   - Assets → Cloud Accounts → Add Account
   - Select AWS
   - Grant SideScanning permissions (agentless)

2. **Enable Coverage**
   - Ensure all regions are enabled
   - Enable automatic asset discovery

#### Expected Detections

| Scenario | Orca Alert |
|----------|-----------|
| All scenarios | Lateral movement risks, Cloud attack paths |
| iam-user-risk | Privilege escalation risk |
| linux-misconfig-web | Vulnerable packages, Exposed secrets |

#### Validation

```bash
# Check Orca dashboard:
# - Alerts → Filter by Cloud Account
# - Attack Paths → Look for CloudVuln resources
# - Lateral Movement Risks
```

---

### AWS Security Hub

#### Setup

1. **Enable Security Hub**
   ```bash
   aws securityhub enable-security-hub --region us-east-1
   ```

2. **Enable Standards**
   - AWS Foundational Security Best Practices
   - CIS AWS Foundations Benchmark
   - PCI-DSS

3. **Enable Integrations**
   - AWS Config
   - Amazon GuardDuty
   - Amazon Inspector

#### Expected Findings

| Control ID | Finding | Scenario |
|-----------|---------|----------|
| IAM.6 | Hardware MFA not enabled for root | Act I |
| EC2.8 | EC2 instance uses IMDSv1 | Acts III, IV, V |
| EC2.7 | EBS default encryption disabled | Acts III, IV, V |
| EC2.21 | Security group allows 0.0.0.0/0 on port 22 | Acts III, V |

#### Validation

```bash
# Query findings via AWS CLI
aws securityhub get-findings \
  --filters '{"ResourceTags": [{"Key": "owner", "Value": "your-name"}]}' \
  --region us-east-1 \
  | jq '.Findings[] | {Title, Severity, ResourceType}'
```

---

### Sysdig Secure

#### Setup

1. **Connect AWS Account**
   - Integrations → Cloud Accounts → AWS
   - Deploy via Terraform or CloudFormation

2. **Install Sysdig Agent** (for runtime)
   - Add to user_data for Linux instances
   - Enable container image scanning

#### Expected Detections

| Scenario | Detection Type |
|----------|---------------|
| linux-misconfig-web | Posture violations, Runtime anomalies |
| docker-container-host | Container runtime violations, Privileged container |

#### Validation

```bash
# Check Sysdig Secure:
# - Posture → Compliance → CIS Benchmarks
# - Runtime → Runtime Policies → Violations
```

---

## Multi-Platform Validation Matrix

| Finding | Wiz | Prisma | CrowdStrike | Lacework | Orca | Security Hub | Sysdig |
|---------|-----|--------|-------------|----------|------|--------------|--------|
| IMDSv1 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Unencrypted EBS | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| No MFA | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Public RDP/SSH | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Root container | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Exposed secrets | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Outdated packages | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ |

## Testing Workflow

### 1. Baseline Scan

Before deploying CloudVuln, establish a baseline:

```bash
# Document existing findings
# Take screenshots of current posture score
# Note any pre-existing violations
```

### 2. Deploy Scenarios

```bash
# Deploy one scenario at a time for clear attribution
make deploy-iam-user-risk
```

### 3. Wait for Detection

Different platforms have different scan frequencies:

| Platform | Scan Frequency | Wait Time |
|----------|---------------|-----------|
| Wiz | 5-15 minutes | 15 min |
| Prisma Cloud | 10-30 minutes | 30 min |
| CrowdStrike | 5-10 minutes | 15 min |
| Lacework | 15-30 minutes | 30 min |
| Orca | 10-20 minutes | 20 min |
| Security Hub | 1-12 hours | 1 hour |
| Sysdig | 5-15 minutes | 15 min |

### 4. Validate Detections

Check that findings include:
- Correct resource identification
- Accurate severity rating
- Remediation guidance
- Compliance framework mapping

### 5. Test Remediation

```bash
# Tear down to test if findings clear
make teardown-iam-user-risk

# Wait for scan
# Verify finding status changes to "Resolved"
```

## Automated Validation Script

```bash
#!/usr/bin/env bash
# validate-cnapp-detection.sh

SCENARIO="$1"
PLATFORM="$2"
WAIT_TIME="${3:-600}"  # Default 10 minutes

echo "Deploying $SCENARIO..."
make deploy-"$SCENARIO"

echo "Waiting $WAIT_TIME seconds for $PLATFORM to scan..."
sleep "$WAIT_TIME"

echo "Check your $PLATFORM dashboard for findings"
echo "Expected detections for $SCENARIO:"
cat "docs/expected-findings-${SCENARIO}.txt"

read -p "Were all expected findings detected? (y/n): " detected

if [ "$detected" = "y" ]; then
  echo "✅ Detection validated!"
else
  echo "❌ Some findings not detected. Review CNAPP configuration."
fi

read -p "Tear down scenario? (y/n): " teardown
if [ "$teardown" = "y" ]; then
  make teardown-"$SCENARIO"
fi
```

## Troubleshooting

### No Detections Appearing

1. **Check account connection**
   ```bash
   # Verify CNAPP platform has access to AWS account
   aws sts get-caller-identity
   ```

2. **Verify scanning is enabled**
   - Check CNAPP console for scan status
   - Ensure region is covered

3. **Check tags**
   - Verify resources are tagged correctly
   - Use `owner` tag to filter

4. **Wait longer**
   - Some platforms take up to 1 hour for first scan
   - Check platform documentation for scan frequency

### False Negatives

If expected findings don't appear:

1. **Check policy coverage**
   - Some platforms may not have all policies enabled
   - Enable CIS Benchmark policies

2. **Verify permissions**
   - CNAPP platform may lack IAM permissions
   - Review CloudFormation/Terraform outputs

3. **Check exclusions**
   - Ensure CloudVuln resources aren't excluded
   - Review suppression rules

### Performance Issues

If scans are slow:

1. **Reduce scope**
   - Deploy one scenario at a time
   - Limit to one region

2. **Check resource limits**
   - Some platforms have API rate limits
   - Verify you're within platform quotas

## Best Practices

1. **Tag Consistently**
   - Always use `owner` tag
   - Add `test` or `cloudvuln` tag

2. **Document Findings**
   - Screenshot all detections
   - Record timestamps
   - Note any false positives/negatives

3. **Test Regularly**
   - Run monthly validation
   - Test after CNAPP platform updates
   - Verify new detections

4. **Clean Up**
   - Always tear down after testing
   - Verify resources are deleted
   - Check for orphaned findings

## Integration APIs

Most platforms provide APIs for automation:

- **Wiz**: GraphQL API
- **Prisma Cloud**: REST API
- **CrowdStrike**: Falcon API
- **Lacework**: REST API v2
- **AWS Security Hub**: AWS API (boto3)

See each platform's API documentation for details.

## Reporting

Generate validation reports:

```bash
# Create validation report
cat > cloudvuln-validation-report.md <<EOF
# CNAPP Validation Report

**Date**: $(date)
**Platform**: Wiz
**Tester**: $(whoami)

## Scenarios Tested

- [x] iam-user-risk
- [x] linux-misconfig-web
- [x] windows-vuln-iis
- [x] docker-container-host

## Detection Results

| Scenario | Expected Findings | Detected | % Coverage |
|----------|------------------|----------|------------|
| iam-user-risk | 4 | 4 | 100% |
| linux-misconfig-web | 6 | 5 | 83% |

## Notes

- All critical findings detected
- One medium severity finding missed (directory browsing)

EOF
```

## Additional Resources

- [Wiz Documentation](https://docs.wiz.io)
- [Prisma Cloud Docs](https://docs.paloaltonetworks.com/prisma/prisma-cloud)
- [CrowdStrike Docs](https://falcon.crowdstrike.com/documentation)
- [Lacework Docs](https://docs.lacework.com)
- [Orca Security Docs](https://docs.orca.security)
- [AWS Security Hub User Guide](https://docs.aws.amazon.com/securityhub/)
- [Sysdig Docs](https://docs.sysdig.com)

---

**Need help?** Open an issue at https://github.com/adilio/CloudVuln/issues
