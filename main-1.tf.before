# main.tf
# Provider configuration for AWS
provider "aws" {
  region = "us-east-1" # Change to your preferred region
}

# Generate an SSH key pair if not done in prerequisites
resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_key" {
  key_name   = "k8s-key"
  public_key = tls_private_key.k8s_key.public_key_openssh

  lifecycle {
      ignore_changes = [public_key]
  }
}

# VPC Configuration
resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Subnet Configuration
resource "aws_subnet" "k8s_subnet" {
  vpc_id                  = aws_vpc.k8s_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

# Security Group
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

# EC2 Instance for Control Plane
resource "aws_instance" "k8s_master" {
  ami             = "ami-0866a3c8686eaeeba" #"ami-0c55b159cbfafe1f0" # Ubuntu 24.04 LTS AMI; update to match your region
  instance_type   = "t3.medium"
  subnet_id       = aws_subnet.k8s_subnet.id
  key_name        = aws_key_pair.k8s_key.key_name
  #security_groups = [aws_security_group.k8s_sg.name]
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]  # Change this line

  tags = {
    Name = "K8s-Master"
  }

  lifecycle {
    ignore_changes = [key_name]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y apt-transport-https ca-certificates curl",
      "curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -",
      "echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee -a /etc/apt/sources.list.d/kubernetes.list",
      "sudo apt-get update -y",
      "sudo apt-get install -y kubelet kubeadm kubectl",
      "sudo kubeadm init --pod-network-cidr=10.244.0.0/16",
      "mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.k8s_key.private_key_pem
      #private_key = file("~/.ssh/id_rsa")  # Adjust path to your private key
      timeout     = "5m"                   # Increase timeout to 5 minutes
      host        = self.public_ip
    }
  }
}

# Output the public IP of the master node
output "k8s_master_public_ip" {
  value = aws_instance.k8s_master.public_ip
}
