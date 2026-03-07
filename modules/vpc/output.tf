output "subnet" {
  value = aws_subnet.public_one.arn
}

output "sg" {
  value = aws_security_group.ecs_tasks.arn
}
