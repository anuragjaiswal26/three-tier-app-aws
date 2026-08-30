# This file has one job: create the actual database, sitting inside the
# private subnets, locked behind the rds-db-sg security group and the
# private NACL. Nothing about the password lives here - that's pulled in
# from what secrets.tf already created.

resource "aws_db_subnet_group" "main" {
  name       = "three-tier-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "three-tier-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "three-tier-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_encrypted = true

  db_name  = "appdb"
  username = "appadmin"
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false

  skip_final_snapshot = true

  tags = {
    Name = "three-tier-db"
  }
}
