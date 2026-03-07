variable "ecs_sg" {
  type     = string
  nullable = false
}

variable "ecs_subnet" {
  type     = string
  nullable = false
}

# variable "api_gateway_arn" {
#   type     = string
#   nullable = false
# }

variable "aws_cognito_user_pool_arn" {
  type     = string
  nullable = false
}

variable "dynamodb_arn" {
  type     = string
  nullable = false
}

variable "region" {
  type     = string
  nullable = false
}

variable "task_definition" {
  type     = string
  nullable = false
}