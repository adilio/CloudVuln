# CloudVuln — Agent Guide

This file summarizes project knowledge for LLM-based agents. Keep intentional vulnerabilities intact unless explicitly asked to change them.

## Purpose
- AWS CNAPP breach simulation lab with five scenarios (Acts I–V) covering IAM, DSPM, CSPM/CDR (Linux + Windows), and CWPP/container risks.
- Built with Terraform + Bash; designed for insecure-by-design resources to validate detections and response playbooks.

## Repository Map (key items)
- `menu.sh`: TUI/CLI driver (`./menu.sh --run <scenario> deploy|teardown`).
- `cleanup-all.sh`: Destroys all scenarios.
- `common_vars.tf`, `terraform.tfvars.example`: Shared Terraform variables.
- Scenarios: `iam-user-risk/`, `dspm-data-generator/`, `linux-misconfig-web/`, `windows-vuln-iis/`, `docker-container-host/`.
- `tools/`: `run-tests.sh`, `cost-estimate.sh`, `health-check.sh` (if present).
- `tests/`: `unit/` (bats), `integration/terraform_syntax_test.sh`, `validation/` (requires deployed infra), `helpers/test_helpers.sh`.
- Docs: `docs/ARCHITECTURE.md`, `docs/QUICKSTART.md`, scenario READMEs.
- CI: `.github/workflows/test.yml`.

## Scenario Snapshots (intentionally vulnerable)
- `iam-user-risk`: IAM user without MFA, excess keys/policies; CIEM baseline.
- `dspm-data-generator`: Generates fake PII/PCI/PHI; optional S3 upload; Bash-driven, no Terraform infra by default.
- `linux-misconfig-web`: Public SG, IMDSv1, unencrypted EBS, outdated packages, canary secrets written via `user_data.sh` (needs OWNER, SCENARIO_NAME, fake keys).
- `windows-vuln-iis`: Similar exposures on Windows/IIS; IMDSv1, public RDP, unencrypted EBS.
- `docker-container-host`: Container host with risky settings (root, host mounts/net, IMDSv1). Uses default VPC + first subnet via `data.aws_subnets`.

## CI/CD (GitHub Actions)
- Workflow: `.github/workflows/test.yml`; triggers on push/PR to main/develop (+ claude/**).
- Env: `TF_VERSION=1.5.0`, `AWS_REGION=us-east-1`.
- Permissions: `contents: read`, `security-events: write`.
- Jobs:
  - `lint`: apt shellcheck; runs `find . -name "*.sh" ... shellcheck -x --severity=error`; Terraform fmt check per scenario (non-fatal warning on format issues).
  - `unit-tests`: installs bats; runs bats in `tests/unit` (marked `|| true` to avoid fail if tests fail? currently `|| true` in workflow).
  - `terraform-validation`: matrix over scenarios; `terraform init -backend=false`, `terraform validate`, `terraform fmt -check -recursive`.
  - `security-scan`: tfsec action v1.0.3 + Trivy; soft-fail; SARIF upload gated on file existence; pass `github_token: ${{ secrets.GITHUB_TOKEN }}`.
  - `documentation`: ensures scenario READMEs exist; markdown link check (continue-on-error); checks for `README.md`, `docs/ARCHITECTURE.md`, `docs/QUICKSTART.md`.
  - `summary`: aggregates needs, fails if lint/unit/terraform/docs failed.
  - Integration tests only on workflow_dispatch with input `run_integration_tests=true` (requires AWS creds).

## Testing & Commands
- Make targets: `make test`, `test-unit`, `test-integration` (`tests/integration/terraform_syntax_test.sh`), `validate-all`, `lint`, `format`, `cost-estimate`, `status`, etc.
- Terraform validate/init per scenario with `-backend=false`; fmt uses `terraform -chdir=<scenario> fmt -recursive`.
- Shellcheck locally: `find . -name "*.sh" -type f -print0 | xargs -0 shellcheck -x --severity=error`.
- Integration script expects Terraform; skips gracefully on init failure; uses `tests/helpers/test_helpers.sh`.

## Notable Implementation Details
- `.gitignore` excludes Terraform state/lock files; remove generated `.terraform.lock.hcl` before commits (CI runs init without backend).
- `linux-misconfig-web/main.tf` templatefile must include `OWNER` var for `user_data.sh` (already wired).
- `docker-container-host/main.tf` uses `data "aws_subnets"` (not deprecated `aws_subnet_ids`); selects first subnet.
- Scenario deploy scripts may export fake secrets (Stripe, AWS key, GitHub token) as canaries; do not replace with real secrets.

## External Dependencies
- Terraform >=1.5, AWS CLI for deployment, bats for unit tests, shellcheck for lint, tfsec/trivy for scans, jq used in scripts.
- CI runners install shellcheck and bats; tfsec/trivy pulled via GitHub Actions (use GITHUB_TOKEN to avoid rate limits).

## Safety & Invariants
- Intentionally vulnerable; do not harden unless asked.
- Use non-production AWS account; cleanup with `./cleanup-all.sh` or scenario `./teardown.sh`.
- Keep fmt/lint passing; preserve canary secrets and insecure settings that tests expect (IMDSv1, public ingress, unencrypted volumes).

## Common Pitfalls
- Missing OWNER in Linux user_data or invalid default subnet data source causes Terraform validate failures.
- Rate limits on tfsec/Trivy without GITHUB_TOKEN; ensured in workflow.
- SARIF uploads require `security-events: write` and files to exist; workflow guards with `hashFiles(...) != ''`.
- `dspm-data-generator` lacks Terraform; integration test counts `.tf` files—ensure script handles zero TF files as expected.

