module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # AWS Load Balancer Controller subnet discovery. These exact tag strings
  # are LBC convention — do not rename. Without them the LBC can't tell
  # which subnets are public vs private and refuses to create any ALB.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  enable_nat_gateway = true
  single_nat_gateway = true # Phase 1: one shared NAT. Phase 5 upgrades to per-AZ.
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Phase = var.phase
  }
}

# Fetch available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}
