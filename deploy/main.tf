# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "aws-ladams-key" {
  description = "Name of the AWS key pair for EC2 instances"
  type        = string
  default     = "aws-ladams-key"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "private-subnet"
  }
}

# Route Table for Public Subnet
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

# Route Table for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-route-table"
  }
}

# Associate Route Tables with Subnets
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security Group for Public Instance
resource "aws_security_group" "public" {
  name        = "public-sg"
  description = "Security group for public EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "public-security-group"
  }
}


# Public EC2 Instance
resource "aws_instance" "node01" {
  ami                    = "ami-044415bb13eee2391"
  instance_type          = "t2.small"
  key_name               = var.aws-ladams-key
  vpc_security_group_ids = [aws_security_group.public.id]
  subnet_id              = aws_subnet.public.id

  user_data = <<-EOF
              #!/bin/bash
              apt-get update

                # Add Docker's official GPG key:
                sudo apt-get update
                sudo apt-get install ca-certificates curl
                sudo install -m 0755 -d /etc/apt/keyrings
                sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
                sudo chmod a+r /etc/apt/keyrings/docker.asc

                # Add the repository to Apt sources:
                echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$$VERSION_CODENAME}") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt-get update

                sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
                sudo usermod -aG docker ubuntu

                git clone https://github.com/lawrenceadams/swarm-practice.git
              EOF

  tags = {
    Name = "manager-ec2-instance"
  }
}

# Private EC2 Instance
resource "aws_instance" "node02" {
  ami                    = "ami-044415bb13eee2391"
  instance_type          = "t2.small"
  key_name               = var.aws-ladams-key
  vpc_security_group_ids = [aws_security_group.public.id]
  subnet_id              = aws_subnet.public.id

  user_data = <<-EOF
              #!/bin/bash
              apt-get update

                # Add Docker's official GPG key:
                sudo apt-get update
                sudo apt-get install ca-certificates curl
                sudo install -m 0755 -d /etc/apt/keyrings
                sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
                sudo chmod a+r /etc/apt/keyrings/docker.asc

                # Add the repository to Apt sources:
                echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$$VERSION_CODENAME}") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt-get update

                sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
                sudo usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "worker-ec2-instance"
  }
}

# Outputs
output "node01_instance_public_ip" {
  description = "node01 public IP address"
  value       = aws_instance.node01.public_ip
}

output "node01_instance_private_ip" {
  description = "node01 rpivate IP address"
  value       = aws_instance.node01.private_ip
}

output "node02_instance_public_ip" {
  description = "node02 public IP address"
  value       = aws_instance.node02.public_ip
}

output "node02_instance_private_ip" {
  description = "node02 rpivate IP address"
  value       = aws_instance.node02.private_ip
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}
