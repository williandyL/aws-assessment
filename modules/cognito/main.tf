terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_cognito_user_pool" "example" {
  name = "mypool"

  schema {
    name                     = "terraform"
    attribute_data_type      = "Boolean"
    mutable                  = false
    required                 = false
    developer_only_attribute = false
  }
}

resource "random_password" "cognito_pass" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  min_lower        = 1
}

resource "aws_cognito_user" "example" {
  user_pool_id = aws_cognito_user_pool.example.id
  username     = "williandy"
  password     = random_password.cognito_pass.result

  attributes = {
    terraform      = true
    email          = "williandy.str@gmail.com"
    email_verified = true
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "williandy-client"
  user_pool_id = aws_cognito_user_pool.example.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

data "aws_region" "current" {}