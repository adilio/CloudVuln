# CloudVuln Test Suite

This directory contains comprehensive tests for the CloudVuln security simulation lab.

## Test Structure

```
tests/
├── unit/                          # Unit tests for bash scripts
│   ├── test_checks.bats          # Tests for lib/checks.sh
│   ├── test_menu.bats            # Tests for menu.sh functions
│   └── test_deploy_scripts.bats # Tests for scenario deploy scripts
├── integration/                   # Integration tests for Terraform
│   ├── terraform_syntax_test.sh  # Terraform validation tests
│   ├── terraform_plan_test.sh    # Terraform plan tests
│   └── scenarios/                # Per-scenario integration tests
│       ├── test_iam_user_risk.sh
│       ├── test_dspm_data.sh
│       ├── test_linux_misconfig.sh
│       ├── test_windows_vuln.sh
│       └── test_docker_host.sh
├── validation/                    # Security misconfiguration validation
│   ├── validate_iam_risks.sh     # Validate IAM misconfigurations
│   ├── validate_cspm.sh          # Validate CSPM detections
│   ├── validate_dspm.sh          # Validate DSPM findings
│   └── validate_cwpp.sh          # Validate CWPP detections
├── helpers/                       # Test helper functions
│   ├── test_helpers.sh           # Common test utilities
│   ├── aws_helpers.sh            # AWS API helpers for validation
│   └── mock_helpers.sh           # Mock utilities for unit tests
└── fixtures/                      # Test fixtures and mock data
    ├── mock_terraform_output.json
    └── sample_aws_responses/

## Test Types

### 1. Unit Tests (using bats)

Unit tests verify individual bash functions and script logic without requiring AWS credentials or Terraform.

**Requirements:**
- [bats-core](https://github.com/bats-core/bats-core) - Bash Automated Testing System
- bats-support - Helper library
- bats-assert - Assertion library

**Installation:**
```bash
# Install bats on macOS
brew install bats-core

# Install on Linux
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

**Running Unit Tests:**
```bash
# Run all unit tests
bats tests/unit/

# Run specific test file
bats tests/unit/test_checks.bats

# Verbose output
bats -t tests/unit/
```

### 2. Integration Tests

Integration tests validate Terraform configurations and AWS deployments.

**Requirements:**
- Terraform >= 1.5.0
- AWS CLI >= 2.0
- Valid AWS credentials
- Non-production AWS account

**Running Integration Tests:**
```bash
# Validate all Terraform syntax
./tests/integration/terraform_syntax_test.sh

# Run Terraform plan tests (no actual deployment)
./tests/integration/terraform_plan_test.sh

# Run full scenario integration test (deploys and tears down)
./tests/integration/scenarios/test_iam_user_risk.sh
```

### 3. Validation Tests

Validation tests check that deployed infrastructure contains the expected security misconfigurations.

**Requirements:**
- AWS CLI
- jq
- Active CloudVuln deployment

**Running Validation Tests:**
```bash
# Validate IAM misconfigurations
./tests/validation/validate_iam_risks.sh

# Validate CSPM findings
./tests/validation/validate_cspm.sh

# Run all validations
make validate-all
```

## Test Coverage Goals

- **Bash Scripts:** 90%+ function coverage
- **Terraform:** 100% syntax validation
- **Security Misconfigurations:** 100% validation coverage
- **Integration:** All 5 scenarios end-to-end tested

## Continuous Integration

Tests are automatically run on:
- Every pull request
- Every push to main branch
- Nightly scheduled runs

See `.github/workflows/test.yml` for CI configuration.

## Writing New Tests

### Adding a Unit Test

Create a new `.bats` file in `tests/unit/`:

```bash
#!/usr/bin/env bats

load '../helpers/test_helpers'

@test "function returns expected value" {
  result="$(your_function arg1 arg2)"
  [ "$result" = "expected" ]
}
```

### Adding an Integration Test

Create a new `.sh` file in `tests/integration/scenarios/`:

```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/../../helpers/test_helpers.sh"

test_scenario_deployment() {
  # Deploy
  # Validate
  # Teardown
}
```

### Adding a Validation Test

Create validation scripts that check for specific misconfigurations:

```bash
#!/usr/bin/env bash
# Validate that IMDSv1 is enabled
check_imdsv1() {
  local instance_id="$1"
  local metadata_options=$(aws ec2 describe-instances \
    --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].MetadataOptions')
  # Assert IMDSv1 is enabled
}
```

## Troubleshooting Tests

### Bats Command Not Found

```bash
# Ensure bats is installed
which bats

# Install if missing
brew install bats-core  # macOS
# or follow installation instructions above
```

### AWS Credentials

Tests requiring AWS access need valid credentials:

```bash
aws configure
aws sts get-caller-identity
```

### Test Failures

Check test logs in `tests/logs/` for detailed output.

## Best Practices

1. **Isolation:** Each test should be independent
2. **Cleanup:** Always clean up resources after integration tests
3. **Mocking:** Use mocks for unit tests to avoid AWS calls
4. **Documentation:** Document test purpose and expected behavior
5. **Fast Feedback:** Keep unit tests fast (<1s each)
6. **Safety:** Integration tests should only run in designated test environments

## Contributing

When adding new features to CloudVuln:
1. Write unit tests first (TDD)
2. Add integration tests for new scenarios
3. Add validation tests for new misconfigurations
4. Update this README if adding new test types
5. Ensure all tests pass before submitting PR

## Resources

- [Bats Documentation](https://bats-core.readthedocs.io/)
- [Terraform Testing Best Practices](https://www.terraform.io/docs/language/modules/testing-experiment.html)
- [AWS CLI Testing](https://docs.aws.amazon.com/cli/latest/reference/)
