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
# ------------------------------------------------------
# 3. FOUNDATIONAL NETWORKING
# ------------------------------------------------------
resource "aws_vpc" "devops_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "devops-pipeline-vpc" }
}

resource "aws_internet_gateway" "devops_igw" {
  vpc_id = aws_vpc.devops_vpc.id
}

resource "aws_subnet" "devops_subnet" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "devops_rt" {
  vpc_id = aws_vpc.devops_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.devops_igw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.devops_subnet.id
  route_table_id = aws_route_table.devops_rt.id
}

resource "aws_security_group" "devops_sg" {
  name        = "devops-fargate-sg"
  vpc_id      = aws_vpc.devops_vpc.id

  # Allow Traffic to the Python Flask API
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Allow the container to pull images and reach the internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------
# 4. IAM PERMISSIONS (Task Execution Role)
# ------------------------------------------------------
# Gives Fargate permission to pull images from ECR
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ------------------------------------------------------
# 5. ECS FARGATE CLUSTER & COMPUTE
# ------------------------------------------------------
resource "aws_ecs_cluster" "app_cluster" {
  name = "python-backend-cluster"
}

# The Blueprint for the Container
resource "aws_ecs_task_definition" "app_task" {
  family                   = "python-backend-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 512 MB RAM
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "python-backend-container"
      image     = "${aws_ecr_repository.backend_repo.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# The Service that keeps the container running
resource "aws_ecs_service" "app_service" {
  name            = "python-backend-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.devops_subnet.id]
    security_groups  = [aws_security_group.devops_sg.id]
    assign_public_ip = true
  }
}