# ------------------------------------------------------
# 1. PROVIDER SETUP
# ------------------------------------------------------
provider "aws" {
  region = "eu-west-2"
}

# ------------------------------------------------------
# 2. ELASTIC CONTAINER REGISTRY (ECR)
# ------------------------------------------------------
resource "aws_ecr_repository" "backend_repo" {
  name                 = "python-backend-repo"
  image_tag_mutability = "MUTABLE"

  # Automatically scan Docker images for vulnerabilities upon push
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "DevOps-Pipeline"
    Project     = "Container-Microservice"
  }
}