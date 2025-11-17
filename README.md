# ☁️ ctxcloud-testing — AWS CNAPP Breach Simulation Lab

## 📖 Overview
`ctxcloud-testing` is a modular **AWS** lab environment built with **Terraform** and **Bash** to simulate security risks across **CNAPP** domains:
- **CSPM** — Cloud Security Posture Management
- **CDR** — Cloud Detection & Response
- **CIEM** — Cloud Infrastructure Entitlement Management
- **DSPM** — Data Security Posture Management
- **CWPP** — Cloud Workload Protection Platform

The lab deploys self-contained scenarios representing high-signal misconfigurations and realistic breaches, allowing you to **validate detections** and **train incident response workflows**.

---

## 🎯 Purpose
This lab follows a progressive **breach simulation narrative**:
1. **Act I — Identity Compromise (`iam-user-risk`)**  
2. **Act II — Sensitive Data Creation (`dspm-data-generator`)**  
3. **Act III — Infrastructure Misconfiguration (Linux) (`linux-misconfig-web`)**  
4. **Act IV — Infrastructure Misconfiguration (Windows) (`windows-vuln-iis`)**  
5. **Act V — Container & Host Exploitation (`docker-container-host`)**  

Each act builds upon the last, simulating an attacker moving laterally through IAM gaps, data exposure, workload exploitation, and ultimately full container/host compromise.

---

## 📦 Repository Structure
```
./
├── cleanup-all.sh            # Destroys all scenarios
├── common_vars.tf            # Shared Terraform variables across scenarios
├── docker-container-host/    # Act V — CWPP misconfiguration scenario
├── docs/                     # Architecture & quickstart guides
├── dspm-data-generator/      # Act II — DSPM sensitive data generation
├── iam-user-risk/            # Act I — IAM misconfiguration
├── lib/                      # Shared preflight checks and helpers
├── linux-misconfig-web/      # Act III — Linux workload misconfigurations
├── menu.sh                   # Interactive TUI for scenario control
└── windows-vuln-iis/         # Act IV — Windows workload misconfigurations
```

---

## 🧭 Choosing a Scenario
You can deploy scenarios individually for focused validation, or follow the **full breach storyline** for end-to-end simulation:

| Sequence | Scenario                  | When to Use |
|----------|---------------------------|-------------|
| Act I    | `iam-user-risk`           | Start here to simulate baseline IAM misconfigurations (no MFA, excess keys, broad policy). |
| Act II   | `dspm-data-generator`     | Add sensitive-looking data for later exfiltration scenarios. |
| Act III  | `linux-misconfig-web`     | Simulate a Linux workload accessible publicly with risky settings. |
| Act IV   | `windows-vuln-iis`        | Explore Windows + IIS exposure in parallel to Linux exploitation. |
| Act V    | `docker-container-host`   | Conclude with container/host-level misconfigurations. |

---

## 🛡️ Environment Safety & Cost Controls
- **Run in a dedicated non-production AWS account**—these deployments are insecure by design.
- AWS charges may apply for running EC2 instances, S3 storage, and IAM objects.
- Always run:
```bash
./cleanup-all.sh
```
after testing to remove all resources and avoid unwanted costs.

---

## 🔍 Validation & Detection Tips
- Each scenario's `README.md` includes validation commands for common CLI-based checks.
- For security tool integration (e.g., Security Hub, CNAPP platforms), look for:
  - Public SG / port exposures
  - IMDSv1 accessibility
  - Unencrypted EBS volumes
  - Sensitive data object access logs

---

## ⚙️ Customizing Variables
You can change deployment defaults via:
1. Editing [`common_vars.tf`](common_vars.tf)
2. Setting environment variables before running `menu.sh`:
```bash
export TF_VAR_owner="myname"
export TF_VAR_aws_region="us-west-2"
export TF_VAR_allow_ssh_cidr="203.0.113.5/32"
```
3. Passing `TF_VAR_*` flags directly to Terraform (advanced use).

---

## 🤖 Running Without TUI
You can run scenarios in non-interactive mode for automation pipelines or scripted demos:
```bash
./menu.sh --run linux-misconfig-web deploy
./menu.sh --run linux-misconfig-web teardown
```
Combine multiple in sequence to simulate the full narrative.

---

## 🛠️ Troubleshooting
| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| `AWS credentials invalid or missing` | AWS CLI is not configured | Run `aws configure` and reauth. |
| `Terraform not installed` | Missing Terraform binary | Install from developer.hashicorp.com/terraform/downloads |
| SSH connection refused | SG/CIDR misconfig | Check menu prompt settings (if applicable); note that scenarios without EC2 skip SSH CIDR prompts |
| Validation command returns `N/A` | Output not defined for scenario | Only some scenarios define DNS/IP outputs; check README for alternatives |

## 🚀 Quick Start

### 1️⃣ Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform installed
- Valid AWS credentials
- Permission to create/destroy EC2, IAM, and S3 resources

### 2️⃣ Menu-Driven Usage
```bash
cd .
./menu.sh
```
Interactive **TUI** will:
- Run preflight checks
- Detect your public IP for secure SSH/RDP
- List available scenarios for deploy/teardown/info

### 3️⃣ Non-Interactive
```bash
./menu.sh --run <scenario> deploy
./menu.sh --run <scenario> teardown
```

---

## 🧩 Scenarios

| Scenario                  | Purpose                                                    | Key Risks |
|---------------------------|------------------------------------------------------------|-----------|
| `iam-user-risk`           | IAM user risk baseline (**CIEM**)                          | No MFA, excessive keys, broad policy |
| `dspm-data-generator`     | Sensitive-looking data generation and optional S3 upload (**DSPM**) | PII/PCI/PHI/secrets exposure |
| `linux-misconfig-web`     | Misconfigured Linux web workload (**CSPM/CDR**)            | Public SG, IMDSv1, unencrypted EBS, outdated OS |
| `windows-vuln-iis`        | Misconfigured Windows Server + IIS (**CSPM/CDR**)          | Public RDP, IMDSv1, unencrypted EBS, web-root canary |
| `docker-container-host`   | Risky containerized workload (**CWPP/CSPM**)               | Root container, host mounts, host net, IMDSv1 |

---

## 🗑️ Cleanup
From the root:
```bash
./cleanup-all.sh
```
From a scenario:
```bash
cd <scenario>
./teardown.sh
```

---

## 🧪 Testing & Development

CloudVuln includes a comprehensive test suite to ensure reliability and quality.

### Quick Testing

```bash
# Run all tests
make test

# Run specific test suites
make test-unit              # Unit tests (bats)
make test-integration       # Integration tests (Terraform validation)
make test-validation        # Validation tests (requires deployed infrastructure)

# Run health check
./tools/health-check.sh

# Estimate costs
./tools/cost-estimate.sh
```

### Test Coverage

- **Unit Tests**: Bash function testing with bats
- **Integration Tests**: Terraform syntax and configuration validation
- **Validation Tests**: Verify deployed infrastructure has expected misconfigurations
- **CI/CD**: Automated testing via GitHub Actions

See [tests/README.md](tests/README.md) for detailed testing documentation.

### Makefile Commands

Common operations available via `make`:

```bash
make help                   # Show all available commands
make check-deps             # Check if dependencies are installed
make setup                  # Setup environment and make scripts executable
make validate-all           # Validate all Terraform configurations
make lint                   # Lint bash scripts with shellcheck
make format                 # Format Terraform files
make cost-estimate          # Estimate infrastructure costs
make status                 # Show deployment status for all scenarios
make clean                  # Clean up temporary files
```

### Development Tools

Located in `tools/`:

- **cost-estimate.sh**: Calculate monthly AWS costs for scenarios
- **health-check.sh**: Validate environment and dependencies
- **run-tests.sh**: Unified test runner for all test suites

### CI/CD Pipeline

GitHub Actions workflows automatically:
- Lint and validate code on every push
- Run unit and integration tests
- Perform security scanning with tfsec and Trivy
- Validate Terraform configurations
- Check documentation quality

See [.github/workflows/test.yml](.github/workflows/test.yml) for configuration.

### Pre-commit Hooks

Install pre-commit hooks for automatic validation:

```bash
pip install pre-commit
pre-commit install
```

Hooks will automatically:
- Format Terraform files
- Lint bash scripts
- Check for secrets
- Validate YAML/JSON syntax
- Run security scans

---

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development setup instructions
- Coding standards and best practices
- How to add new scenarios
- Testing requirements
- Pull request process

---

## 📚 Additional Resources

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Scenario design, threat model, CNAPP mapping
- [docs/QUICKSTART.md](docs/QUICKSTART.md) — Setup and usage instructions
- [tests/README.md](tests/README.md) — Testing guide and test documentation
- [CONTRIBUTING.md](CONTRIBUTING.md) — Contribution guidelines
- [CHANGELOG.md](CHANGELOG.md) — Version history and changes

---

## 📊 Cost Transparency

Estimated monthly costs (us-east-1):
- **Act I (IAM)**: $0.00 (Free tier)
- **Act II (DSPM)**: $0.00 (No EC2, optional S3)
- **Act III (Linux)**: ~$20-25 (t3.medium + EBS)
- **Act IV (Windows)**: ~$30-35 (t3.medium Windows + EBS)
- **Act V (Docker)**: ~$20-25 (t3.medium + EBS)

**Total for all scenarios**: ~$70-85/month

**Cost optimization tips**:
- Deploy scenarios individually as needed
- Use `terraform destroy` when finished testing
- Consider t3.micro for non-production testing
- Run `./tools/cost-estimate.sh` for detailed breakdown

---

**⚠️ Security Notice:**
These scenarios intentionally deploy **vulnerable configurations**.
Do **not** run in production AWS accounts or with sensitive data.