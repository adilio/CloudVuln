#!/usr/bin/env bash
# dspm-data-generator — Teardown data generation scenario
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Colors / Icons
green() { tput setaf 2; }
yellow() { tput setaf 3; }
red() { tput setaf 1; }
cyan() { tput setaf 6; }
resetc() { tput sgr0; }
status() { green; echo "✅ $1"; resetc; }
warn() { yellow; echo "⚠️  $1"; resetc; }
error() { red; echo "❌ $1"; resetc; exit 1; }
info() { cyan; echo "ℹ️  $1"; resetc; }

info "🗑️  Starting teardown for dspm-data-generator..."

# Note: DSPM data generator doesn't deploy Terraform infrastructure
# It only generates local data files. This teardown cleans up local artifacts.

# Clean up generated data directory if it exists
if [ -d "$SCRIPT_DIR/dspm_test_data" ]; then
  warn "Removing generated test data in $SCRIPT_DIR/dspm_test_data..."
  rm -rf "$SCRIPT_DIR/dspm_test_data"
  status "Local test data removed"
fi

# Clean up any potential Terraform files (in case user accidentally initialized)
if [ -d "$SCRIPT_DIR/.terraform" ]; then
  warn "Removing Terraform artifacts..."
  rm -rf "$SCRIPT_DIR/.terraform"
  rm -f "$SCRIPT_DIR/terraform.tfstate" "$SCRIPT_DIR/terraform.tfstate.backup" "$SCRIPT_DIR/.terraform.lock.hcl"
fi

info "Note: If you uploaded data to S3, you must manually clean it up:"
echo "  aws s3 rm s3://<bucket-name> --recursive"
echo "  aws s3 rb s3://<bucket-name> --force"

status "Teardown complete for dspm-data-generator."
