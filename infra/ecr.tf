resource "aws_ecr_repository" "payment" {
  name                 = "payment-service"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "payment-service"
    Project     = var.project_name
    Environment = var.environment
    Phase       = var.phase
  }
}

resource "aws_ecr_lifecycle_policy" "payment" {
  repository = aws_ecr_repository.payment.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.payment.repository_url
  description = "ECR repository URL for payment-service images"
}

# ----------------------------------------------------------------------------
# Phase 03b — risk-check-service ECR repo
# Mirrors payment-service: IMMUTABLE tags, scan-on-push, AES256, lifecycle 10.
# ----------------------------------------------------------------------------

resource "aws_ecr_repository" "risk_check" {
  name                 = "risk-check-service"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "risk-check-service"
    Project     = var.project_name
    Environment = var.environment
    Phase       = var.phase
  }
}

resource "aws_ecr_lifecycle_policy" "risk_check" {
  repository = aws_ecr_repository.risk_check.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

output "risk_check_ecr_repository_url" {
  value       = aws_ecr_repository.risk_check.repository_url
  description = "ECR repository URL for risk-check-service images"
}
