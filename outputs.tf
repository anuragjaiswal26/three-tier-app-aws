# This file has one job: print out useful information after "terraform
# apply" finishes, so you don't have to dig through the AWS console to
# find it. Nothing here creates anything - it's read-only convenience.

output "ec2_public_ip" {
  description = "Public IP address of the web server - use this to SSH in"
  value       = aws_instance.web.public_ip
}

output "rds_endpoint" {
  description = "Address of the database - the web server uses this to connect"
  value       = aws_db_instance.main.address
}

output "secrets_manager_secret_name" {
  description = "Name of the secret holding the DB password"
  value       = aws_secretsmanager_secret.db_password.name
}
