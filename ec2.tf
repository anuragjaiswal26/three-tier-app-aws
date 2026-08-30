# This file has one job: create the EC2 web server. It sits in the public
# subnet, wears the IAM badge from iam.tf, is protected by the ec2-web-sg
# security group, and gets Python + the AWS SDK installed automatically so
# it's ready to run check_db_health.py once we write it.

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# CHANGE THIS: put the name of the key pair you created in the AWS console
variable "key_pair_name" {
  description = "Name of the EC2 key pair to use for SSH access"
  type        = string
  default     = "three-tier-key"
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true
  key_name                    = var.key_pair_name

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y python3-pip
    pip3 install boto3 psycopg2-binary
  EOF

  tags = {
    Name = "three-tier-web-server"
  }
}
