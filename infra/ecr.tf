resource "aws_ecr_repository" "payment" {
  name                        = "payment-service"
  image_tag_mutability        = "IMMUTABLE"
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
        description  = "Keep last 10 images, expire others after 7 days"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["*"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
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
