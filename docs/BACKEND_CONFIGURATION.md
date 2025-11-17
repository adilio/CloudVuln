# Terraform Backend Configuration

This guide explains how to configure Terraform remote state backends for CloudVuln scenarios.

## Why Use a Remote Backend?

Remote backends provide:
- **State Locking**: Prevents concurrent modifications
- **Collaboration**: Share state across team members
- **Security**: Encrypt state at rest
- **Backup**: Automatic state versioning
- **Audit**: Track who made changes

## Supported Backends

### 1. S3 Backend (Recommended for AWS)

#### Setup

1. Create an S3 bucket for state storage:

```bash
aws s3api create-bucket \
  --bucket cloudvuln-terraform-state-$(whoami) \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket cloudvuln-terraform-state-$(whoami) \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket cloudvuln-terraform-state-$(whoami) \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

2. Create a DynamoDB table for state locking:

```bash
aws dynamodb create-table \
  --table-name cloudvuln-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

3. Add backend configuration to each scenario:

Create `backend.tf` in each scenario directory:

```hcl
terraform {
  backend "s3" {
    bucket         = "cloudvuln-terraform-state-YOUR-USERNAME"
    key            = "cloudvuln/SCENARIO-NAME/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "cloudvuln-terraform-locks"
  }
}
```

#### Example for iam-user-risk:

```bash
cd iam-user-risk
cat > backend.tf <<'EOF'
terraform {
  backend "s3" {
    bucket         = "cloudvuln-terraform-state-aleghari"
    key            = "cloudvuln/iam-user-risk/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "cloudvuln-terraform-locks"
  }
}
EOF

# Initialize with the backend
terraform init
```

### 2. Terraform Cloud

#### Setup

1. Create a Terraform Cloud account: https://app.terraform.io

2. Create an organization and workspace

3. Generate an API token:

```bash
terraform login
```

4. Add backend configuration:

```hcl
terraform {
  cloud {
    organization = "your-org-name"

    workspaces {
      name = "cloudvuln-iam-user-risk"
    }
  }
}
```

5. Initialize:

```bash
terraform init
```

### 3. Local Backend (Default)

The default configuration uses local state files:

```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

**Pros:**
- Simple, no setup required
- Works offline
- Fast

**Cons:**
- No collaboration support
- No state locking
- State stored in repository (security risk)
- No automatic backup

## Backend Migration

### Migrating from Local to S3

1. Create backend.tf with S3 configuration (see above)

2. Backup existing state:

```bash
cp terraform.tfstate terraform.tfstate.backup
```

3. Initialize with new backend:

```bash
terraform init -migrate-state
```

4. Verify migration:

```bash
aws s3 ls s3://cloudvuln-terraform-state-$(whoami)/cloudvuln/
```

### Migrating from S3 to Local

1. Remove or comment out backend.tf

2. Initialize and migrate:

```bash
terraform init -migrate-state
```

3. State file will be created locally

## Best Practices

### Security

1. **Encrypt state at rest and in transit**
   - S3: Enable bucket encryption
   - Terraform Cloud: Encryption enabled by default

2. **Restrict access to state**
   - S3: Use IAM policies
   - Terraform Cloud: Use team permissions

3. **Enable versioning**
   - Allows rollback if state becomes corrupted

4. **Never commit state files to Git**
   - Add to .gitignore:
   ```
   terraform.tfstate
   terraform.tfstate.backup
   .terraform/
   ```

### State Locking

Always use state locking in team environments:

```bash
# DynamoDB for S3 backend
aws dynamodb create-table \
  --table-name cloudvuln-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### State Backup

Automated backups:

1. **S3 Backend**: Enable versioning on bucket
2. **Terraform Cloud**: Automatic state versioning
3. **Local Backend**: Manual backups before changes

```bash
# Manual backup script
backup_state() {
  if [ -f terraform.tfstate ]; then
    cp terraform.tfstate "terraform.tfstate.backup.$(date +%Y%m%d-%H%M%S)"
  fi
}
```

## Per-Scenario Backend Configuration

### Recommended Structure

```
cloudvuln/
├── iam-user-risk/
│   ├── backend.tf (key: cloudvuln/iam-user-risk/terraform.tfstate)
│   └── ...
├── linux-misconfig-web/
│   ├── backend.tf (key: cloudvuln/linux-misconfig-web/terraform.tfstate)
│   └── ...
└── ...
```

### Single Bucket, Multiple Keys

Use the same S3 bucket with different keys per scenario:

```hcl
# iam-user-risk/backend.tf
terraform {
  backend "s3" {
    key = "cloudvuln/iam-user-risk/terraform.tfstate"
    # ... other config
  }
}

# linux-misconfig-web/backend.tf
terraform {
  backend "s3" {
    key = "cloudvuln/linux-misconfig-web/terraform.tfstate"
    # ... other config
  }
}
```

## Troubleshooting

### State Lock Errors

If you encounter state lock errors:

```bash
# List locks
aws dynamodb scan \
  --table-name cloudvuln-terraform-locks \
  --region us-east-1

# Force unlock (use with caution!)
terraform force-unlock LOCK_ID
```

### State Corruption

If state becomes corrupted:

1. Restore from backup:

```bash
# S3 backend
aws s3api list-object-versions \
  --bucket cloudvuln-terraform-state-$(whoami) \
  --prefix cloudvuln/iam-user-risk/

# Download specific version
aws s3api get-object \
  --bucket cloudvuln-terraform-state-$(whoami) \
  --key cloudvuln/iam-user-risk/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate
```

2. Or manually reconcile:

```bash
terraform refresh
```

### Migration Issues

If migration fails:

```bash
# Start fresh (CAUTION: destroys local state)
rm -rf .terraform terraform.tfstate*
terraform init
```

## Cost Considerations

### S3 Backend

- S3 storage: ~$0.023/GB/month
- DynamoDB (on-demand): Free for typical usage
- S3 requests: Minimal cost
- **Estimated monthly cost**: <$1 for CloudVuln

### Terraform Cloud

- Free tier: Up to 5 users
- Paid plans: $20/user/month
- Best for teams

## Example: Complete S3 Backend Setup

```bash
#!/usr/bin/env bash
# setup-remote-backend.sh

set -euo pipefail

BUCKET="cloudvuln-terraform-state-$(whoami)"
TABLE="cloudvuln-terraform-locks"
REGION="us-east-1"

echo "Setting up Terraform remote backend..."

# Create S3 bucket
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$REGION"

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table
aws dynamodb create-table \
  --table-name "$TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

echo "✅ Backend infrastructure created!"
echo ""
echo "Add this to backend.tf in each scenario:"
echo ""
cat <<EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET"
    key            = "cloudvuln/SCENARIO-NAME/terraform.tfstate"
    region         = "$REGION"
    encrypt        = true
    dynamodb_table = "$TABLE"
  }
}
EOF
```

## Additional Resources

- [Terraform Backend Configuration](https://www.terraform.io/docs/language/settings/backends/configuration.html)
- [S3 Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [Terraform Cloud Documentation](https://www.terraform.io/docs/cloud/index.html)
- [State Locking](https://www.terraform.io/docs/language/state/locking.html)
