# This file has one job: create a "badge" (IAM role) that gets pinned onto
# the EC2 server, giving it permission to read the database password from
# Secrets Manager. Without this, EC2 would not be allowed to touch Secrets
# Manager at all - AWS blocks everything by default.

resource "aws_iam_role" "ec2_role" {
  name = "ec2-secrets-reader-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ec2-secrets-reader-role"
  }
}

resource "aws_iam_role_policy" "read_secret" {
  name = "read-db-secret-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-secrets-reader-profile"
  role = aws_iam_role.ec2_role.name
}
