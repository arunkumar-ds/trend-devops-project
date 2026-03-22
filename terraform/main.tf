terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" 
}

# 1. Network Infrastructure (VPC)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "trend-project-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

# 2. Jenkins Server (EC2)
resource "aws_instance" "jenkins" {
  ami                    = "ami-0c7217cdde317cfec" 
  instance_type          = "t3.medium"
  subnet_id              = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  key_name               = "project"
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              # Update and Install Java (Required for Jenkins)
              sudo apt update -y
              sudo apt install fontconfig openjdk-17-jre -y

              # Install Jenkins (Updated 2026 Stable method)
              sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
              https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
              echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
              https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
              /etc/apt/sources.list.d/jenkins.list > /dev/null
              sudo apt update -y
              sudo apt install jenkins -y
              sudo systemctl start jenkins
              sudo systemctl enable jenkins

              # Install Docker
              sudo apt install docker.io -y
              sudo usermod -aG docker jenkins
              sudo usermod -aG docker ubuntu
              sudo systemctl restart docker

              # Install kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              EOF

  tags = { Name = "Jenkins-Server" }
}
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  vpc_id      = module.vpc.vpc_id

  # Allow SSH for PuTTY
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For security, replace with your IP later
  }

  # Allow Jenkins Web UI
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# 3. EKS Cluster (Kubernetes)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "trend-eks-cluster"
  cluster_version = "1.31"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    nodes = {
      min_size     = 1
      max_size     = 2
      desired_size = 2
      instance_types = ["t3.medium"]
    }
  }
}
