resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_role.arn

  version = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy]
}

resource "terraform_data" "update-ng-trigger" {
  input = var.update_node_groups
}

resource "terraform_data" "latest-matching-cluster-version" {
  input = aws_eks_cluster.this.version

  lifecycle {
    ignore_changes       = [input]
    replace_triggered_by = [terraform_data.update-ng-trigger]
  }
}

resource "aws_eks_node_group" "this" {
  for_each = { for node_group in var.node_groups : node_group.name => node_group }

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.value.name
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_ids
  version         = terraform_data.latest-matching-cluster-version.output

  scaling_config {
    desired_size = each.value.desired_capacity
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  instance_types = [each.value.instance_type]
}

# IAM role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.cluster_name}-eks-cluster-role"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_role" {
  name               = "eks-cluster-eks_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_role.name
}

# IAM role for EKS worker nodes
resource "aws_iam_role" "eks_node_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.cluster_name}-eks-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_worker_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_worker_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

# Security group for EKS
resource "aws_security_group" "eks_cluster_sg" {
  vpc_id = var.vpc_id

  ingress {
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
    Name = "${var.cluster_name}-eks-cluster-sg"
  }
}
