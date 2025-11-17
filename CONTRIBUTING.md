# Contributing to CloudVuln

Thank you for your interest in contributing to CloudVuln! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Coding Standards](#coding-standards)
- [Project Structure](#project-structure)

## Code of Conduct

This project follows a simple code of conduct:
- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Remember this is an intentionally vulnerable lab environment

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Git** for version control
- **Terraform** (>= 1.5.0) for infrastructure as code
- **AWS CLI** (>= 2.0) configured with credentials
- **Bash** (>= 4.0) for scripting
- **Make** for running common tasks
- **jq** for JSON processing
- **bats** for unit testing (optional but recommended)
- **shellcheck** for bash linting (optional but recommended)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/CloudVuln.git
   cd CloudVuln
   ```
3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/original-repo/CloudVuln.git
   ```

## Development Setup

### 1. Install Dependencies

```bash
# On macOS
brew install terraform awscli jq shellcheck bats-core

# On Linux (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y jq shellcheck
# Install Terraform and AWS CLI separately
```

Or use the Makefile:

```bash
make install
```

### 2. Configure Development Environment

```bash
# Setup repository
make setup

# Run health check
./tools/health-check.sh

# Check dependencies
make check-deps
```

### 3. Configure AWS Credentials

```bash
aws configure
# Enter your AWS access key, secret key, and default region
```

**Important:** Use a non-production AWS account for testing!

### 4. Install Pre-commit Hooks (Recommended)

```bash
pip install pre-commit
pre-commit install
```

This automatically runs linting and validation before each commit.

## Making Changes

### Branching Strategy

- `main` - Stable, production-ready code
- `develop` - Development branch for new features
- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates

### Creating a Feature Branch

```bash
git checkout -b feature/your-feature-name develop
```

### Types of Contributions

#### 1. Adding a New Scenario

To add a new security scenario:

1. Create a new directory: `act-X-scenario-name/`
2. Required files:
   - `main.tf` - Terraform infrastructure
   - `vars.tf` - Variable definitions
   - `deploy.sh` - Deployment script
   - `teardown.sh` - Cleanup script
   - `README.md` - Scenario documentation
   - `user_data.sh` or `user_data.ps1` - Bootstrap script (if EC2)

3. Follow the naming convention: `act-N-description` (e.g., `act-vi-serverless-misconfig`)

4. Document CNAPP coverage (CSPM, CDR, CIEM, DSPM, CWPP)

5. Add cost estimates to `tools/cost-estimate.sh`

6. Create validation tests in `tests/validation/`

#### 2. Improving Existing Scenarios

- Add more misconfigurations
- Improve documentation
- Optimize costs
- Enhance user_data scripts

#### 3. Adding Tests

- **Unit tests**: `tests/unit/*.bats`
- **Integration tests**: `tests/integration/*.sh`
- **Validation tests**: `tests/validation/*.sh`

#### 4. Enhancing Tooling

- Improve menu.sh TUI
- Add new utility scripts in `tools/`
- Enhance Makefile targets

#### 5. Improving Documentation

- Update README.md
- Enhance scenario READMEs
- Add examples and screenshots
- Fix typos and clarify instructions

## Testing

### Run All Tests

```bash
make test
```

### Run Specific Test Suites

```bash
# Unit tests only
make test-unit

# Integration tests (Terraform validation)
make test-integration

# Validation tests (requires deployed infrastructure)
make test-validation
```

### Manual Testing

```bash
# Test a specific scenario
make deploy-iam-user-risk
make teardown-iam-user-risk

# Validate Terraform
make validate-all

# Run health check
./tools/health-check.sh
```

### Writing Tests

#### Unit Test Example (bats)

```bash
#!/usr/bin/env bats
# tests/unit/test_example.bats

@test "function returns expected value" {
  source lib/checks.sh
  result=$(some_function "arg")
  [ "$result" = "expected" ]
}
```

#### Integration Test Example

```bash
#!/usr/bin/env bash
# tests/integration/test_scenario.sh

source tests/helpers/test_helpers.sh

test_scenario() {
  cd scenario-name
  terraform init -backend=false
  terraform validate
}

test_scenario
```

## Submitting Changes

### Before Submitting

1. **Run tests**:
   ```bash
   make test
   ```

2. **Run linting**:
   ```bash
   make lint
   ```

3. **Format Terraform**:
   ```bash
   make format
   ```

4. **Check pre-commit**:
   ```bash
   make pre-commit
   ```

5. **Update documentation** if needed

### Creating a Pull Request

1. Push your changes:
   ```bash
   git push origin feature/your-feature-name
   ```

2. Create a pull request on GitHub

3. Fill out the PR template:
   - **Description**: What does this PR do?
   - **Motivation**: Why is this change needed?
   - **Testing**: How was it tested?
   - **Checklist**: Complete all items

4. Wait for CI checks to pass

5. Address review feedback

### Pull Request Checklist

- [ ] Code follows project style guidelines
- [ ] Tests added/updated as needed
- [ ] All tests pass locally
- [ ] Documentation updated
- [ ] Commit messages are clear and descriptive
- [ ] No sensitive data in commits
- [ ] Pre-commit hooks pass
- [ ] CHANGELOG.md updated (for significant changes)

## Coding Standards

### Bash Scripts

- Use `#!/usr/bin/env bash` shebang
- Enable strict mode: `set -euo pipefail`
- Use shellcheck for linting
- Add comments for complex logic
- Use meaningful variable names
- Follow Google Shell Style Guide

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Function: deploy_scenario
# Description: Deploys a CloudVuln scenario
# Arguments: $1 - scenario name
deploy_scenario() {
  local scenario="$1"

  if [ -z "$scenario" ]; then
    echo "Error: scenario name required"
    return 1
  fi

  # Implementation
}
```

### Terraform

- Use Terraform 1.5.0+ syntax
- Run `terraform fmt` before committing
- Use descriptive resource names
- Add comments for intentional misconfigurations
- Tag all resources with `owner` and `scenario`

Example:

```hcl
# Intentionally insecure: IMDSv1 enabled for CSPM detection
resource "aws_instance" "vulnerable" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"  # IMDSv1 - security finding
  }

  tags = {
    owner    = var.owner
    scenario = var.scenario
  }
}
```

### Documentation

- Use Markdown format
- Include code examples
- Add screenshots where helpful
- Keep line length reasonable (~80-100 chars)
- Use proper heading hierarchy
- Include TOC for long documents

### Git Commits

Follow conventional commit format:

```
type(scope): subject

body

footer
```

Types:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `test:` Tests
- `refactor:` Code refactoring
- `chore:` Maintenance tasks

Examples:

```
feat(linux-misconfig-web): add exposed API keys for DSPM detection

- Generate runtime fake API keys
- Expose keys via nginx web server
- Update validation tests

Closes #123
```

## Project Structure

```
CloudVuln/
├── README.md                    # Main documentation
├── CONTRIBUTING.md              # This file
├── Makefile                     # Common operations
├── menu.sh                      # Interactive TUI
├── cleanup-all.sh               # Teardown all scenarios
├── common_vars.tf               # Shared variables
│
├── lib/                         # Shared libraries
│   └── checks.sh                # Preflight checks
│
├── docs/                        # Documentation
│   ├── ARCHITECTURE.md          # Design docs
│   └── QUICKSTART.md            # Quick start guide
│
├── tools/                       # Utility scripts
│   ├── cost-estimate.sh         # Cost calculator
│   ├── health-check.sh          # Environment validator
│   └── run-tests.sh             # Test runner
│
├── tests/                       # Test suite
│   ├── unit/                    # Unit tests (bats)
│   ├── integration/             # Integration tests
│   ├── validation/              # Validation tests
│   └── helpers/                 # Test utilities
│
├── .github/                     # GitHub configuration
│   └── workflows/               # CI/CD pipelines
│
└── [scenarios]/                 # Security scenarios
    ├── main.tf
    ├── vars.tf
    ├── deploy.sh
    ├── teardown.sh
    └── README.md
```

## Questions?

- Open an issue for questions
- Join discussions
- Check existing issues and PRs
- Review documentation

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to CloudVuln! 🎉
