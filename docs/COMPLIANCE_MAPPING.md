# CloudVuln Compliance Framework Mapping

This document maps CloudVuln security misconfigurations to major compliance frameworks and security standards.

## Overview

CloudVuln scenarios are designed to trigger detections across multiple compliance frameworks including:

- **CIS AWS Foundations Benchmark**
- **NIST Cybersecurity Framework**
- **PCI-DSS** (Payment Card Industry Data Security Standard)
- **HIPAA** (Health Insurance Portability and Accountability Act)
- **SOC 2**
- **ISO 27001**
- **GDPR** (General Data Protection Regulation)

## Scenario-by-Scenario Mapping

### Act I: IAM User Risk (iam-user-risk)

| Misconfiguration | CIS AWS | NIST CSF | PCI-DSS | HIPAA | SOC 2 | ISO 27001 |
|------------------|---------|----------|---------|-------|-------|-----------|
| No MFA enabled | 1.12, 1.13, 1.14 | PR.AC-1 | 8.3 | 164.312(a)(2)(i) | CC6.1 | A.9.4.2 |
| Multiple access keys | 1.3 | PR.AC-1 | 8.2.3 | 164.312(d) | CC6.1 | A.9.2.4 |
| Overly permissive IAM policy | 1.16 | PR.AC-4 | 7.1.2 | 164.308(a)(3) | CC6.3 | A.9.2.3 |
| Weak password policy | 1.5-1.11 | PR.AC-1 | 8.2.3 | 164.308(a)(5)(ii)(D) | CC6.1 | A.9.4.3 |

**Compliance Impact:**
- **CIS Benchmark**: Fails 4+ controls
- **NIST**: Inadequate access control (PR.AC)
- **PCI-DSS**: Requirement 8 violations (access management)
- **HIPAA**: Administrative safeguards violations
- **SOC 2**: Control environment failures (CC6 domain)

### Act II: DSPM Data Generator (dspm-data-generator)

| Misconfiguration | GDPR | PCI-DSS | HIPAA | SOC 2 | ISO 27001 |
|------------------|------|---------|-------|-------|-----------|
| Unencrypted sensitive data | Art. 32 | 3.4, 4.1 | 164.312(a)(2)(iv) | CC6.7 | A.10.1.1 |
| Public S3 bucket (if uploaded) | Art. 32 | 1.2.1 | 164.308(a)(4) | CC6.6 | A.13.1.3 |
| PII/PHI without protection | Art. 5, 32 | 3.2, 3.4 | 164.502(a) | CC6.7 | A.18.1.3 |
| No data classification | - | 9.2 | 164.308(a)(1)(ii)(B) | CC6.7 | A.8.2.1 |

**Compliance Impact:**
- **GDPR**: Data protection failures (Article 32)
- **PCI-DSS**: Requirement 3 violations (protect stored cardholder data)
- **HIPAA**: Privacy Rule and Security Rule violations
- **SOC 2**: Confidentiality criteria failures

###Act III: Linux Misconfigured Web Server (linux-misconfig-web)

| Misconfiguration | CIS AWS | NIST CSF | PCI-DSS | HIPAA | SOC 2 | ISO 27001 |
|------------------|---------|----------|---------|-------|-------|-----------|
| IMDSv1 enabled | 4.1 | PR.AC-5 | 2.2.2 | 164.312(a)(1) | CC6.6 | A.9.4.1 |
| Unencrypted EBS | 2.2.1 | PR.DS-1 | 3.4.1 | 164.312(a)(2)(iv) | CC6.7 | A.10.1.1 |
| Public SSH/HTTP access | 4.1, 4.2 | PR.AC-5 | 1.2.1 | 164.312(e)(1) | CC6.6 | A.13.1.1 |
| Outdated OS/packages | - | PR.IP-12 | 6.2 | 164.308(a)(5)(ii)(B) | CC7.1 | A.12.6.1 |
| No security updates | 3.6 | PR.IP-12 | 6.2 | 164.308(a)(5)(ii)(B) | CC7.1 | A.12.6.1 |
| Exposed API keys | - | PR.DS-5 | 3.4 | 164.312(a)(2)(iv) | CC6.7 | A.10.1.2 |

**Compliance Impact:**
- **CIS Benchmark**: Fails 6+ controls
- **NIST**: Protective technology failures (PR.PT, PR.DS)
- **PCI-DSS**: Requirement 2, 3, 6 violations
- **HIPAA**: Technical safeguards violations
- **SOC 2**: System operations and change management failures

### Act IV: Windows Vulnerable IIS (windows-vuln-iis)

| Misconfiguration | CIS AWS | NIST CSF | PCI-DSS | HIPAA | SOC 2 | ISO 27001 |
|------------------|---------|----------|---------|-------|-------|-----------|
| Public RDP access | 4.1, 4.2 | PR.AC-5 | 1.2.1, 2.2.2 | 164.312(e)(1) | CC6.6 | A.13.1.1 |
| IMDSv1 enabled | 4.1 | PR.AC-5 | 2.2.2 | 164.312(a)(1) | CC6.6 | A.9.4.1 |
| Unencrypted EBS | 2.2.1 | PR.DS-1 | 3.4.1 | 164.312(a)(2)(iv) | CC6.7 | A.10.1.1 |
| Outdated Windows Server | - | PR.IP-12 | 6.2 | 164.308(a)(5)(ii)(B) | CC7.1 | A.12.6.1 |
| IIS directory browsing | - | PR.AC-5 | 2.2.2 | 164.312(a)(1) | CC6.6 | A.9.4.1 |
| Exposed canary files | - | PR.DS-5 | 3.4 | 164.312(a)(2)(iv) | CC6.7 | A.10.1.2 |

**Compliance Impact:**
- **CIS Benchmark**: Fails 5+ controls
- **NIST**: Access control and data security failures
- **PCI-DSS**: Requirements 1, 2, 3, 6 violations
- **HIPAA**: Technical and administrative safeguards violations
- **SOC 2**: Security and availability failures

### Act V: Docker Container Host (docker-container-host)

| Misconfiguration | CIS Docker | NIST CSF | PCI-DSS | HIPAA | SOC 2 | ISO 27001 |
|------------------|------------|----------|---------|-------|-------|-----------|
| Container runs as root | 4.1 | PR.AC-4 | 2.2.4 | 164.312(a)(1) | CC6.6 | A.9.4.5 |
| Host networking mode | 5.9 | PR.AC-5 | 1.2.1 | 164.312(e)(1) | CC6.6 | A.13.1.1 |
| Host /etc mounted | 5.4, 5.5 | PR.AC-5 | 2.2.4 | 164.308(a)(3)(i) | CC6.6 | A.9.4.5 |
| IMDSv1 accessible | 4.1 (AWS) | PR.AC-5 | 2.2.2 | 164.312(a)(1) | CC6.6 | A.9.4.1 |
| Unencrypted EBS | 2.2.1 (AWS) | PR.DS-1 | 3.4.1 | 164.312(a)(2)(iv) | CC6.7 | A.10.1.1 |
| No capability restrictions | 5.3 | PR.PT-3 | 2.2.4 | 164.312(a)(1) | CC6.6 | A.13.1.3 |

**Compliance Impact:**
- **CIS Docker Benchmark**: Fails 6+ container controls
- **NIST**: Identity management and platform security failures
- **PCI-DSS**: Requirement 2 violations (secure configurations)
- **HIPAA**: Access control violations
- **SOC 2**: Logical access control failures

## Framework-Specific Summaries

### CIS AWS Foundations Benchmark

CloudVuln triggers detection for these CIS control categories:

| Section | Controls Violated | Scenarios |
|---------|------------------|-----------|
| 1.0 Identity and Access Management | 1.3, 1.5-1.16 | Act I |
| 2.0 Storage | 2.2.1 | Acts III, IV, V |
| 3.0 Logging | 3.6 | Acts III, IV |
| 4.0 Networking | 4.1, 4.2 | Acts III, IV, V |

**Overall CIS Compliance Score**: Intentionally fails 15+ controls

### NIST Cybersecurity Framework

CloudVuln addresses these NIST CSF functions:

| Function | Categories | Detection Rate |
|----------|-----------|----------------|
| Identify (ID) | Asset Management | Medium |
| Protect (PR) | Access Control, Data Security | **High** |
| Detect (DE) | Anomalies and Events | **High** |
| Respond (RS) | Response Planning | Medium |
| Recover (RC) | Recovery Planning | Low |

**Primary Focus**: Protect (PR) and Detect (DE) functions

### PCI-DSS v3.2.1

CloudVuln creates violations in these PCI-DSS requirements:

| Requirement | Description | Scenarios |
|------------|-------------|-----------|
| 1 | Firewall Configuration | Acts III, IV, V |
| 2 | Default Passwords/Security Parameters | Acts III, IV, V |
| 3 | Protect Stored Cardholder Data | Acts II, III, IV |
| 6 | Secure Systems and Applications | Acts III, IV |
| 7 | Restrict Access by Business Need | Act I |
| 8 | Identify and Authenticate Access | Act I |
| 9 | Restrict Physical Access | Act II |

**PCI-DSS Compliance**: Fails 7/12 major requirements

### HIPAA Security Rule

CloudVuln violates these HIPAA safeguard categories:

| Safeguard Type | Standard | Scenarios |
|----------------|----------|-----------|
| Administrative | Access Control (§164.308(a)(3)) | Act I |
| Administrative | Security Management Process (§164.308(a)(1)) | Acts II, III, IV |
| Physical | Workstation Security (§164.310(c)) | Acts III, IV, V |
| Technical | Access Control (§164.312(a)(1)) | Acts I, III, IV, V |
| Technical | Transmission Security (§164.312(e)(1)) | Acts III, IV |

**HIPAA Compliance**: Violates 5+ security standards

### SOC 2 Trust Service Criteria

| Criterion | Description | Scenarios |
|-----------|-------------|-----------|
| CC6.1 | Logical and Physical Access Controls | Acts I, III, IV, V |
| CC6.6 | Logical Access - Restricts Access | Acts III, IV, V |
| CC6.7 | Logical Access - Encryption | Acts II, III, IV, V |
| CC7.1 | System Operations - Detects Changes | Acts III, IV |

**SOC 2 Impact**: Common Criteria (CC) domain failures

### ISO/IEC 27001:2013

| Annex A Control | Description | Scenarios |
|-----------------|-------------|-----------|
| A.9.2.3 | Management of privileged access rights | Act I |
| A.9.4.1 | Information access restriction | Acts III, IV, V |
| A.9.4.2 | Secure log-on procedures | Act I |
| A.10.1.1 | Policy on use of cryptographic controls | Acts II, III, IV, V |
| A.12.6.1 | Management of technical vulnerabilities | Acts III, IV |
| A.13.1.1 | Network controls | Acts III, IV, V |
| A.18.1.3 | Protection of records | Act II |

**ISO 27001 Compliance**: Fails 7+ controls across 5 domains

### GDPR (General Data Protection Regulation)

| Article | Principle | Scenarios |
|---------|-----------|-----------|
| Art. 5 | Data Processing Principles | Act II |
| Art. 25 | Data Protection by Design | Acts II, III, IV |
| Art. 32 | Security of Processing | All Acts |
| Art. 33 | Breach Notification | All Acts |

**GDPR Compliance**: Data protection and security violations

## Using CloudVuln for Compliance Testing

### Audit Preparation

1. **Pre-Audit Validation**
   - Deploy scenarios to verify your security tools detect violations
   - Test detection coverage for each framework
   - Validate alerting and response procedures

2. **Control Testing**
   - Use CloudVuln to demonstrate detective controls work
   - Show preventive controls block similar deployments in production
   - Document remediation procedures

3. **Evidence Collection**
   - CNAPP detection screenshots
   - Alert notifications
   - Automated response workflows
   - Remediation timelines

### Framework-Specific Testing

#### For PCI-DSS Assessments

```bash
# Deploy scenarios that test PCI requirements
make deploy-linux-misconfig-web   # Tests Req 1, 2, 3, 6
make deploy-iam-user-risk         # Tests Req 7, 8
make test-validation              # Verify detection
```

#### For HIPAA Assessments

```bash
# Test technical safeguards
make deploy-iam-user-risk         # Access Control
make deploy-dspm-data-generator   # PHI Protection
./tests/validation/validate_iam_risks.sh
```

#### For SOC 2 Audits

```bash
# Test Common Criteria (CC) controls
make deploy-all                   # CC6, CC7 controls
make test-validation              # Verify monitoring
```

## Compliance Report Generation

CloudVuln can assist in generating compliance evidence:

1. **Deploy scenarios**
2. **Run validation tests**
3. **Capture CNAPP detection screenshots**
4. **Document findings**
5. **Show remediation** (via teardown)

## Limitations

CloudVuln is a **testing tool**, not a compliance solution:

- ❌ Does not provide compliance certification
- ❌ Does not replace security assessments
- ❌ Does not guarantee regulatory approval
- ✅ Validates detective controls
- ✅ Tests security tool coverage
- ✅ Demonstrates security awareness
- ✅ Supports audit preparation

## Additional Resources

- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [PCI-DSS Requirements](https://www.pcisecuritystandards.org)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)
- [SOC 2 Trust Service Criteria](https://www.aicpa.org/soc)
- [ISO/IEC 27001](https://www.iso.org/isoiec-27001-information-security.html)
- [GDPR](https://gdpr-info.eu)

---

**Disclaimer**: This mapping is provided for educational purposes. Consult with compliance professionals for official assessments.
