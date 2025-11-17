output "iam_user_name" {
  description = "Name of the created IAM user"
  value       = aws_iam_user.this.name
}

output "iam_user_arn" {
  description = "ARN of the created IAM user"
  value       = aws_iam_user.this.arn
}

output "access_key_1_id" {
  description = "First access key ID (use 'terraform output -raw' to view)"
  value       = aws_iam_access_key.key1.id
  sensitive   = true
}

output "access_key_1_secret" {
  description = "First access key secret (use 'terraform output -raw' to view)"
  value       = aws_iam_access_key.key1.secret
  sensitive   = true
}

output "access_key_2_id" {
  description = "Second access key ID (use 'terraform output -raw' to view)"
  value       = aws_iam_access_key.key2.id
  sensitive   = true
}

output "access_key_2_secret" {
  description = "Second access key secret (use 'terraform output -raw' to view)"
  value       = aws_iam_access_key.key2.secret
  sensitive   = true
}

output "summary" {
  description = "Summary of IAM misconfigurations for CIEM validation"
  value = {
    user_name         = aws_iam_user.this.name
    user_arn          = aws_iam_user.this.arn
    access_keys_count = 2
    mfa_enabled       = false
    policy_overly_permissive = true
    password_policy_weak     = true
  }
}
