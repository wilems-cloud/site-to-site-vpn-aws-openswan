
provider "aws" {
  region = "us-east-1"
}

# --- VPCs ---
resource "aws_vpc" "cloud_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "CloudVPC"
  }
}

resource "aws_vpc" "on_prem_vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "OnPremVPC"
  }
}

# --- Subnets ---
resource "aws_subnet" "cloud_private_subnet" {
  vpc_id                  = aws_vpc.cloud_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "CloudPrivateSubnet"
  }
}

resource "aws_subnet" "on_prem_public_subnet" {
  vpc_id                  = aws_vpc.on_prem_vpc.id
  cidr_block              = "192.168.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "OnPremPublicSubnet"
  }
}

# --- Internet Gateways ---
resource "aws_internet_gateway" "cloud_igw" {
  vpc_id = aws_vpc.cloud_vpc.id
  tags = {
    Name = "CloudIGW"
  }
}

resource "aws_internet_gateway" "on_prem_igw" {
  vpc_id = aws_vpc.on_prem_vpc.id
  tags = {
    Name = "OnPremIGW"
  }
}

# --- Route Tables ---
resource "aws_route_table" "cloud_route_table" {
  vpc_id = aws_vpc.cloud_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloud_igw.id
  }
  tags = {
    Name = "CloudRouteTable"
  }
}

resource "aws_route_table" "on_prem_public_rt" {
  vpc_id = aws_vpc.on_prem_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.on_prem_igw.id
  }

  route { ## help test will use openswan as a router to get to cloud 

  cidr_block = "10.0.0.0/16" # Cloud VPC CIDR
  network_interface_id = aws_instance.openswan.primary_network_interface_id
  }

  tags = {
    Name = "OnPremPublicRT"
  }
}

# --- Route Table Associations ---
resource "aws_route_table_association" "cloud_assoc" {
  subnet_id      = aws_subnet.cloud_private_subnet.id
  route_table_id = aws_route_table.cloud_route_table.id
}

resource "aws_route_table_association" "on_prem_public_assoc" {
  subnet_id      = aws_subnet.on_prem_public_subnet.id
  route_table_id = aws_route_table.on_prem_public_rt.id
}

# --- Security Groups ---
resource "aws_security_group" "cloud_sg" {
  name        = "cloud-sg"
  description = "Allow ICMP"
  vpc_id      = aws_vpc.cloud_vpc.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["192.168.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "CloudSG"
  }
}

resource "aws_security_group" "on_prem_sg" {
  name        = "on-prem-sg"
  description = "Allow SSH and ICMP"
  vpc_id      = aws_vpc.on_prem_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    Name = "OnPremSG"
  }
}

# --- EC2 Instances ---
resource "aws_instance" "openswan" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.on_prem_public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.on_prem_sg.id]
  key_name                    = "Ubuntu_KeyPair"
   source_dest_check = false ## for the disable stop

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y openswan
              EOF

  tags = {
    Name = "OpenSwanServer"
  }
}


resource "aws_instance" "on_prem_test" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.on_prem_public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.on_prem_sg.id]
  key_name                    = "Ubuntu_KeyPair"

  tags = {
    Name = "OnPremTestInstance"
  }
}

resource "aws_instance" "cloud_test" {
  ami                    = "ami-0c02fb55956c7d316"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.cloud_private_subnet.id
  vpc_security_group_ids = [aws_security_group.cloud_sg.id]
  key_name               = "Ubuntu_KeyPair"

  tags = {
    Name = "CloudTestInstance"
  }
}

# --- VPN Setup ---
resource "aws_customer_gateway" "on_prem_gateway" {
  bgp_asn    = 65000
 ip_address = aws_instance.openswan.public_ip
  type       = "ipsec.1"
  tags = {
    Name = "CustomerGateway"
  }
}

resource "aws_vpn_gateway" "cloud_vgw" {
  vpc_id = aws_vpc.cloud_vpc.id
  tags = {
    Name = "CloudVGW"
  }
}

resource "aws_vpn_connection" "site_to_site" {
  customer_gateway_id = aws_customer_gateway.on_prem_gateway.id
  vpn_gateway_id      = aws_vpn_gateway.cloud_vgw.id
  type                = "ipsec.1"
  static_routes_only  = true
  tags = {
    Name = "SiteToSiteVPN"
  }
}

resource "aws_vpn_connection_route" "onprem_to_cloud" {
  vpn_connection_id      = aws_vpn_connection.site_to_site.id
  destination_cidr_block = "192.168.0.0/16"
}

resource "aws_vpn_gateway_route_propagation" "cloud_propagation" {
  vpn_gateway_id = aws_vpn_gateway.cloud_vgw.id
  route_table_id = aws_route_table.cloud_route_table.id
}
