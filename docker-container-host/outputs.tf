output "instance_id" {
  description = "ID of the Docker container host instance"
  value       = aws_instance.docker_host.id
}

output "public_ip" {
  description = "Public IP address of the Docker container host"
  value       = aws_instance.docker_host.public_ip
}

output "public_dns" {
  description = "Public DNS name of the Docker container host"
  value       = aws_instance.docker_host.public_dns
}

output "app_url" {
  description = "URL of the containerized application"
  value       = "http://${aws_instance.docker_host.public_ip}:8080"
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.docker_host.public_ip}"
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.docker_sg.id
}

output "summary" {
  description = "Summary of Docker host misconfigurations for CWPP/CSPM validation"
  value = {
    instance_id            = aws_instance.docker_host.id
    public_ip              = aws_instance.docker_host.public_ip
    app_url                = "http://${aws_instance.docker_host.public_ip}:8080"
    container_runs_as_root = true
    host_networking_mode   = true
    host_volume_mounted    = true
    imdsv1_enabled         = true
    ebs_encryption         = false
    public_port_exposed    = true
  }
}
