#------------------------------------------------
# Created by Yevhen Kashuba
# December 2022
# This code creates VPC, public and private subnets, IGW with route table,
# security group and Server Ubuntu in public subnet with elastic IP.
#------------------------------------------------

provider "aws" {
  region = var.region
}

# Create remoute state on AWS S3 for keep there terraform.tfstate file
terraform {
  backend "s3" {
    bucket = "homelab-bucket-eu-north-1"
    key    = "deploy/net-homelab/terraform.tfstate"
    region = "eu-north-1"
  }
}

# Create VPC
resource "aws_vpc" "homelab_vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "Homelab-VPC"
  }
}

# Association VCP with route table
resource "aws_main_route_table_association" "associate_RT_with_VPC" {
  vpc_id         = aws_vpc.homelab_vpc.id
  route_table_id = aws_route_table.homelab_public_routetable.id
}

# Internet gateway for VPC
resource "aws_internet_gateway" "homelab_igw" {
  vpc_id = aws_vpc.homelab_vpc.id
}

# Create public subnets in VPC Homelab-VPC. If you need more than 1 subnet,
# you have to add one more cidr in "var.public_subnet_cidr"
resource "aws_subnet" "homelab_public_subnet" {
  count                   = length(var.public_subnet_cidr)
  vpc_id                  = aws_vpc.homelab_vpc.id
  cidr_block              = element(var.public_subnet_cidr, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "Homelab-Public-Subnet-${count.index + 1}"
  }
}

# create Route Table for internet
resource "aws_route_table" "homelab_public_routetable" {
  vpc_id = aws_vpc.homelab_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.homelab_igw.id
  }
  tags = {
    Name = "Homelab-Public-Routetable"
  }
}

# Association route table with public subnets
resource "aws_route_table_association" "route_association" {
  count          = length(aws_subnet.homelab_public_subnet[*].id)
  route_table_id = aws_route_table.homelab_public_routetable.id
  subnet_id      = element(aws_subnet.homelab_public_subnet[*].id, count.index)
}

# create Security Group for Frontend instance
resource "aws_security_group" "homelab-SG-frontend" {
  name        = "allow_http_p80"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.homelab_vpc.id

  dynamic "ingress" {
    for_each = var.allow_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Homelab-SG-Frontend-P80"
  }
}

# Create Frontend instance in public subnet and set up nginx
resource "aws_instance" "frontend-nginx" {
  ami                         = data.aws_ami.latest_ubuntu_22_04.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.homelab_public_subnet[0].id
  vpc_security_group_ids      = [aws_security_group.homelab-SG-frontend.id]
  associate_public_ip_address = true
  user_data                   = file("./user_data_files/bootstrap_nginx.sh")
  tags = {
    Name    = "Homelab-Frontend-Nginx"
    Owner   = "Yevhen Kashuba"
    Project = "Homelab"
    Region  = var.region
  }
}
data "aws_ami" "latest_ubuntu_22_04" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Create Elastic IP for Frontend inctance
resource "aws_eip" "homelab_elastic_ip" {
  instance = aws_instance.frontend-nginx.id
  tags = {
    Name = "Homelab_Elastic_IP_for_Frontend"
  }
}
