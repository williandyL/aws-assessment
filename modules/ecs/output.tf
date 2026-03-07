output "task_definition" {
  value = aws_ecs_task_definition.sns_dispatcher.arn
}