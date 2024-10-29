# Provider configuration for AWS
provider "aws" {
  region = "us-east-1"  # Change to your preferred AWS region
}

# Configure SSH Key Pair for EC2 access
resource "aws_key_pair" "k8s_key" {
  key_name   = "k8s-ec2-key"
  public_key = file("~/.ssh/id_rsa.pub")  # Path to your public key
}

# VPC configuration
resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id
}

# Subnet configuration
resource "aws_subnet" "k8s_subnet" {
  vpc_id            = aws_vpc.k8s_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"  # Change to your preferred AZ
}

# Security Group configuration
resource "aws_security_group" "k8s_sg" {
  vpc_id = aws_vpc.k8s_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance configuration
resource "aws_instance" "k8s_master" {
  ami                    = "ami-0866a3c8686eaeeba"  # Ubuntu 24.04 LTS AMI ID
  instance_type          = "t2.medium"  # Use a bigger instance type for production
  key_name               = aws_key_pair.k8s_key.key_name
  subnet_id              = aws_subnet.k8s_subnet.id
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "K8s-Master"
  }

  # Script to install Kubernetes on instance startup
  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io apt-transport-https ca-certificates curl

    # Kubernetes installation
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    kubeadm init --pod-network-cidr=10.244.0.0/16

    # Configure kubectl for root user
    export KUBECONFIG=/etc/kubernetes/admin.conf

    # Apply a network plugin (e.g., Flannel)
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
  EOF
}
