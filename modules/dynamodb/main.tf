terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_dynamodb_table" "GreetingLogs" {
  name             = "GreetingLogs"
  hash_key         = "id"
  billing_mode     = "PAY_PER_REQUEST"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "TestTableHashKey"
    type = "S"
  }

  #   replica {
  #     region_name = "us-east-1"
  #   }

  replica {
    region_name = "eu-west-1"
  }
}

data "aws_region" "current" {}