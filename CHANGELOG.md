# Changelog

All notable changes to CloudVuln will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive test framework with unit, integration, and validation tests
- GitHub Actions CI/CD pipeline for automated testing
- Makefile with common operations and shortcuts
- Cost estimation tool (`tools/cost-estimate.sh`)
- Health check utility (`tools/health-check.sh`)
- Unified test runner (`tools/run-tests.sh`)
- Pre-commit hooks configuration for code quality
- CONTRIBUTING.md guide for contributors
- Full test coverage for bash scripts and Terraform configurations
- Validation tests for security misconfigurations (IAM, CSPM, DSPM, CWPP)
- Test documentation in `tests/README.md`
- Bats unit tests for lib/checks.sh and menu.sh functions
- Integration tests for Terraform syntax validation
- CHANGELOG.md for tracking changes

### Enhanced
- Error handling and logging throughout codebase
- Documentation structure with clear contribution guidelines
- Repository organization with tools/ directory
- Development workflow with automated checks

### Fixed
- Terraform templatefile interpolation errors
- Variable declarations for stripe_key, aws_key, github_token
- Hostname prefixing with owner variable across all scenarios

## [1.0.0] - 2024-11-17

### Added
- Initial release of CloudVuln
- 5 progressive breach simulation scenarios (Acts I-V)
- Interactive TUI menu system (`menu.sh`)
- IAM User Risk scenario (Act I - CIEM)
- DSPM Data Generator scenario (Act II - DSPM)
- Linux Misconfigured Web Server scenario (Act III - CSPM/CDR/DSPM)
- Windows Vulnerable IIS scenario (Act IV - CSPM/CDR)
- Docker Container Host scenario (Act V - CWPP/CSPM)
- Comprehensive documentation (README, ARCHITECTURE, QUICKSTART)
- Per-scenario README with validation steps
- Preflight checks library (`lib/checks.sh`)
- Cleanup scripts for individual and all scenarios
- Public IP detection for SSH CIDR restriction
- Logging system for all operations
- Terraform configurations for all scenarios
- User data scripts for EC2 bootstrapping
- Tagging strategy for resource tracking
- Safety warnings and non-production account recommendations

### Features
- **CNAPP Coverage**: CSPM, CDR, CIEM, DSPM, CWPP
- **5-Act Narrative**: Progressive breach simulation
- **Intentional Misconfigurations**:
  - IMDSv1 enabled
  - Unencrypted EBS volumes
  - Public RDP/SSH access
  - Weak IAM policies
  - Multiple access keys
  - No MFA
  - Exposed secrets
  - Outdated AMIs
  - Container misconfigurations

### Documentation
- Main README with overview and quick start
- Architecture documentation
- Quick start guide
- Per-scenario documentation
- Troubleshooting guides
- Validation command examples

---

## Version Format

**[MAJOR.MINOR.PATCH]**

- **MAJOR**: Incompatible changes or major redesigns
- **MINOR**: New scenarios, features, or significant enhancements
- **PATCH**: Bug fixes, documentation updates, minor improvements

## Categories

- **Added**: New features, scenarios, or tools
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features or scenarios
- **Fixed**: Bug fixes
- **Security**: Security-related changes
- **Enhanced**: Improvements to existing features

## Links

- [Unreleased]: https://github.com/YOUR-ORG/CloudVuln/compare/v1.0.0...HEAD
- [1.0.0]: https://github.com/YOUR-ORG/CloudVuln/releases/tag/v1.0.0
