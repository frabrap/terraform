provider "aws" {
  region = "us-east-1"
}


# 1. Create a VPC
resource "aws_vpc" "vpc-terraform" {
  cidr_block = "192.0.0.0/16"
  tags = {
    Name = "production"
  }
}
# 2. Create Internet Gateway
resource "aws_internet_gateway" "igw-terraform" {
  vpc_id = aws_vpc.vpc-terraform.id
  tags = {
    Name = "igw_terraform"
  }
}

# 3. Create Custom Route Table.
resource "aws_route_table" "routeTb_terraform" {
  vpc_id = aws_vpc.vpc-terraform.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-terraform.id
  }

  tags = {
    Name = "routeTb_terraform"
  }
}

# 4. Create a Subnet
variable "subnet_prefix" {
  description = "cidr block for the subnet"
  #192.0.1.0/24
}

resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.vpc-terraform.id
  cidr_block        = var.subnet_prefix[0].cidr_block
  availability_zone = "us-east-1a"
  tags = {
    Name = var.subnet_prefix[0].name
  }
}

resource "aws_subnet" "subnet-2" {
  vpc_id            = aws_vpc.vpc-terraform.id
  cidr_block        = var.subnet_prefix[1].cidr_block
  availability_zone = "us-east-1a"
  tags = {
    Name = var.subnet_prefix[1].name
  }
}
# 5. associate subnet with route Table.
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.routeTb_terraform.id
}

# 6. Create Security Group to allow port 20, 80, 443
resource "aws_security_group" "sg_terraform" {
  name        = "sg_terraform"
  description = "Allow terraform inbound traffic"
  vpc_id      = aws_vpc.vpc-terraform.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh from VPC"
    from_port   = 22
    to_port     = 22
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
    Name = "sg_terraform"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4.
resource "aws_network_interface" "interface-terraform" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["192.0.1.10"]
  security_groups = [aws_security_group.sg_terraform.id]
}

# 8. Assign an elastic IP to the network interface created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.interface-terraform.id
  associate_with_private_ip = "192.0.1.10"
  depends_on                = [aws_internet_gateway.igw-terraform]

}


output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# 9. Create Ubuntu server and install/enable apache 2
resource "aws_instance" "terraform-server" {
  ami               = "ami-0557a15b87f6559cf"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "ubuntu_ec2"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.interface-terraform.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo mi primera pÃ¡gina > /var/www/html/index.html'
              EOF

  tags = {
    Name = "ubuntu_terraform"
  }

}