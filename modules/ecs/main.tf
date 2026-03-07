terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_ecs_cluster" "exam" {
  name = "exam"
}

resource "aws_ecs_cluster_capacity_providers" "exam" {
  cluster_name = aws_ecs_cluster.exam.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecs_task_definition" "sns_dispatcher" {
  family                   = "sns-publisher-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role
  task_role_arn            = var.task_role

  container_definitions = jsonencode([
    {
      name      = "publisher-container"
      image     = "amazon/aws-cli:latest"
      essential = true

      command = [
        "/bin/sh", "-c",
        "aws sns publish --topic-arn arn:aws:sns:us-east-1:123456789012:Unleash-Live-Topic --message \"{\\\"email\\\": \\\"$USER_EMAIL\\\", \\\"source\\\": \\\"ECS\\\", \\\"repo\\\": \\\"$REPO_URL\\\"}\""
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/sns-publisher"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}