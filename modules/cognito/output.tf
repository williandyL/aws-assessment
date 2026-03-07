output "aws_cognito_user_pool_arn" {
  value       = aws_cognito_user_pool.example.arn
  description = "A description of the output's purpose"
}

output "cognito_test_username" {
  value     = aws_cognito_user.example.username
  sensitive = true
}

output "cognito_test_password" {
  value     = aws_cognito_user.example.password
  sensitive = true
}

output "cognito_client_id" {
  value     = aws_cognito_user_pool_client.client.id
}

output "cognito_region" {
  value = data.aws_region.current.name
}