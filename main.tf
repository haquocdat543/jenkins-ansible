terraform {
  backend "s3" {
    bucket         = "<your-bucket-name>"
    key            = "Jenkins/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = "true"
    role_arn       = "<your-role-arn>"
    dynamodb_table = "<your-dynamodb-table-name>"
  }
}

# Profile configuration
provider "aws" {
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = var.profile
}

# Create VPC
resource "aws_vpc" "jenkins-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Cicd-vpc"
    Env = "Development"
  }
}
# Create Internet Gateway
resource "aws_internet_gateway" "jenkins_gw" {
  vpc_id = aws_vpc.jenkins-vpc.id

  tags = {
    Name = "Cicd-gateway"
    Env = "Development"
  }
}
# Create Custom Route Table
resource "aws_route_table" "ProdRouteTable" {
  vpc_id = aws_vpc.jenkins-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins_gw.id
  }
  tags = {
    Name = "Cicd-RouteTable"
    Env = "Development"
  }
}
# Create a Subnet
resource "aws_subnet" "JenkinsSubnet" {
  vpc_id            = aws_vpc.jenkins-vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "Cicd-JenkinsSubnet"
    Env = "Development"
  }
}
# Create Associate Subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.JenkinsSubnet.id
  route_table_id = aws_route_table.ProdRouteTable.id
}
# Create Security Group to allow port 22, 80, 443
resource "aws_security_group" "JenkinsSecurityGroup" {
  name        = "JenkinsSecurityGroup"
  description = "Allow SSH ,HTTPS , Jenkins, Sonarqube, React"
  vpc_id      = aws_vpc.jenkins-vpc.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 9000
    to_port          = 9000
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Jenkin-SG"
    Env = "Development"
  }
}
# Create a network interface with an ip in the subnet that was created step 4
resource "aws_network_interface" "Jenkins-Ansible" {
  subnet_id       = aws_subnet.JenkinsSubnet.id
  private_ips     = ["10.0.0.51"]
  security_groups = [aws_security_group.JenkinsSecurityGroup.id]
  tags = {
    Name = "Jenkin-Master"
    Env = "Development"
  }
}

# Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "Jenkins-Ansible" {
  domain                    = "vpc"
}

# Associate EIP to EC2 instances ENI

resource "aws_eip_association" "eip_assoc_to_Jenkins-Ansible" {
  instance_id   = aws_instance.Jenkins-Ansible.id
  allocation_id = aws_eip.Jenkins-Ansible.id
}

resource "aws_instance" "Jenkins-Ansible" {
  ami               = var.ami_id
  instance_type     = "t3.medium"
  availability_zone = "ap-northeast-1a"
  key_name          = var.key_pair
  user_data         = file("./scripts/jenkins-ansible.sh")
  root_block_device {
    volume_size = 15
    volume_type = "gp3"
    encrypted   = true
    tags	= {
	    "Name" = "Jenkins-Ansible"
	    "Env" = "Dev"
	}
    }
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.Jenkins-Ansible.id
  }
}

#Output
output "Jenkins-Ansible" {
  value = "ssh -i ~/${var.key_pair}.pem ubuntu@${aws_eip.Jenkins-Ansible.public_ip}"
}
