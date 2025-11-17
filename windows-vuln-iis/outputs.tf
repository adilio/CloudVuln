output "instance_id" {
  description = "ID of the Windows IIS instance"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP address of the Windows IIS instance"
  value       = aws_instance.this.public_ip
}

output "public_dns" {
  description = "Public DNS name of the Windows IIS instance"
  value       = aws_instance.this.public_dns
}

output "rdp_connection" {
  description = "RDP connection command"
  value       = "mstsc /v:${aws_instance.this.public_ip}"
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = aws_instance.this.ami
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.sg.id
}

output "summary" {
  description = "Summary of Windows IIS misconfigurations for CSPM/CDR validation"
  value = {
    instance_id           = aws_instance.this.id
    public_ip             = aws_instance.this.public_ip
    rdp_public_access     = true
    imdsv1_enabled        = true
    ebs_encryption        = false
    os_outdated           = true
    iis_directory_browse  = true
   }
}
