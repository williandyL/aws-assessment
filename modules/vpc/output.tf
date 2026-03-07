output "subnet" {
  value = aws_subnet.public_one.id
}

output "sg" {
  value = aws_security_group.ecs_tasks.id
}
