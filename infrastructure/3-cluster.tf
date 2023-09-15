resource "aws_security_group" "eks-cluster" {
  name = "eks-cluster-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = "0"
    to_port = "0"
  }
  
  egress {
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = "0"
    to_port = "0"
  }
}

resource "aws_security_group" "eks-node" {
  name = "eks-node-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = "0"
    to_port = "0"
  }
  
  egress {
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    from_port = "0"
    to_port = "0"
  }
}

resource "aws_iam_role" "eks-cluster" {
    name = "wsi-cluster-role"

    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "eks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "amazon-eks-cluster-policy" {
    policy_arn = "arn:aws:iam:aws:policy/AdministratorAccess"
    role       = aws_iam_role.eks-cluster.name
}

resource "aws_eks_cluster" "cluster" {
    name     = "wsi-cluster"
    version  = "1.27"
    role_arn = aws_iam_role.eks-cluster.arn

    vpc_config {
        
    }
}