terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


resource "aws_vpc" "main" {
  cidr_block           = var.vpc
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public_one" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1a"
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-task-sg"
  description = "Allow outbound HTTPS for SNS and ECR"
  vpc_id      = aws_vpc.main.id # Replace with your VPC ID

  # INBOUND: No one can talk to this container (Highly Secure)
  # Fargate tasks usually don't need inbound rules unless they are web servers.
  ingress = []

  # OUTBOUND: Allow the container to reach the Internet/AWS APIs
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Required to talk to SNS, ECR, and CloudWatch"
  }

  tags = {
    Name = "ecs-publisher-sg"
  }
}


# 1. The Gateway (Attached to VPC)
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# 2. The Route Table (The Map)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                  # All internet traffic
    gateway_id = aws_internet_gateway.main.id # Go to the IGW
  }
}

# 3. The Association (The Connection)
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_one.id
  route_table_id = aws_route_table.public.id
}


# resource "aws_vpc" "main_us" {
#   cidr_block           = "12.0.0.0/16"
#   enable_dns_hostnames = true
#   enable_dns_support   = true

#   tags = {
#     Name = "main-vpc"
#   }
# }

# resource "aws_subnet" "public_one_us" {
#   vpc_id                  = aws_vpc.main_us.id
#   cidr_block              = "12.0.1.0/24"
#   map_public_ip_on_launch = true              

#   tags = {
#     Name = "public-subnet-1a"
#   }
# }

# resource "aws_security_group" "ecs_tasks_us" {
#   name        = "ecs-task-sg"
#   description = "Allow outbound HTTPS for SNS and ECR"
#   vpc_id      = aws_vpc.main_us.id

#   ingress = []

#   egress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"] 
#     description = "Required to talk to SNS, ECR, and CloudWatch"
#   }

#   tags = {
#     Name = "ecs-publisher-sg"
#   }
# }