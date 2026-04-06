terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "172.31.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = { Name = "sre-demo-vpc" }
}

# Subnets
resource "aws_subnet" "public" {
  count = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index)
  availability_zone = element(["eu-north-1a", "eu-north-1b", "eu-north-1c"], count.index)
  map_public_ip_on_launch = true
  tags = { Name = "sre-demo-subnet-${count.index}" }
}

# EKS Cluster
resource "aws_eks_cluster" "demo" {
  name     = "sre-demo-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }
}

# IAM Role for EKS
resource "aws_iam_role" "eks_cluster" {
  name = "sre-demo-eks-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

# EKS Node Group
resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.demo.name
  node_group_name = "sre-demo-workers"
  node_role_arn   = aws_iam_role.workers.arn
  subnet_ids      = aws_subnet.public[*].id
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  instance_types = ["t3.micro"]
}

resource "aws_iam_role" "workers" {
  name = "sre-demo-workers-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# ECR Repository
resource "aws_ecr_repository" "app" {
  name = "sre-demo-app"
}

output "cluster_name" {
  value = aws_eks_cluster.demo.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}
