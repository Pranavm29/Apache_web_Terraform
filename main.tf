#  Custom VPC (10.0.0.0/16)

#  Public Subnet (10.0.1.0/24)

# Internet Gateway

# Route Table with internet access

# Security Group (SSH, HTTP, HTTPS)

# Network Interface with private IP (10.0.1.50)

# Elastic IP (Public IP)

# EC2 Instance (Ubuntu 22.04)

# Apache Web Server installed via user_data

provider "aws" {
  region = "us-east-1"
}


resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Prod_VPC"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "Prod_IGW"
  }
}


resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public_Route_Table"
  }
}


resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.prod_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public_Subnet"
  }
}

# Associate Route Table
resource "aws_route_table_association" "rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_security_group" "web_sg" {
  name        = "web_security_group"
  description = "Allow SSH, HTTP, HTTPS"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web_SG"
  }
}


resource "aws_network_interface" "web_eni" {
  subnet_id       = aws_subnet.public_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.web_sg.id]

  tags = {
    Name = "Web_ENI"
  }
}


resource "aws_instance" "web_server" {
  ami               = "ami-053b0d53c279acc90" # Ubuntu 22.04 (us-east-1)
  instance_type     = "t3.micro"
  availability_zone = "us-east-1a"
  key_name          = "Internet_Gateway"

  network_interface {
    network_interface_id = aws_network_interface.web_eni.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install apache2 -y
              systemctl start apache2
              systemctl enable apache2
              echo "<html><body><h1>Welcome to the Web Server 🚀</h1></body></html>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "Web_Server"
  }
}


resource "aws_eip" "web_eip" {
  network_interface         = aws_network_interface.web_eni.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.igw]

  tags = {
    Name = "Web_EIP"
  }
}