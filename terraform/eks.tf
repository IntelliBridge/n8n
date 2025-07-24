# VPC
data "aws_availability_zones" "available" {}

resource "aws_vpc" "flow_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "flow-vpc"
  }
}

resource "aws_internet_gateway" "flow_igw" {
  vpc_id = aws_vpc.flow_vpc.id

  tags = {
    Name = "flow-igw"
  }
}

resource "aws_subnet" "flow_public" {
  count = 2

  vpc_id                  = aws_vpc.flow_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "flow-public-${count.index + 1}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "flow_private" {
  count = 2

  vpc_id            = aws_vpc.flow_vpc.id
  cidr_block        = "10.0.${count.index + 3}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "flow-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_route_table" "flow_public" {
  vpc_id = aws_vpc.flow_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.flow_igw.id
  }

  tags = {
    Name = "flow-public-rt"
  }
}

resource "aws_route_table_association" "flow_public" {
  count = 2

  subnet_id      = aws_subnet.flow_public[count.index].id
  route_table_id = aws_route_table.flow_public.id
}

# NAT Gateway
resource "aws_eip" "flow_nat" {
  domain = "vpc"
  tags = {
    Name = "flow-nat-eip"
  }
}

resource "aws_nat_gateway" "flow_nat" {
  allocation_id = aws_eip.flow_nat.id
  subnet_id     = aws_subnet.flow_public[0].id

  tags = {
    Name = "flow-nat"
  }

  depends_on = [aws_internet_gateway.flow_igw]
}

resource "aws_route_table" "flow_private" {
  vpc_id = aws_vpc.flow_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.flow_nat.id
  }

  tags = {
    Name = "flow-private-rt"
  }
}

resource "aws_route_table_association" "flow_private" {
  count = 2

  subnet_id      = aws_subnet.flow_private[count.index].id
  route_table_id = aws_route_table.flow_private.id
}

# Security Groups
resource "aws_security_group" "flow_cluster_sg" {
  name        = "flow-cluster-sg"
  description = "Security group for Flow EKS cluster"
  vpc_id      = aws_vpc.flow_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flow-cluster-sg"
  }
}

# EKS Cluster IAM Role
resource "aws_iam_role" "flow_cluster_role" {
  name = "flow-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "flow_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.flow_cluster_role.name
}

# EKS Cluster
resource "aws_eks_cluster" "flow_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.flow_cluster_role.arn
  version  = "1.28"

  vpc_config {
    subnet_ids              = concat(aws_subnet.flow_public[*].id, aws_subnet.flow_private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.flow_cluster_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.flow_cluster_AmazonEKSClusterPolicy,
  ]

  tags = {
    Name = var.cluster_name
  }
}

# EKS Node Group IAM Role
resource "aws_iam_role" "flow_nodes_role" {
  name = "flow-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "flow_nodes_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.flow_nodes_role.name
}

resource "aws_iam_role_policy_attachment" "flow_nodes_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.flow_nodes_role.name
}

resource "aws_iam_role_policy_attachment" "flow_nodes_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.flow_nodes_role.name
}

# EKS Node Group
resource "aws_eks_node_group" "flow_nodes" {
  cluster_name    = aws_eks_cluster.flow_cluster.name
  node_group_name = "flow-nodes"
  node_role_arn   = aws_iam_role.flow_nodes_role.arn
  subnet_ids      = aws_subnet.flow_private[*].id
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.desired_capacity
    max_size     = var.max_capacity
    min_size     = var.min_capacity
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.flow_nodes_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.flow_nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.flow_nodes_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    Name = "flow-nodes"
  }
}