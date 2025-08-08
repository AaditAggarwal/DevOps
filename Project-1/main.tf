terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "access-key"
  secret_key = "secret-key"
}

# Create a VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# Create a Custom Route Table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "production-route-table"
  }
}

# Create a subnet

resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "production-subnet-1"
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "subnet-1-association" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# Create a security group to allow port 22, 80, and 443
resource "aws_security_group" "allow-web" {
  name        = "allow-web-traffic"
  description = "Allow SSH, HTTP, and HTTPS traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-web-traffic"
  }
}

# Create a Network Interface
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.allow-web.id]

  tags = {
    Name = "web-server-nic"
  }
}

# Assign an elastic IP to the network interface
resource "aws_eip" "web-server-eip" {
  domain   = "vpc"
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.gw ]
}

# Create an Ubuntu EC2 instance

resource "aws_instance" "web-server-instance" {
  ami           = "ami-ami-020cba7c55df1f615"
  instance_type = "t3.micro"
  key_name      = "D:/DevOps/Keys/tf-access-key.pem"
  availability_zone = "us-east-1a"

  network_interface {
    network_interface_id = aws_network_interface.web-server-nic.id
    device_index         = 0
  }

  tags = {
    Name = "web-server"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    sudo bash -c 'echo your very first web server > /var/www/html/index.html'
    EOF
}