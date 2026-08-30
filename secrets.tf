# This file has one job: generate a random database password, and lock it
# away in Secrets Manager. The actual password value never appears in this
# file, never gets typed by a human, and never ends up in GitHub.

resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name        = "three-tier-app/db-password"
  description = "Password for the RDS database, used by the EC2 web server"

  tags = {
    Name = "db-password-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "appadmin"
    password = random_password.db_password.result
  })
}
