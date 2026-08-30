# This file has one job: build the VPC and the subnets inside it.
# Nothing about security rules (that's nacl.tf / security-groups.tf) or
# actual servers/databases (that's ec2.tf / rds.tf) lives here.

# The VPC - the walls of your own private building inside AWS.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "three-tier-vpc"
  }
}

# Public subnet - the "front lobby". This is where the EC2 web server will live.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-2a"
  map_public_ip_on_launch = true # anything launched here gets a public IP automatically

  tags = {
    Name = "public-subnet"
  }
}

# Private subnets - the "locked back room". RDS will live here.
# There are two of these, in two different zones, because AWS requires a
# database to be able to sit across at least two zones - even if we only
# run one copy of it for this project.
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-2a"

  tags = {
    Name = "private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-2b"

  tags = {
    Name = "private-subnet-b"
  }
}

# Internet Gateway - the actual "door" that lets anything inside the VPC
# reach the internet at all. Without this, nothing in the VPC can be public.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "three-tier-igw"
  }
}

# Route table for the public subnet - the "signpost" that says
# "any traffic leaving here for the internet, go out through the Internet Gateway."
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Connects the public subnet to that signpost. This is the actual switch
# that makes the public subnet "public" - without this line, it would be
# just as locked-down as the private subnets.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Note: the private subnets have no route table association here on purpose.
# With no explicit route to the Internet Gateway, AWS automatically falls
# back to a route table that only allows traffic within the VPC itself.
# That's what makes them "private" - it's what we don't build, not what we do.
