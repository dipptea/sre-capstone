# EKS Cluster using official Terraform module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project_name}-cluster"
  cluster_version = "1.34"

  # VPC configuration
  vpc_id = module.vpc.vpc_id

  # Control plane (AWS-managed, outside VPC)
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  # Network configuration — worker nodes use private subnets
  subnet_ids = module.vpc.private_subnets
  # Control plane is AWS-managed; only nodes need subnets in our VPC

  # Enable IRSA (IAM Roles for Service Accounts) for pod-level IAM
  enable_irsa = true

  # Node group configuration
  eks_managed_node_groups = {
    main = {
      name_prefix = "capstone-sre-nodes-"

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      # Sizing: 2 nodes (1 per AZ) for Phase 1
      min_size     = 2
      max_size     = 2
      desired_size = 2

      # EBS volume for node OS + container images
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 30
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }

      # Tags for identification
      tags = {
        Phase = var.phase
      }
    }
  }

  tags = {
    Phase = var.phase
  }
}

# OIDC provider is created automatically by the module when enable_irsa = true
# No manual resource needed
